import Foundation
import SwiftUI
import UIKit

// MARK: - 户型档案的模型与持久化（SavedFloorplanLayout / 宅谱归档 / 工作区共享快照）
// 从 FloorplanView.swift 抽出：这些类型不带任何视图状态，改动风险为零。

extension Notification.Name {
    public static let didImportRoomPlanFloorplan = Notification.Name("com.tjyx.compass.didImportRoomPlanFloorplan")
}

struct SavedFloorplanLayout: Codable {
    let rooms: [FloorplanRoom]
    let centroidX: Double
    let centroidY: Double
    let compassRotation: Double
    let isSyncWithCompass: Bool
    let hasFloorplanAccess: Bool
    /// A paid case grant is scoped to this saved layout. Older records may
    /// contain only the pre-signature ID; those records are re-sealed once on
    /// restore before they can continue to unlock the layout.
    let floorplanAccessGrantID: String?
    let floorplanAccessGrantSignature: String?
    var aspectRatio: Double? = nil
    var widthMeters: Double? = nil
    var depthMeters: Double? = nil
    var houseFacingDegrees: Double? = nil
    var houseFacingWasExplicit: Bool? = nil
    var surveyMapping: FloorplanSurveyMapping? = nil
    /// nil follows live recommendations; an empty array is an explicitly cleared plan.
    var familyRoomAssignments: [FamilyRoomAssignment]? = nil
}

/// P1.2 多套户型宅谱档案记录（支持保存多套房源/客户户型、关联 3D 空间测绘模型及各自的已购解锁凭证）
struct FloorplanCaseRecord: Codable, Identifiable {
    var id: String
    var title: String
    let createdAt: Date
    let sittingSummary: String
    let layout: SavedFloorplanLayout
    var imageFileName: String?
    var spatialSurvey: HouseSpatialSurvey? = nil
    var virtualSpatialSurvey: HouseSpatialSurvey? = nil
    var exteriorRecords: [ExteriorShaRecord]? = nil
    var siteFacts: [XuanKongSiteFact]? = nil
    var propertyKey: String? = nil
    // Included only in portable JSON backups, never in the defaults archive.
    var backupImageData: Data? = nil
}

enum FloorplanCaseAssets {
    static func imageURL(fileName: String, directory: URL) throws -> URL {
        guard !fileName.isEmpty, fileName != ".", fileName != "..",
              URL(fileURLWithPath: fileName).lastPathComponent == fileName else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        return directory.appendingPathComponent(fileName, isDirectory: false)
    }

    static func backup(_ record: FloorplanCaseRecord, directory: URL) throws -> Data {
        var portable = record
        if let name = record.imageFileName {
            portable.backupImageData = try Data(contentsOf: imageURL(fileName: name, directory: directory))
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(portable)
    }

    static func importBackup(_ data: Data, existingIDs: Set<String>, directory: URL) throws -> FloorplanCaseRecord {
        var record = try JSONDecoder().decode(FloorplanCaseRecord.self, from: data)
        if record.id.isEmpty || existingIDs.contains(record.id) { record.id = UUID().uuidString }
        let imageData: Data?
        if let embedded = record.backupImageData {
            imageData = embedded
        } else if let name = record.imageFileName {
            // Legacy backups can still be imported on the original device.
            imageData = try Data(contentsOf: imageURL(fileName: name, directory: directory))
        } else {
            imageData = nil
        }
        record.imageFileName = nil
        if let imageData {
            let name = "floorplan-case-\(UUID().uuidString).jpg"
            try imageData.write(to: imageURL(fileName: name, directory: directory), options: .atomic)
            record.imageFileName = name
        }
        record.backupImageData = nil
        return record
    }

    static func deleteImage(_ record: FloorplanCaseRecord, remainingCases: [FloorplanCaseRecord], directory: URL) throws {
        guard let name = record.imageFileName,
              !remainingCases.contains(where: { $0.imageFileName == name }) else { return }
        let url = try imageURL(fileName: name, directory: directory)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }
}

/// One process-wide archive: windows mutate records by ID, never write a stale list.
final class FloorplanCaseStore: ObservableObject {
    static let shared = FloorplanCaseStore()
    static let storageKey = "tiandi_floorplan_cases_archive_v1"
    @Published private(set) var records: [FloorplanCaseRecord]
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        records = defaults.data(forKey: Self.storageKey).flatMap {
            try? JSONDecoder().decode([FloorplanCaseRecord].self, from: $0)
        } ?? []
    }

    func insert(_ record: FloorplanCaseRecord) throws {
        var record = record
        if record.id.isEmpty || records.contains(where: { $0.id == record.id }) {
            record.id = UUID().uuidString
        }
        var updated = records
        updated.insert(record, at: 0)
        try persist(updated)
    }

    func remove(id: String, imageDirectory: URL) throws {
        guard let record = records.first(where: { $0.id == id }) else { return }
        let updated = records.filter { $0.id != id }
        let data = try JSONEncoder().encode(updated)
        try FloorplanCaseAssets.deleteImage(record, remainingCases: updated, directory: imageDirectory)
        defaults.set(data, forKey: Self.storageKey)
        records = updated
    }

    private func persist(_ updated: [FloorplanCaseRecord]) throws {
        let data = try JSONEncoder().encode(updated)
        defaults.set(data, forKey: Self.storageKey)
        records = updated
    }
}

struct FloorplanWorkspaceSnapshot {
    let revision: UInt64
    let propertyID: UUID
    let writerID: UUID?
    let layout: SavedFloorplanLayout?
    let image: UIImage?
}

/// Shares the active plan and its image as one revision across all scenes.
/// Revision checks also reject delayed background/gesture writes from old views.
final class FloorplanWorkspaceStore: ObservableObject {
    static let shared = FloorplanWorkspaceStore()
    static let layoutKey = "tiandi_floorplan_saved_layout_v1"
    @Published private(set) var snapshot: FloorplanWorkspaceSnapshot
    let imageURL: URL?
    private let defaults: UserDefaults
    private var encodedLayout: Data?

    init(defaults: UserDefaults = .standard, directory: URL? = nil) {
        self.defaults = defaults
        let folder = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let resolvedImageURL: URL?
        if let folder, (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil {
            resolvedImageURL = folder.appendingPathComponent("floorplan-background.jpg")
        } else { resolvedImageURL = nil }
        self.imageURL = resolvedImageURL
        let layout = defaults.data(forKey: Self.layoutKey).flatMap {
            try? JSONDecoder().decode(SavedFloorplanLayout.self, from: $0)
        }
        encodedLayout = layout.flatMap { try? Self.encode($0) }
        snapshot = FloorplanWorkspaceSnapshot(revision: 0, propertyID: ShaSurveyStore.shared.propertyID, writerID: nil, layout: layout,
                                              image: resolvedImageURL.flatMap { UIImage(contentsOfFile: $0.path) })
    }

    @discardableResult
    func save(layout: SavedFloorplanLayout, image: UIImage?, writerID: UUID,
              expectedRevision: UInt64? = nil, expectedPropertyID: UUID? = nil) throws -> Bool {
        if let expectedRevision, expectedRevision != snapshot.revision { return false }
        if let expectedPropertyID, !ShaSurveyStore.shared.isCurrentProperty(expectedPropertyID) { return false }
        let data = try Self.encode(layout)
        let sameImage = image === snapshot.image
        guard data != encodedLayout || !sameImage || snapshot.propertyID != ShaSurveyStore.shared.propertyID else { return true }
        if !sameImage {
            guard let imageURL else { throw CocoaError(.fileWriteNoPermission) }
            if let image {
                guard let bytes = image.jpegData(compressionQuality: 0.85) ?? image.pngData() else {
                    throw CocoaError(.fileWriteUnknown)
                }
                try bytes.write(to: imageURL, options: .atomic)
            } else if FileManager.default.fileExists(atPath: imageURL.path) {
                try FileManager.default.removeItem(at: imageURL)
            }
        }
        defaults.set(data, forKey: Self.layoutKey)
        encodedLayout = data
        snapshot = FloorplanWorkspaceSnapshot(revision: snapshot.revision &+ 1,
                                              propertyID: ShaSurveyStore.shared.propertyID, writerID: writerID,
                                              layout: layout, image: image)
        return true
    }

    private static func encode(_ layout: SavedFloorplanLayout) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(layout)
    }
}

/// Complete geometry and audit values captured together on the UI thread.
struct FloorplanReportSnapshot {
    let rooms: [FloorplanRoom]
    let report: [FloorplanAuditItem]
    let centroid: CGPoint
    let heading: Double
    let aspectRatio: CGFloat
    let image: UIImage?
    let date: Date

    init(rooms: [FloorplanRoom], centroid: CGPoint, heading: Double, aspectRatio: CGFloat,
         image: UIImage? = nil, date: Date = Date()) {
        self.centroid = centroid
        self.heading = heading
        self.aspectRatio = aspectRatio
        self.image = image
        self.date = date
        let result = FloorplanEngine.shared.auditFloorplan(rooms: rooms, centroid: centroid, heading: heading,
                                                          aspectRatio: aspectRatio, date: date)
        self.rooms = result.auditedRooms
        self.report = result.report
    }
}

/// The renderer uses these same measured rectangles, so additional family members
/// and wrapped translations push the next paragraph down instead of overlapping it.
struct FloorplanReportRowLayout {
    static let titleFont = UIFont.boldSystemFont(ofSize: 22)
    static let bodyFont = UIFont.systemFont(ofSize: 17)
    static let solutionFont = UIFont.systemFont(ofSize: 17, weight: .semibold)
    let titleRect: CGRect
    let loreRect: CGRect
    let solutionRect: CGRect
    let height: CGFloat

    init(item: FloorplanAuditItem, solutionPrefix: String, width: CGFloat = 920) {
        let bodyWidth = max(1, width)
        func measuredHeight(_ text: String, font: UIFont) -> CGFloat {
            ceil((text as NSString).boundingRect(
                with: CGSize(width: bodyWidth, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil
            ).height)
        }
        titleRect = CGRect(x: 90, y: 16, width: bodyWidth, height: measuredHeight(item.title, font: Self.titleFont))
        loreRect = CGRect(x: 90, y: titleRect.maxY + 8, width: bodyWidth, height: measuredHeight(item.lore, font: Self.bodyFont))
        solutionRect = CGRect(x: 90, y: loreRect.maxY + 8, width: bodyWidth,
                              height: measuredHeight(solutionPrefix + " " + item.solution, font: Self.solutionFont))
        height = max(138, ceil(solutionRect.maxY + 16 + 12))
    }
}


