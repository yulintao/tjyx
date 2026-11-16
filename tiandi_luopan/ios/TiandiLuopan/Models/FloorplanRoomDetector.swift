import CoreGraphics
import Foundation
import UIKit
import Vision

/// 识别候选：矩形框 + 可选的真实轮廓多边形（相对坐标 0..1）
struct RoomCandidate: Equatable {
    var rect: CGRect
    var polygonPoints: [CGPoint]?
}

/// 户型图纸的房间识别：Vision 双通道（矩形检测 + 闭合轮廓）。
///
/// 从 FloorplanView 里搬出来是为了两点：
/// 1. 它只做像素 → 归一化矩形的计算，不碰任何视图状态，所以能脱离 SwiftUI 单测；
/// 2. 阈值（0.35 置信度、0.012 最小面积、0.55 IoU）以前散在视图文件里，
///    现在集中在这里，调参不用翻 3400 行的 View。
enum FloorplanRoomDetector {

    /// 一次完整识别。调用方负责放到后台线程。
    static func detect(in image: UIImage) -> [RoomCandidate] {
        guard let cgImage = image.cgImage else { return [] }
        let orientation = cgOrientation(for: image.imageOrientation)
        let rects = rectCandidates(cgImage: cgImage, orientation: orientation)
        let contours = contourCandidates(cgImage: cgImage, orientation: orientation)
        return merge(rectCandidates: rects, contourCandidates: contours)
    }

    /// 通道 1：矩形检测（高置信度矩形，适合规整线稿）
    static func rectCandidates(cgImage: CGImage, orientation: CGImagePropertyOrientation) -> [CGRect] {
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.35
        request.minimumSize = 0.04
        request.minimumAspectRatio = 0.15
        request.maximumAspectRatio = 6.0
        request.maximumObservations = 32
        do {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            return normalizedRoomCandidates(from: request.results ?? [])
        } catch {
            return []
        }
    }

    /// 通道 2：闭合轮廓多边形（自带对比度增强与灰度化，适配照片拍摄的图纸）
    static func contourCandidates(cgImage: CGImage,
                                  orientation: CGImagePropertyOrientation) -> [(rect: CGRect, points: [CGPoint])] {
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 2.0
        request.detectsDarkOnLight = true
        request.maximumImageDimension = 640
        do {
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            try handler.perform([request])
            guard let observation = request.results?.first else { return [] }
            return contourRoomCandidates(from: observation)
        } catch {
            return []
        }
    }

    /// 把顶层闭合轮廓转成房间候选（面积过滤 + 面积降序）
    static func contourRoomCandidates(from observation: VNContoursObservation) -> [(rect: CGRect, points: [CGPoint])] {
        var result: [(rect: CGRect, points: [CGPoint])] = []
        for contour in observation.topLevelContours {
            let rawPoints = contour.normalizedPoints
            guard rawPoints.count >= 4 else { continue }
            // Vision 坐标 y 向上（左下原点）→ 翻转为 UIKit y 向下
            let flipped = rawPoints.map { CGPoint(x: CGFloat($0.x), y: CGFloat(1 - $0.y)) }
            // 轮廓首尾接近即视为闭合房间边界
            let first = flipped.first ?? .zero
            let last = flipped.last ?? .zero
            guard hypot(last.x - first.x, last.y - first.y) < 0.03 else { continue }
            guard let bounds = GeometryUtils.polygonBounds(flipped) else { continue }
            guard bounds.width >= 0.08, bounds.height >= 0.06,
                  bounds.width * bounds.height >= 0.012,
                  bounds.width * bounds.height <= 0.78 else { continue }
            result.append((bounds, flipped))
        }
        return result.sorted {
            ($0.rect.width * $0.rect.height) > ($1.rect.width * $1.rect.height)
        }
    }

    /// 双通道候选合并：矩形优先入列，轮廓补齐；IoU > 0.55 视为同区域去重
    static func merge(rectCandidates: [CGRect],
                      contourCandidates: [(rect: CGRect, points: [CGPoint])]) -> [RoomCandidate] {
        var merged: [RoomCandidate] = []
        for rect in rectCandidates {
            let overlaps = merged.contains { existing in
                overlapsTooMuch(existing.rect, rect)
            }
            if !overlaps { merged.append(RoomCandidate(rect: rect, polygonPoints: nil)) }
        }
        for contour in contourCandidates {
            let overlaps = merged.contains { existing in
                overlapsTooMuch(existing.rect, contour.rect)
            }
            if !overlaps {
                merged.append(RoomCandidate(rect: contour.rect, polygonPoints: contour.points))
            }
        }
        return merged.sorted {
            ($0.rect.width * $0.rect.height) > ($1.rect.width * $1.rect.height)
        }
    }

    /// 两张归一化矩形的交并比是否超过 0.55
    static func overlapsTooMuch(_ lhs: CGRect, _ rhs: CGRect) -> Bool {
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull else { return false }
        let union = lhs.union(rhs)
        let unionArea = union.width * union.height
        return unionArea > 0 && (intersection.width * intersection.height) / unionArea > 0.55
    }

    static func cgOrientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    static func normalizedRoomCandidates(from observations: [VNRectangleObservation]) -> [CGRect] {
        let candidates = observations.compactMap { observation -> CGRect? in
            let box = observation.boundingBox
            let rect = CGRect(
                x: max(0, min(1, box.minX)),
                y: max(0, min(1, 1 - box.maxY)),
                width: max(0, min(1, box.width)),
                height: max(0, min(1, box.height))
            )
            guard rect.width >= 0.08, rect.height >= 0.06,
                  rect.width * rect.height >= 0.012,
                  rect.width * rect.height <= 0.78 else { return nil }
            return rect
        }
        .sorted { $0.width * $0.height > $1.width * $1.height }

        // Vision may return the same room at several nested scales. Keep the
        // first (largest) candidate and discard heavily overlapping boxes.
        return candidates.reduce(into: []) { result, candidate in
            if !result.contains(where: { overlapsTooMuch($0, candidate) }) {
                result.append(candidate)
            }
        }
    }
}
