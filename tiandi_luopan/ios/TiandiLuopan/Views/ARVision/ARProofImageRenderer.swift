import CoreGraphics
import Foundation
import UIKit

// MARK: - AR 存证快照渲染
// 从 ARVisionView.captureAndSaveSnapshot 的闭包里抽出来：那段画布代码原本埋在
// 2200 行级的视图文件中间，改一个水印位置要翻半天，也没法单独验证。
// 现在它只依赖 ARProofRenderInput 里的值，画面构成可以脱离相机、定位、罗盘单独推演。

/// 绘制一张 AR 存证图所需的全部输入（值类型，便于预览与回归测试）
struct ARProofRenderInput {
    var baseImage: UIImage
    var size: CGSize
    var shaName: String
    var shaAliases: String
    var shaSeverity: String
    var facingName: String
    var facingPinyin: String
    var facingPalace: String
    var heading: Double
    var targetHeading: Double
    var targetMountainName: String
    var targetPalace: String
    var targetNormX: Double
    var targetNormY: Double
    var distanceMeters: Double?
    var isLidarAvailable: Bool
    var coordinates: String
    var solarTime: String
    var capturedAt: Date
    var watermarkTitle: String
    var watermarkStamp: String
    var language: AppLanguage
}

extension ARProofRenderInput {
    /// 存证图固定 1920 边长，按相机帧原始比例等比铺满；不做二次裁切，
    /// 否则目标点相对画面的位置会偏移
    static func canvasSize(for image: UIImage, side: CGFloat = 1920) -> CGSize {
        GeometryUtils.aspectFitRect(
            aspectRatio: image.size.width / max(1, image.size.height),
            in: CGRect(x: 0, y: 0, width: side, height: side)
        ).size
    }
}

enum ARProofImageRenderer {

    /// 在后台线程调用：CoreGraphics 绘制 + UIKit 文字排版
    static func render(_ input: ARProofRenderInput) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        // 存证图按声明的像素尺寸出图，不继承 2x/3x 的 Retina scale
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: input.size, format: format)
        return renderer.image { ctx in
            let cg = ctx.cgContext

            // Only a real camera frame can become an on-site proof image.
            let imageSize = input.baseImage.size
            let fillScale = max(input.size.width / imageSize.width, input.size.height / imageSize.height)
            let drawSize = CGSize(width: imageSize.width * fillScale, height: imageSize.height * fillScale)
            let drawRect = CGRect(
                x: (input.size.width - drawSize.width) / 2,
                y: (input.size.height - drawSize.height) / 2,
                width: drawSize.width,
                height: drawSize.height
            )
            input.baseImage.draw(in: drawRect)

            // HUD 在相机帧上保持可读性。
            cg.setFillColor(UIColor.black.withAlphaComponent(0.12).cgColor)
            cg.fill(CGRect(origin: .zero, size: input.size))
            
            // 十字天心
            cg.setStrokeColor(UIColor(red: 0.0, green: 0.82, blue: 0.95, alpha: 0.6).cgColor)
            cg.setLineWidth(3)
            cg.move(to: CGPoint(x: input.size.width / 2, y: 0))
            cg.addLine(to: CGPoint(x: input.size.width / 2, y: input.size.height))
            cg.move(to: CGPoint(x: 0, y: input.size.height / 2))
            cg.addLine(to: CGPoint(x: input.size.width, y: input.size.height / 2))
            cg.strokePath()

            // 形煞锁定目标框绘入存证图
            let boxW: CGFloat = 420
            let boxH: CGFloat = 220
            let boxCenter = CGPoint(x: CGFloat(input.targetNormX) * input.size.width, y: CGFloat(input.targetNormY) * input.size.height)
            let targetBoxRect = CGRect(
                x: max(40, min(input.size.width - boxW - 40, boxCenter.x - boxW / 2)),
                y: max(120, min(input.size.height - 440 - boxH, boxCenter.y - boxH / 2)),
                width: boxW,
                height: boxH
            )
            cg.setFillColor(UIColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 0.16).cgColor)
            cg.fill(targetBoxRect)
            cg.setStrokeColor(UIColor(red: 1.0, green: 0.85, blue: 0.15, alpha: 0.95).cgColor)
            cg.setLineWidth(4)
            cg.stroke(targetBoxRect)

            let boxHeader = "\(input.shaName) · \(input.targetMountainName) (\(String(format: "%.1f°", input.targetHeading)))"
            boxHeader.draw(
                in: CGRect(x: targetBoxRect.minX + 20, y: targetBoxRect.minY + 24, width: boxW - 40, height: 60),
                withAttributes: [
                    .font: UIFont.boldSystemFont(ofSize: 30),
                    .foregroundColor: UIColor(red: 1.0, green: 0.92, blue: 0.35, alpha: 1.0)
                ]
            )
            let distLine: String
            if let d = input.distanceMeters {
                distLine = "\(input.targetPalace) · \(input.isLidarAvailable ? "LiDAR" : "AR") \(String(format: "%.2f m", d))"
            } else {
                distLine = "\(input.targetPalace) · \(input.shaSeverity)"
            }
            distLine.draw(
                in: CGRect(x: targetBoxRect.minX + 20, y: targetBoxRect.minY + 92, width: boxW - 40, height: 50),
                withAttributes: [
                    .font: UIFont.monospacedSystemFont(ofSize: 24, weight: .bold),
                    .foregroundColor: UIColor.white
                ]
            )
            input.shaAliases.draw(
                in: CGRect(x: targetBoxRect.minX + 20, y: targetBoxRect.minY + 148, width: boxW - 40, height: 48),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 22),
                    .foregroundColor: UIColor.white.withAlphaComponent(0.85)
                ]
            )
            
            // 水印卡片
            let cardRect = CGRect(x: 40, y: input.size.height - 380, width: input.size.width - 80, height: 320)
            cg.setFillColor(UIColor(red: 12/255.0, green: 12/255.0, blue: 16/255.0, alpha: 0.9).cgColor)
            cg.fill(cardRect)
            cg.setStrokeColor(UIColor(red: 212/255.0, green: 175/255.0, blue: 55/255.0, alpha: 0.8).cgColor)
            cg.setLineWidth(2)
            cg.stroke(cardRect)
            
            let titleAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 36),
                .foregroundColor: UIColor(red: 242/255.0, green: 217/255.0, blue: 115/255.0, alpha: 1.0)
            ]
            input.watermarkTitle.draw(at: CGPoint(x: 70, y: input.size.height - 350), withAttributes: titleAttr)
            
            let bodyAttr: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.white
            ]
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            let timeStr = dateFormatter.string(from: input.capturedAt)
            let distSuffix = input.distanceMeters.map { String(format: " · %@ %.2fm", input.isLidarAvailable ? "LiDAR" : "AR", $0) } ?? ""
            
            let infoText: String
            switch input.language {
            case .en:
                infoText = """
                Facing Orientation: Mountain \(input.facingPinyin) (Measured \(String(format: "%.1f", input.heading))°)\(distSuffix)
                Identified Sha: [\(input.shaName)] (\(input.shaAliases)) · \(input.shaSeverity)
                Coordinates: \(input.coordinates) · Solar: \(input.solarTime)
                Audit Time: \(timeStr) · SN: YX-AR-\(Int(input.capturedAt.timeIntervalSince1970))
                """
            case .zhHant:
                infoText = """
                向首方位: \(input.facingName)山向首 (實測 \(String(format: "%.1f", input.heading))°) · \(input.facingPalace)\(distSuffix)
                識別形煞: 【\(input.shaName)】(\(input.shaAliases)) · \(input.shaSeverity)
                現場經緯: \(input.coordinates) · 真太陽時: \(input.solarTime)
                勘察時間: \(timeStr) · 報告編號: YX-AR-\(Int(input.capturedAt.timeIntervalSince1970))
                """
            case .ja:
                infoText = """
                向首方位: \(input.facingName)山向首 (実測 \(String(format: "%.1f", input.heading))°) · \(input.facingPalace)\(distSuffix)
                識別形殺: 【\(input.shaName)】(\(input.shaAliases)) · \(input.shaSeverity)
                現場経度緯度: \(input.coordinates) · 真太陽時: \(input.solarTime)
                調査日時: \(timeStr) · レポート番号: YX-AR-\(Int(input.capturedAt.timeIntervalSince1970))
                """
            case .ko:
                infoText = """
                향수 방위: \(input.facingName)산 향수 (실측 \(String(format: "%.1f", input.heading))°) · \(input.facingPalace)\(distSuffix)
                식별 형살: 【\(input.shaName)】(\(input.shaAliases)) · \(input.shaSeverity)
                현장 좌표: \(input.coordinates) · 진태양시: \(input.solarTime)
                감정 일시: \(timeStr) · 보고서 번호: YX-AR-\(Int(input.capturedAt.timeIntervalSince1970))
                """
            case .vi:
                infoText = """
                Hướng đo: Sơn \(input.facingName) (Thực đo \(String(format: "%.1f", input.heading))°) · \(input.facingPalace)\(distSuffix)
                Hình sát nhận diện: [\(input.shaName)] (\(input.shaAliases)) · \(input.shaSeverity)
                Tọa độ: \(input.coordinates) · Giờ Mặt Trời: \(input.solarTime)
                Thời gian khảo sát: \(timeStr) · Mã báo cáo: YX-AR-\(Int(input.capturedAt.timeIntervalSince1970))
                """
            case .th:
                infoText = """
                ทิศทางที่หัน: ขุนเขา \(input.facingName) (วัดจริง \(String(format: "%.1f", input.heading))°) · \(input.facingPalace)\(distSuffix)
                ลักษณะปะทะที่พบ: [\(input.shaName)] (\(input.shaAliases)) · \(input.shaSeverity)
                พิกัดพื้นที่: \(input.coordinates) · เวลาสุริยะจริง: \(input.solarTime)
                เวลาสำรวจ: \(timeStr) · หมายเลขรายงาน: YX-AR-\(Int(input.capturedAt.timeIntervalSince1970))
                """
            case .id:
                infoText = """
                Arah Hadap: Gunung \(input.facingName) (Terukur \(String(format: "%.1f", input.heading))°) · \(input.facingPalace)\(distSuffix)
                Bentuk Sha Terdeteksi: [\(input.shaName)] (\(input.shaAliases)) · \(input.shaSeverity)
                Koordinat: \(input.coordinates) · Waktu Surya: \(input.solarTime)
                Waktu Survei: \(timeStr) · No. Laporan: YX-AR-\(Int(input.capturedAt.timeIntervalSince1970))
                """
            case .zhHans, .auto:
                infoText = """
                向首方位: \(input.facingName)山向首 (实测 \(String(format: "%.1f", input.heading))°) · \(input.facingPalace)\(distSuffix)
                识别形煞: 【\(input.shaName)】(\(input.shaAliases)) · \(input.shaSeverity)
                现场经纬: \(input.coordinates) · 真太阳时: \(input.solarTime)
                勘察时间: \(timeStr) · 报告编号: YX-AR-\(Int(input.capturedAt.timeIntervalSince1970))
                """
            }
            infoText.draw(in: CGRect(x: 70, y: input.size.height - 290, width: input.size.width - 260, height: 210), withAttributes: bodyAttr)
            
            // 朱砂印鉴
            let sealRect = CGRect(x: input.size.width - 190, y: input.size.height - 230, width: 120, height: 120)
            cg.setStrokeColor(UIColor(red: 178/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0).cgColor)
            cg.setLineWidth(3)
            cg.stroke(sealRect)
            input.watermarkStamp.draw(in: sealRect.insetBy(dx: 18, dy: 18), withAttributes: [
                .font: UIFont.boldSystemFont(ofSize: 26),
                .foregroundColor: UIColor(red: 178/255.0, green: 34/255.0, blue: 34/255.0, alpha: 1.0)
            ])
        }
    }
}
