import Foundation
import CoreGraphics

/// Converts blueprint axes and AR coordinates independently into geographic sectors.
/// A room may cover several sectors. Point objects always keep their own measured position.
enum XuanKongHomeContextBuilder {
    static func facing(layout: SavedFloorplanLayout?, survey: HouseSpatialSurvey?) -> Double? {
        [layout?.houseFacingDegrees, survey?.resolvedHouseFacing].compactMap { $0 }.first { $0.isFinite }
    }

    static func build(layout: SavedFloorplanLayout?, survey: HouseSpatialSurvey?, exterior: [ExteriorShaRecord],
                      facts: [XuanKongSiteFact]) -> XuanKongHomeContext {
        var result = XuanKongHomeContext(exterior: exterior.filter { $0.bearingDegrees.isFinite },
                                        facts: facts.filter { (0...8).contains($0.palaceID) })
        var acceptedSurvey = survey
        if let a = layout?.houseFacingDegrees, let b = survey?.resolvedHouseFacing,
           a.isFinite, b.isFinite {
            let delta = abs(a - b).truncatingRemainder(dividingBy: 360)
            if min(delta, 360 - delta) > 7.5 {
                acceptedSurvey = nil
                result.warningKeys.append("xkd_orientation_conflict")
            }
        }
        if let layout, let survey = acceptedSurvey,
           !layout.rooms.isEmpty,
           layout.surveyMapping?.point(x: survey.centroidX, z: survey.centroidZ, surveyID: survey.id) == nil {
            acceptedSurvey = nil
            if !survey.openings.isEmpty || !survey.objects.isEmpty {
                result.warningKeys.append("xkd_alignment_missing")
            }
        }
        let validRooms = layout?.rooms.filter {
            $0.rect.minX.isFinite && $0.rect.minY.isFinite && $0.rect.width.isFinite && $0.rect.height.isFinite
                && $0.rect.width > 0 && $0.rect.height > 0
        } ?? []
        let bounds = validRooms.filter { $0.type != .missingCorner }.reduce(CGRect.null) { $0.union($1.rect) }
        let planRatio = (layout?.aspectRatio).flatMap { $0.isFinite && $0 > 0 ? CGFloat($0) : nil } ?? 1
        let planRadius = bounds.isNull ? 0.03 : min(bounds.width * planRatio, bounds.height) * 0.12
        func planSector(_ point: CGPoint, layout: SavedFloorplanLayout) -> Int? {
            let center = CGPoint(x: layout.centroidX, y: layout.centroidY)
            if hypot((point.x - center.x) * planRatio, point.y - center.y) < planRadius { return 4 }
            return XuanKongDeepAnalyzer.palaceID(bearing:
                GeometryUtils.bearing(from: center, to: point, aspectRatio: planRatio) + layout.compassRotation)
        }
        if let layout, layout.compassRotation.isFinite, layout.centroidX.isFinite, layout.centroidY.isFinite {
            func sector(_ point: CGPoint) -> Int? {
                planSector(point, layout: layout)
            }
            for room in validRooms {
                if room.type == .door || room.type == .missingCorner {
                    if let id = sector(FloorplanEngine.roomCentroid(room)) {
                        result.places.append(XuanKongLocatedPlace(id: "plan-\(room.id)-\(id)", palaceID: id, name: room.name,
                            kind: room.type == .door ? .entrance : .room, roomType: room.type))
                    }
                    continue
                }
                var counts: [Int: Int] = [:]
                for x in 0..<11 {
                    for y in 0..<11 {
                        let point = CGPoint(x: room.rect.minX + room.rect.width * (CGFloat(x) + 0.5) / 11,
                                            y: room.rect.minY + room.rect.height * (CGFloat(y) + 0.5) / 11)
                        guard FloorplanEngine.roomContains(room, point: point), let id = sector(point) else { continue }
                        counts[id, default: 0] += 1
                    }
                }
                let total = max(1, counts.values.reduce(0, +))
                for id in counts.keys.sorted() {
                    let count = counts[id] ?? 0
                    result.places.append(XuanKongLocatedPlace(id: "plan-\(room.id)-\(id)", palaceID: id,
                        name: room.name, kind: .room, roomType: room.type, coverage: max(1, Int((Double(count) / Double(total) * 100).rounded()))))
                }
            }
        }
        if let survey = acceptedSurvey, survey.compassHeading.isFinite {
            let center = survey.centroid
            let radius = Double(min(survey.dimensions.totalWidth, survey.dimensions.totalDepth)) * 0.12
            func sector(x: Float, z: Float) -> Int? {
                guard x.isFinite, z.isFinite, center.x.isFinite, center.z.isFinite else { return nil }
                if let layout, !layout.rooms.isEmpty {
                    guard let point = layout.surveyMapping?.point(x: x, z: z, surveyID: survey.id) else { return nil }
                    return planSector(point, layout: layout)
                }
                let dx = Double(x - center.x), dz = Double(z - center.z)
                if hypot(dx, dz) < max(0.05, radius) { return 4 }
                return XuanKongDeepAnalyzer.palaceID(bearing: atan2(dx, -dz) * 180 / .pi + survey.compassHeading)
            }
            // Blueprint room polygons take precedence over AR bounding boxes for room coverage.
            if result.places.allSatisfy({ $0.kind != .room }) {
                for room in survey.rooms {
                    var counts: [Int: Int] = [:]
                    let angle = Double(room.rotationY ?? 0), c = Float(cos(angle)), s = Float(sin(angle))
                    for x in 0..<11 {
                        for z in 0..<11 {
                            let lx = room.sizeX * (Float(x) + 0.5) / 11 - room.sizeX / 2
                            let lz = room.sizeZ * (Float(z) + 0.5) / 11 - room.sizeZ / 2
                            if let id = sector(x: room.centerX + lx * c - lz * s, z: room.centerZ + lx * s + lz * c) {
                                counts[id, default: 0] += 1
                            }
                        }
                    }
                    let total = max(1, counts.values.reduce(0, +))
                    for id in counts.keys.sorted() {
                        result.places.append(XuanKongLocatedPlace(id: "room-\(room.id)-\(id)", palaceID: id,
                            name: room.name, kind: .room, roomType: room.type,
                            coverage: max(1, Int((Double(counts[id] ?? 0) / Double(total) * 100).rounded()))))
                    }
                }
            }
            for opening in survey.openings {
                guard let id = sector(x: opening.posX, z: opening.posZ) else { continue }
                let kind: XuanKongPlaceKind = opening.type == .entranceDoor ? .entrance
                    : (opening.type == .window || opening.type == .balconyDoor ? .window : .interiorDoor)
                result.places.append(XuanKongLocatedPlace(id: "opening-\(opening.id)", palaceID: id,
                    name: opening.type.localizedName, kind: kind, roomType: nil))
            }
            for object in survey.objects {
                guard object.category == "bed" || object.category == "stove" || object.category == "oven",
                      let id = sector(x: object.posX, z: object.posZ) else { continue }
                result.places.append(XuanKongLocatedPlace(id: "object-\(object.id)", palaceID: id,
                    name: object.localizedCategoryName, kind: object.category == "bed" ? .bed : .stove, roomType: nil))
            }
        }
        if result.places.isEmpty { result.missingKeys.append("xkd_missing_plan") }
        if !result.places.contains(where: { $0.kind == .window }) { result.missingKeys.append("xkd_missing_window") }
        if !result.places.contains(where: { $0.kind == .bed }) { result.missingKeys.append("xkd_missing_bed") }
        if !result.places.contains(where: { $0.kind == .stove }) { result.missingKeys.append("xkd_missing_stove") }
        if result.exterior.isEmpty && result.facts.isEmpty { result.missingKeys.append("xkd_missing_exterior") }
        return result
    }
}

// MARK: - 户型空间立极与全屋风水体检引擎 (PRD 5.3 & 第7章)

struct FloorplanAuditTimeKey: Equatable {
    let year: Int
    let solarTerm: Int
    let utcOffset: Int

    init(date: Date, timeZone: TimeZone = .current) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        year = calendar.component(.year, from: date)
        solarTerm = SolarTimeCalculator.shared.solarTermIndex(for: date)
        utcOffset = timeZone.secondsFromGMT(for: date)
    }
}

public enum FloorplanRoomType: String, CaseIterable, Identifiable, Codable {
    case door = "大门"
    case livingRoom = "客厅"
    case masterBedroom = "主卧"
    case secondBedroom = "次卧"
    case kitchen = "厨房"
    case bathroom = "卫生间"
    case study = "书房"
    case balcony = "阳台"
    case missingCorner = "户型缺角"
    
    public var id: String { self.rawValue }
    
    public var iconName: String {
        switch self {
        case .door: return "door.left.hand.open"
        case .livingRoom: return "sofa.fill"
        case .masterBedroom: return "bed.double.fill"
        case .secondBedroom: return "bed.double"
        case .kitchen: return "flame.fill"
        case .bathroom: return "drop.triangle.fill"
        case .study: return "books.vertical.fill"
        case .balcony: return "sun.max.fill"
        case .missingCorner: return "exclamationmark.triangle.fill"
        }
    }

    public var localizedName: String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .en:
            switch self {
            case .door: return "Main Entrance"
            case .livingRoom: return "Living Room"
            case .masterBedroom: return "Master Bedroom"
            case .secondBedroom: return "Second Bedroom"
            case .kitchen: return "Kitchen"
            case .bathroom: return "Bathroom"
            case .study: return "Study"
            case .balcony: return "Balcony"
            case .missingCorner: return "Missing Corner"
            }
        case .ja:
            switch self {
            case .door: return "玄関"
            case .livingRoom: return "リビング"
            case .masterBedroom: return "主寝室"
            case .secondBedroom: return "寝室"
            case .kitchen: return "キッチン"
            case .bathroom: return "浴室・トイレ"
            case .study: return "書斎"
            case .balcony: return "バルコニー"
            case .missingCorner: return "間取りの欠け"
            }
        case .ko:
            switch self {
            case .door: return "현관문"
            case .livingRoom: return "거실"
            case .masterBedroom: return "안방 (주침실)"
            case .secondBedroom: return "작은방 (침실)"
            case .kitchen: return "주방"
            case .bathroom: return "욕실"
            case .study: return "서재"
            case .balcony: return "발코니"
            case .missingCorner: return "평면 결손"
            }
        case .vi:
            switch self {
            case .door: return "Cửa chính"
            case .livingRoom: return "Phòng khách"
            case .masterBedroom: return "Phòng ngủ chính"
            case .secondBedroom: return "Phòng ngủ phụ"
            case .kitchen: return "Nhà bếp"
            case .bathroom: return "Phòng vệ sinh"
            case .study: return "Phòng đọc sách"
            case .balcony: return "Ban công"
            case .missingCorner: return "Khuyết góc nhà"
            }
        case .th:
            switch self {
            case .door: return "ประตูใหญ่"
            case .livingRoom: return "ห้องรับแขก"
            case .masterBedroom: return "ห้องนอนใหญ่"
            case .secondBedroom: return "ห้องนอนเล็ก"
            case .kitchen: return "ห้องครัว"
            case .bathroom: return "ห้องน้ำ"
            case .study: return "ห้องหนังสือ"
            case .balcony: return "ระเบียง"
            case .missingCorner: return "มุมเว้าแหว่ง"
            }
        case .id:
            switch self {
            case .door: return "Pintu Utama"
            case .livingRoom: return "Ruang Tamu"
            case .masterBedroom: return "Kamar Tidur Utama"
            case .secondBedroom: return "Kamar Tidur Kedua"
            case .kitchen: return "Dapur"
            case .bathroom: return "Kamar Mandi"
            case .study: return "Ruang Belajar"
            case .balcony: return "Balkon"
            case .missingCorner: return "Sudut Hilang"
            }
        case .zhHant:
            switch self {
            case .door: return "入戶大門"
            case .livingRoom: return "客廳"
            case .masterBedroom: return "主臥"
            case .secondBedroom: return "次臥"
            case .kitchen: return "廚房"
            case .bathroom: return "衛生間"
            case .study: return "書房"
            case .balcony: return "陽台"
            case .missingCorner: return "戶型缺角"
            }
        case .zhHans, .auto:
            switch self {
            case .door: return "入户大门"
            case .livingRoom: return "客厅"
            case .masterBedroom: return "主卧"
            case .secondBedroom: return "次卧"
            case .kitchen: return "厨房"
            case .bathroom: return "卫生间"
            case .study: return "书房"
            case .balcony: return "阳台"
            case .missingCorner: return "户型缺角"
            }
        }
    }
}

public struct FloorplanRoom: Identifiable, Codable {
    public var id: String
    public var name: String
    public var type: FloorplanRoomType
    public var rect: CGRect // 相对比例 (0.0 .. 1.0)
    public var polygonPoints: [CGPoint]? // 可选：识别出的真实房间轮廓（相对比例），nil 时退化为矩形
    public var palaceName: String // "西北乾宫", "东南巽宫", etc.
    public var inspectionTitle: String
    public var inspectionLevel: String // "吉", "平", "凶", "大凶"
    public var inspectionLore: String
    public var inspectionAdvice: String
    
    public init(id: String = UUID().uuidString, name: String, type: FloorplanRoomType, rect: CGRect, polygonPoints: [CGPoint]? = nil, palaceName: String = "", inspectionTitle: String = "", inspectionLevel: String = "平", inspectionLore: String = "", inspectionAdvice: String = "") {
        self.id = id
        self.name = name
        self.type = type
        self.rect = rect
        self.polygonPoints = polygonPoints
        self.palaceName = palaceName
        self.inspectionTitle = inspectionTitle
        self.inspectionLevel = inspectionLevel
        self.inspectionLore = inspectionLore
        self.inspectionAdvice = inspectionAdvice
    }
    /// Apply one affine edit to both representations of the room geometry.
    public func transformed(to target: CGRect) -> FloorplanRoom {
        var result = self
        if let points = polygonPoints, rect.width > 0, rect.height > 0 {
            result.polygonPoints = points.map {
                CGPoint(x: target.minX + ($0.x - rect.minX) * target.width / rect.width,
                        y: target.minY + ($0.y - rect.minY) * target.height / rect.height)
            }
        }
        result.rect = target
        return result
    }

    public var isSevere: Bool {
        inspectionLevel.contains("严重") || inspectionLevel.contains("大凶") ||
        inspectionLevel.localizedCaseInsensitiveContains("severe") ||
        inspectionLevel.localizedCaseInsensitiveContains("critical")
    }
    public var isBad: Bool {
        isSevere || inspectionLevel.contains("凶") ||
        inspectionLevel.localizedCaseInsensitiveContains("harm")
    }
    public var isGood: Bool {
        inspectionLevel.contains("吉") || inspectionLevel.localizedCaseInsensitiveContains("auspicious")
    }
    public var isWarning: Bool {
        inspectionLevel.contains("预警") || inspectionLevel.localizedCaseInsensitiveContains("warning")
    }
}

public struct FloorplanAuditItem: Identifiable {
    // The audit is recalculated whenever the compass moves. A generated UUID
    // here makes SwiftUI treat every row as a brand-new view on each update,
    // which resets row layout and can visibly shake the report list. Callers
    // provide a stable room/report key instead.
    public let id: String
    public let title: String
    public let palace: String
    public let severity: String // "吉", "提示", "预警", "严重煞气"
    public let lore: String
    public let solution: String

    public init(id: String, title: String, palace: String, severity: String, lore: String, solution: String) {
        self.id = id
        self.title = title
        self.palace = palace
        self.severity = severity
        self.lore = lore
        self.solution = solution
    }

    public var isSevere: Bool {
        severity.contains("严重") || severity.contains("大凶") ||
        severity.localizedCaseInsensitiveContains("severe") ||
        severity.localizedCaseInsensitiveContains("critical")
    }
    public var isGood: Bool {
        severity.contains("吉") || severity.localizedCaseInsensitiveContains("auspicious")
    }
    public var isWarning: Bool {
        severity.contains("预警") || severity.localizedCaseInsensitiveContains("warning")
    }
    public var localizedSeverity: String {
        let lang = LocalizationManager.shared
        if isSevere { return lang.t("floorplan_level_severe") }
        if isGood { return lang.t("floorplan_level_auspicious") }
        if isWarning { return lang.t("floorplan_level_warning") }
        return lang.t("floorplan_level_neutral")
    }
}

/// Latest in-session floorplan audit consumed by the TianJi export. The
/// report is intentionally kept as value data; it is refreshed after every
/// audit and is not treated as a durable source of truth.
public final class FloorplanAuditStore {
    public static let shared = FloorplanAuditStore()
    private init() {}

    public private(set) var latestReport: [FloorplanAuditItem] = []

    public func update(_ report: [FloorplanAuditItem]) {
        latestReport = report
    }

    public func clear() {
        latestReport.removeAll()
    }
}

public class FloorplanEngine {
    public static let shared = FloorplanEngine()
    
    private init() {}
    
    // 生成演示标准三室两厅精装户型 (支持根据当前语言动态输出，杜绝英文下出现中文硬编码)
    public func generateSampleRooms() -> [FloorplanRoom] {
        let lang = LocalizationManager.shared.effectiveLanguage
        let doorName: String
        let livingName: String
        let masterName: String
        let studyName: String
        let secondBedName: String
        let kitchenName: String
        let bathroomName: String
        let balconyName: String
        
        switch lang {
        case .en:
            doorName = "Main Entrance (South Qi)"
            livingName = "Spacious Living Room"
            masterName = "Master Bedroom"
            studyName = "Quiet Study Room"
            secondBedName = "Second Bedroom"
            kitchenName = "Gourmet Kitchen"
            bathroomName = "Main Bathroom"
            balconyName = "South Balcony"
        case .zhHant:
            doorName = "入戶大門 (正南明堂納氣)"
            livingName = "聚氣大客廳"
            masterName = "尊貴主臥"
            studyName = "文昌靜雅書房"
            secondBedName = "靜心次臥"
            kitchenName = "膳食廚房"
            bathroomName = "主衛浴間"
            balconyName = "南向大陽台"
        case .ja:
            doorName = "正面玄関（正南明堂納気）"
            livingName = "集気リビング"
            masterName = "主寝室"
            studyName = "文昌書斎"
            secondBedName = "静心寝室"
            kitchenName = "キッチン"
            bathroomName = "主浴室・トイレ"
            balconyName = "南向きバルコニー"
        case .ko:
            doorName = "현관문 (남향 명당 납기)"
            livingName = "거실"
            masterName = "안방 (주침실)"
            studyName = "문창 서재"
            secondBedName = "작은방 (침실)"
            kitchenName = "주방"
            bathroomName = "주욕실"
            balconyName = "남향 발코니"
        case .vi:
            doorName = "Cửa chính (Nam minh đường nạp khí)"
            livingName = "Phòng khách tụ khí"
            masterName = "Phòng ngủ chính"
            studyName = "Phòng đọc sách Văn Xương"
            secondBedName = "Phòng ngủ phụ"
            kitchenName = "Nhà bếp"
            bathroomName = "Phòng tắm chính"
            balconyName = "Ban công hướng Nam"
        case .th:
            doorName = "ประตูใหญ่ (รับชี่ทิศใต้)"
            livingName = "ห้องรับแขกเปิดกว้าง"
            masterName = "ห้องนอนใหญ่"
            studyName = "ห้องหนังสือ"
            secondBedName = "ห้องนอนเล็ก"
            kitchenName = "ห้องครัว"
            bathroomName = "ห้องน้ำหลัก"
            balconyName = "ระเบียงทิศใต้"
        case .id:
            doorName = "Pintu Utama (Penerima Qi Selatan)"
            livingName = "Ruang Tamu Lapang"
            masterName = "Kamar Tidur Utama"
            studyName = "Ruang Belajar Tenang"
            secondBedName = "Kamar Tidur Kedua"
            kitchenName = "Dapur Bersih"
            bathroomName = "Kamar Mandi Utama"
            balconyName = "Balkon Menghadap Selatan"
        case .zhHans, .auto:
            doorName = "入户大门 (正南明堂纳气)"
            livingName = "聚气大客厅"
            masterName = "尊贵主卧"
            studyName = "文昌静雅书房"
            secondBedName = "静心次卧"
            kitchenName = "膳食厨房"
            bathroomName = "主卫浴间"
            balconyName = "南向大阳台"
        }
        
        return [
            FloorplanRoom(
                name: doorName,
                type: .door,
                rect: CGRect(x: 0.40, y: 0.82, width: 0.20, height: 0.12)
            ),
            FloorplanRoom(
                name: livingName,
                type: .livingRoom,
                rect: CGRect(x: 0.32, y: 0.45, width: 0.38, height: 0.36)
            ),
            FloorplanRoom(
                name: masterName,
                type: .masterBedroom,
                rect: CGRect(x: 0.70, y: 0.42, width: 0.25, height: 0.45)
            ),
            FloorplanRoom(
                name: studyName,
                type: .study,
                rect: CGRect(x: 0.32, y: 0.10, width: 0.35, height: 0.30)
            ),
            FloorplanRoom(
                name: secondBedName,
                type: .secondBedroom,
                rect: CGRect(x: 0.70, y: 0.10, width: 0.25, height: 0.30)
            ),
            FloorplanRoom(
                name: kitchenName,
                type: .kitchen,
                rect: CGRect(x: 0.05, y: 0.10, width: 0.24, height: 0.30)
            ),
            FloorplanRoom(
                name: bathroomName,
                type: .bathroom,
                rect: CGRect(x: 0.05, y: 0.45, width: 0.24, height: 0.25)
            ),
            FloorplanRoom(
                name: balconyName,
                type: .balcony,
                // 右下角阳台：与左下大门 (0.40-0.60)×(0.82-0.94) 保持 x 向不重叠
                rect: CGRect(x: 0.62, y: 0.88, width: 0.30, height: 0.10)
            )
        ]
    }
    
    // MARK: - 多边形识别辅助（识别管线升级：真实轮廓优先，矩形退化）

    /// 房间实际面积（优先多边形轮廓，退化回矩形）
    public static func roomArea(_ room: FloorplanRoom) -> CGFloat {
        if let pts = room.polygonPoints, pts.count >= 3 {
            return GeometryUtils.polygonArea(pts)
        }
        return room.rect.width * room.rect.height
    }

    public static func roomContains(_ room: FloorplanRoom, point: CGPoint) -> Bool {
        if let points = room.polygonPoints, points.count >= 3 {
            return GeometryUtils.polygonContains(point, points: points)
        }
        return room.rect.contains(point)
    }

    /// 房间几何质心（优先多边形质心，退化回矩形中心）
    public static func roomCentroid(_ room: FloorplanRoom) -> CGPoint {
        if let pts = room.polygonPoints, pts.count >= 3 {
            let c = GeometryUtils.polygonCentroid(pts)
            return CGPoint(x: max(0, min(1, c.x)), y: max(0, min(1, c.y)))
        }
        return CGPoint(x: room.rect.midX, y: room.rect.midY)
    }

    /// 全屋面积加权质心（立极中宫）：各房间真实面积 × 房间质心
    public static func roomsCentroid(_ rooms: [FloorplanRoom]) -> CGPoint {
        var totalArea: CGFloat = 0
        var weightedX: CGFloat = 0
        var weightedY: CGFloat = 0
        for room in rooms where room.type != .missingCorner {
            let area = roomArea(room)
            guard area > 0 else { continue }
            let c = roomCentroid(room)
            totalArea += area
            weightedX += c.x * area
            weightedY += c.y * area
        }
        guard totalArea > 0 else { return CGPoint(x: 0.5, y: 0.5) }
        return CGPoint(
            x: max(0.05, min(0.95, weightedX / totalArea)),
            y: max(0.05, min(0.95, weightedY / totalArea))
        )
    }

    /// 规则式房间类型推断：依据相对面积与纵横比 + 已用类型，给出最可能类型
    /// - Parameters:
    ///   - areaRatio: 候选面积占画布面积比例 (0..1)
    ///   - aspectRatio: 候选宽高比（>1 表示横向）
    ///   - existing: 当前已确认房间（避免重复分配主卧/客厅等唯一类型）
    public static func inferRoomType(areaRatio: CGFloat, aspectRatio: CGFloat, existing: [FloorplanRoom]) -> FloorplanRoomType? {
        let used = Set(existing.map { $0.type })
        // 细长区域（长走廊/阳台）优先判为阳台
        if aspectRatio > 2.6 && !used.contains(.balcony) {
            return .balcony
        }
        // 极小面积优先卫浴/书房
        if areaRatio < 0.06 {
            if !used.contains(.bathroom) { return .bathroom }
            if !used.contains(.study) { return .study }
        }
        // 其余按常见户型主次分配第一个未占用类型
        let candidateOrder: [FloorplanRoomType] = [
            .livingRoom, .masterBedroom, .secondBedroom, .study, .kitchen, .bathroom, .balcony, .door
        ]
        for type in candidateOrder where !used.contains(type) {
            return type
        }
        return nil
    }

    // 根据户型重心立极点与罗盘朝向解算各房间八卦方位与全屋风水体检报告
    public func auditFloorplan(rooms: [FloorplanRoom], centroid: CGPoint, heading: Double, aspectRatio: CGFloat = 1, date: Date = Date()) -> (auditedRooms: [FloorplanRoom], report: [FloorplanAuditItem]) {
        var updatedRooms: [FloorplanRoom] = []
        var auditReport: [FloorplanAuditItem] = []
        
        let language = LocalizationManager.shared.effectiveLanguage
        let centralRoomID = rooms
            .filter { $0.type != .missingCorner && Self.roomContains($0, point: centroid) }
            .min {
                Self.roomArea($0) < Self.roomArea($1)
            }?.id
        let manualMissingGua = Set(rooms.filter { $0.type == .missingCorner }.map {
            palaceForPoint(Self.roomCentroid($0), centroid: centroid, heading: heading, aspectRatio: aspectRatio).gua
        })
        let pwChart = PurpleWhiteEngine.shared.calculateChart(date: date, heading: heading)
        
        for room in rooms {
            var r = room
            let palace: (dir: String, gua: String)
            if room.type != .missingCorner && room.id == centralRoomID {
                switch language {
                case .en: palace = ("Center", "Center")
                case .zhHant: palace = ("中央", "中")
                case .ja: palace = ("中央", "中")
                case .ko: palace = ("중앙", "중")
                case .vi: palace = ("Trung tâm", "Trung")
                case .th: palace = ("จุดศูนย์กลาง", "กลาง")
                case .id: palace = ("Pusat", "Tengah")
                case .auto, .zhHans: palace = ("中央", "中")
                }
            } else {
                palace = palaceForPoint(
                    Self.roomCentroid(room),
                    centroid: centroid,
                    heading: heading,
                    aspectRatio: aspectRatio
                )
            }
            switch language {
            case .en: r.palaceName = "\(palace.dir) (\(palace.gua) Palace)"
            case .zhHant, .ja: r.palaceName = "\(palace.dir) \(palace.gua)宮"
            case .ko: r.palaceName = "\(palace.dir) \(palace.gua)궁"
            case .vi: r.palaceName = "\(palace.dir) Cung \(palace.gua)"
            case .th: r.palaceName = "\(palace.dir) วัง\(palace.gua)"
            case .id: r.palaceName = "\(palace.dir) (Istana \(palace.gua))"
            default: r.palaceName = "\(palace.dir) \(palace.gua)宫"
            }
            
            if r.type == .missingCorner {
                let content = missingCornerContent(gua: palace.gua)
                r.name = r.type.localizedName
                r.inspectionTitle = content.title
                r.inspectionLevel = "预警"
                let lore = missingCornerLoreWithSource(gua: palace.gua, lore: content.lore)
                r.inspectionLore = lore
                r.inspectionAdvice = content.solution
                updatedRooms.append(r)
                auditReport.append(FloorplanAuditItem(
                    id: "manual-missing-corner-\(room.id)",
                    title: "\(r.type.localizedName) · \(content.title)",
                    palace: r.palaceName,
                    severity: "预警",
                    lore: lore,
                    solution: content.solution
                ))
                continue
            }

            // 风水动态研判（叠加宅主本命卦四吉四凶 + 流年紫白飞星交叉断事）
            let audit = evaluateRoom(type: r.type, palaceGua: palace.gua, palaceDir: palace.dir)
            let crossSuffix = crossModuleLoreSuffix(palaceGua: palace.gua, pwChart: pwChart)
            let combinedLore = crossSuffix.isEmpty ? audit.lore : "\(audit.lore)\n\(crossSuffix)"
            r.name = r.type.localizedName
            r.inspectionTitle = audit.title
            r.inspectionLevel = audit.level
            r.inspectionLore = combinedLore
            r.inspectionAdvice = audit.advice
            
            updatedRooms.append(r)
            
            // Keep balanced rooms in the report as well. Their explanatory
            // text and maintenance advice are part of the complete floorplan
            // snapshot and must be available to the long-scroll export; the
            // previous warning-only filter silently dropped those remedies.
            auditReport.append(FloorplanAuditItem(
                id: "room-\(room.id)",
                title: "\(r.type.localizedName) · \(audit.title)",
                palace: r.palaceName,
                severity: audit.level,
                lore: combinedLore,
                solution: audit.advice
            ))
        }

        auditReport.append(contentsOf: missingCornerAudits(
            rooms: rooms,
            centroid: centroid,
            heading: heading,
            aspectRatio: aspectRatio,
            excludingGua: manualMissingGua
        ))
        
        // 增加穿堂煞与中宫检测
        if auditReport.isEmpty {
            let hasValidRoom = rooms.contains {
                $0.type != .missingCorner && $0.rect.width > 0 && $0.rect.height > 0
            }
            let title: String
            let palace: String
            let lore: String
            let solution: String
            if hasValidRoom {
                switch language {
                case .en:
                    title = "Balanced Whole-Home Qi"
                    palace = "Whole Home"
                    lore = "Every functional area is well positioned, with activity separated and yin-yang in harmony."
                    solution = "Keep the home bright and ventilated, with living plants to support steady family fortune."
                case .zhHant:
                    title = "全屋空間氣場中和純清"
                    palace = "全局"
                    lore = "各功能區方位得所，動靜分離，陰陽調和。"
                    solution = "保持居室明亮通風，綠植點綴，可常保家運昌隆。"
                case .ja:
                    title = "全室の空間エネルギーの調和"
                    palace = "全般"
                    lore = "各部屋の配置が調和し、動と静が分かれ、陰陽のバランスが保たれています。"
                    solution = "明るく風通しの良い環境を保ち、観葉植物を飾ることで家庭運を安定させます。"
                case .ko:
                    title = "주택 전체 기운의 균형"
                    palace = "전체"
                    lore = "각 기능 구역의 방위가 조화를 이루고, 동선과 정숙함이 분리되어 음양이 화합합니다."
                    solution = "실내를 밝고 통풍이 잘 되게 유지하며, 화분을 배치하여 가운을 번창시키세요."
                case .vi:
                    title = "Sinh khí toàn gia hài hòa thanh tịnh"
                    palace = "Toàn cục"
                    lore = "Các khu vực chức năng được bố trí hợp cách, động tĩnh phân minh, âm dương hòa hợp."
                    solution = "Giữ nhà cửa sáng sủa thông thoáng, điểm xuyết cây xanh để gia vận hưng thịnh."
                case .th:
                    title = "ชี่ทั่วบ้านสมดุลและบริสุทธิ์"
                    palace = "ภาพรวม"
                    lore = "ทุกพื้นที่การใช้งานอยู่ในทิศทางที่เหมาะสม แยกโซนเงียบสงบและเคลื่อนไหวอย่างสมดุล"
                    solution = "รักษาบ้านให้สว่างและระบายอากาศได้ดี ตกแต่งด้วยต้นไม้เพื่อเสริมความรุ่งเรือง"
                case .id:
                    title = "Energi Seluruh Rumah Seimbang dan Harmonis"
                    palace = "Keseluruhan"
                    lore = "Setiap area fungsional berada di posisi yang baik, terpisah dengan rapi, dan yin-yang selaras."
                    solution = "Jaga rumah tetap terang dan berventilasi baik, hiasi tanaman hijau untuk rezeki stabil."
                case .auto, .zhHans:
                    title = "全屋空间气场中和纯清"
                    palace = "全局"
                    lore = "各功能区方位得所，动静分离，阴阳调和。"
                    solution = "保持居室内明亮通风，绿植点缀，可常保家运昌隆。"
                }
            } else {
                switch language {
                case .en:
                    title = "Floorplan Needs a Valid Room"
                    palace = "Whole Home"
                    lore = "Only missing-corner markers remain, or all room rectangles have zero area, so a Tai Ji center and room placement cannot be calculated."
                    solution = "Add at least one real room with a positive width and height, then place the Tai Ji point and run the audit again."
                case .zhHant:
                    title = "戶型缺少有效房間"
                    palace = "全局"
                    lore = "目前只剩戶型缺角標記，或所有房間框面積為零，無法計算立極中宮與房間方位。"
                    solution = "請至少新增一個有實際寬高的房間，再設定立極點並重新體檢。"
                case .ja:
                    title = "有効な部屋の配置が必要です"
                    palace = "全般"
                    lore = "部屋の面積がゼロであるか欠けのみのため、太極中宮を算出できません。"
                    solution = "少なくとも1つの部屋を追加してから立極点を設定してください。"
                case .ko:
                    title = "유효한 방 배치가 필요합니다"
                    palace = "전체"
                    lore = "방 면적이 0이거나 결손 표기만 있어 태극 중궁을 계산할 수 없습니다."
                    solution = "최소 하나의 방을 추가한 후 입극점을 설정하여 다시 검진하세요."
                case .vi:
                    title = "Bản vẽ cần phòng hợp lệ"
                    palace = "Toàn cục"
                    lore = "Hiện chỉ có đánh dấu khuyết góc hoặc diện tích bằng 0, không thể tính trung cung."
                    solution = "Vui lòng thêm ít nhất một phòng có diện tích thực tế để thẩm định lại."
                case .th:
                    title = "ผังบ้านต้องการห้องที่ถูกต้อง"
                    palace = "ภาพรวม"
                    lore = "มีเพียงเครื่องหมายมุมแหว่งหรือไม่ระบุขนาดห้อง จึงไม่สามารถคำนวณจุดศูนย์กลางได้"
                    solution = "โปรดเพิ่มห้องจริงอย่างน้อยหนึ่งห้อง จากนั้นตั้งจุดศูนย์กลางแล้วตรวจใหม่อีกครั้ง"
                case .id:
                    title = "Denah Memerlukan Ruangan yang Valid"
                    palace = "Keseluruhan"
                    lore = "Hanya tersisa penanda sudut hilang atau luas area nol, sehingga pusat Tai Ji tidak dapat dihitung."
                    solution = "Tambahkan minimal satu ruangan nyata, lalu tentukan titik Tai Ji dan periksa kembali."
                case .auto, .zhHans:
                    title = "户型缺少有效房间"
                    palace = "全局"
                    lore = "当前只剩户型缺角标记，或所有房间框面积为零，无法计算立极中宫与房间方位。"
                    solution = "请至少新增一个有实际宽高的房间，再设置立极点并重新体检。"
                }
            }
            auditReport.append(FloorplanAuditItem(
                id: hasValidRoom ? "whole-home-balanced" : "floorplan-missing-valid-room",
                title: title,
                palace: palace,
                severity: hasValidRoom ? "吉" : "预警",
                lore: lore,
                solution: solution
            ))
        }
        
        return (updatedRooms, auditReport)
    }

    private func palaceForPoint(_ point: CGPoint, centroid: CGPoint, heading: Double, aspectRatio: CGFloat) -> (dir: String, gua: String) {
        let screenAngle = GeometryUtils.bearing(from: centroid, to: point, aspectRatio: aspectRatio)
        let geoAngle = (screenAngle + heading).truncatingRemainder(dividingBy: 360.0)
        return resolvePalace(geoAngle: geoAngle < 0 ? geoAngle + 360.0 : geoAngle)
    }

    private func missingCornerAudits(
        rooms: [FloorplanRoom],
        centroid: CGPoint,
        heading: Double,
        aspectRatio: CGFloat,
        excludingGua: Set<String>
    ) -> [FloorplanAuditItem] {
        let footprintRooms = rooms.filter {
            $0.type != .missingCorner && $0.rect.width > 0 && $0.rect.height > 0
        }
        guard !footprintRooms.isEmpty else { return [] }
        let bounds = footprintRooms.reduce(CGRect.null) { partial, room in
            partial.union(room.rect)
        }
        guard !bounds.isNull, bounds.width > 0.05, bounds.height > 0.05 else { return [] }

        let sectorWidth = bounds.width / 3.0
        let sectorHeight = bounds.height / 3.0
        // Check every outer cell of the 3×3 bagua grid. The previous
        // implementation only inspected the four corners, so a recessed
        // middle section on the east/south/west/north edge was silently
        // treated as a complete footprint.
        var sectors: [CGRect] = []
        for row in 0..<3 {
            for column in 0..<3 {
                guard row != 1 || column != 1 else { continue }
                sectors.append(CGRect(
                    x: bounds.minX + CGFloat(column) * sectorWidth,
                    y: bounds.minY + CGFloat(row) * sectorHeight,
                    width: sectorWidth,
                    height: sectorHeight
                ))
            }
        }
        let sectorArea = sectorWidth * sectorHeight
        guard sectorArea > 0 else { return [] }

        var results: [FloorplanAuditItem] = []
        // A custom layout can contain several small rooms in one sector and
        // can also have a shifted Tai Ji point that maps two geometric
        // sectors to the same eight-gua sector. Keep the emitted gua set
        // stable so a SwiftUI ForEach never receives duplicate report IDs.
        var emittedGua = excludingGua
        for sector in sectors {
            let occupiedArea = coveredArea(of: sector, by: footprintRooms)
            let occupied = occupiedArea / sectorArea >= 0.18
            guard !occupied else { continue }

            let center = CGPoint(x: sector.midX, y: sector.midY)
            let palace = palaceForPoint(center, centroid: centroid, heading: heading, aspectRatio: aspectRatio)
            guard !emittedGua.contains(palace.gua) else { continue }
            emittedGua.insert(palace.gua)
            let content = missingCornerContent(gua: palace.gua)
            let lore = missingCornerLoreWithSource(gua: palace.gua, lore: content.lore)
            results.append(FloorplanAuditItem(
                id: "missing-corner-\(palace.gua)",
                title: content.title,
                palace: palace.dir,
                severity: "预警",
                lore: lore,
                solution: content.solution
            ))
        }
        return results
    }

    /// Returns the exact union area of axis-aligned room rectangles clipped to
    /// one grid sector. Summing each overlap would count overlapping custom
    /// rooms twice, while checking only one room misses a sector assembled from
    /// several smaller rooms. A sweep over the rectangles' x breakpoints keeps
    /// this calculation deterministic and inexpensive (only eight sectors).
    private func coveredArea(of sector: CGRect, by rooms: [FloorplanRoom]) -> CGFloat {
        let clipped = rooms.compactMap { room -> CGRect? in
            let intersection = room.rect.intersection(sector)
            guard !intersection.isNull,
                  intersection.width > 0,
                  intersection.height > 0 else { return nil }
            return intersection
        }
        guard !clipped.isEmpty else { return 0 }

        var xBreakpoints: [CGFloat] = [sector.minX, sector.maxX]
        for rect in clipped {
            xBreakpoints.append(rect.minX)
            xBreakpoints.append(rect.maxX)
        }
        xBreakpoints.sort()

        var area: CGFloat = 0
        for index in 0..<(xBreakpoints.count - 1) {
            let x0 = xBreakpoints[index]
            let x1 = xBreakpoints[index + 1]
            let width = x1 - x0
            guard width > 0 else { continue }
            let x = (x0 + x1) / 2
            let yIntervals = clipped.compactMap { rect -> (CGFloat, CGFloat)? in
                guard x > rect.minX, x < rect.maxX else { return nil }
                return (rect.minY, rect.maxY)
            }.sorted { $0.0 < $1.0 }
            guard !yIntervals.isEmpty else { continue }

            var coveredHeight: CGFloat = 0
            var currentStart = yIntervals[0].0
            var currentEnd = yIntervals[0].1
            for interval in yIntervals.dropFirst() {
                if interval.0 <= currentEnd {
                    currentEnd = max(currentEnd, interval.1)
                } else {
                    coveredHeight += currentEnd - currentStart
                    currentStart = interval.0
                    currentEnd = interval.1
                }
            }
            coveredHeight += currentEnd - currentStart
            area += width * coveredHeight
        }
        return area
    }

    private func tr8(
        _ hans: String,
        _ hant: String,
        _ en: String,
        _ ja: String,
        _ ko: String,
        _ vi: String,
        _ th: String,
        _ id: String
    ) -> String {
        switch LocalizationManager.shared.effectiveLanguage {
        case .zhHant: return hant
        case .en: return en
        case .ja: return ja
        case .ko: return ko
        case .vi: return vi
        case .th: return th
        case .id: return id
        case .auto, .zhHans: return hans
        }
    }

    /// 跨模块交叉断事：将「流年紫白飞星落宫」与「宅主本命卦四吉四凶」注入户型房间体检结果
    private func crossModuleLoreSuffix(palaceGua: String, pwChart: PurpleWhiteChart) -> String {
        let canonGua: String
        let palaceId: Int
        switch palaceGua {
        case "坎", "Kan", "감", "Khảm", "ข่าน":
            canonGua = "坎"; palaceId = 1
        case "坤", "Kun", "곤", "Khôn", "คุน":
            canonGua = "坤"; palaceId = 2
        case "震", "Zhen", "진", "Chấn", "เจิ้น":
            canonGua = "震"; palaceId = 3
        case "巽", "Xun", "손", "Tốn", "ซวิ่น":
            canonGua = "巽"; palaceId = 4
        case "乾", "Qian", "건", "Càn", "เฉียน":
            canonGua = "乾"; palaceId = 6
        case "兑", "兌", "Dui", "태", "Đoài", "ตุ้ย":
            canonGua = "兑"; palaceId = 7
        case "艮", "Gen", "간", "Cấn", "เกิ่น":
            canonGua = "艮"; palaceId = 8
        case "离", "離", "Li", "이", "Ly", "หลี":
            canonGua = "离"; palaceId = 9
        default:
            canonGua = "中"; palaceId = 5
        }

        var parts: [String] = []
        if let pwItem = pwChart.palaceItems.first(where: { $0.palaceId == palaceId }) {
            let starTitle = pwItem.starName
            let shaWarn: String
            if pwItem.isTaiSui {
                shaWarn = tr8("（犯流年太岁）", "（犯流年太歲）", " (Annual Tai Sui)", "（流年太歳）", " (유년 태세)", " (Phạm Thái Tuế)", " (ไท่ส่วยประจำปี)", " (Tai Sui Tahunan)")
            } else if pwItem.isSuiPo {
                shaWarn = tr8("（犯岁破）", "（犯歲破）", " (Year Breaker)", "（歳破）", " (세파)", " (Tuế Phá)", " (ส่วยพั่ว)", " (Sui Po)")
            } else if pwItem.isSanSha {
                shaWarn = tr8("（犯三煞）", "（犯三煞）", " (Three Killings)", "（三煞）", " (삼살)", " (Tam Sát)", " (ซานซา)", " (Tiga Sha)")
            } else {
                shaWarn = ""
            }
            parts.append(
                tr8(
                    "【流年紫白】\(starTitle)\(shaWarn)",
                    "【流年紫白】\(starTitle)\(shaWarn)",
                    "[Annual Star] \(starTitle)\(shaWarn)",
                    "【流年紫白】\(starTitle)\(shaWarn)",
                    "[유년자백] \(starTitle)\(shaWarn)",
                    "[Lưu Niên] \(starTitle)\(shaWarn)",
                    "[ดาวประจำปี] \(starTitle)\(shaWarn)",
                    "[Bintang Tahunan] \(starTitle)\(shaWarn)"
                )
            )
        }

        let kuaProfile = UserKuaProfileManager.shared
        if kuaProfile.canUsePersonalAnalysis && canonGua != "中" {
            let ownerBz = BaZhaiEngine.shared.analyze(sittingPalace: kuaProfile.ownerGuaKey, facingPalace: "离")
            if let ownerItem = ownerBz.items.first(where: { $0.guaName == canonGua }) {
                let sName = ownerItem.star.localizedName
                parts.append(
                    tr8(
                        "【宅主本命】落\(sName)",
                        "【宅主本命】落\(sName)",
                        "[Owner Life Gua] \(sName)",
                        "【家主本命】\(sName)",
                        "[건축주 본명] \(sName)",
                        "[Bản Mệnh Chủ] \(sName)",
                        "[รหัสชีวิตเจ้าของ] \(sName)",
                        "[Gua Pemilik] \(sName)"
                    )
                )
            }
        }

        return parts.joined(separator: " · ")
    }

    /// Adds the classical source and plain-language context to the two
    /// missing-corner sectors whose traditional interpretation includes
    /// wealth or water-flow language. The Chinese strings already contain
    /// their citations; this keeps the other localized reports equally
    /// explicit without replacing the original judgment.
    private func missingCornerLoreWithSource(gua: String, lore: String) -> String {
        let isXun = ["巽", "Xun", "손", "Tốn", "ซวิ่น"].contains(gua)
        let isKan = ["坎", "Kan", "감", "Khảm", "ข่าน"].contains(gua)
        guard isXun || isKan else { return lore }
        let language = LocalizationManager.shared.effectiveLanguage
        let source: String
        if isXun {
            switch language {
            case .en: source = "Classical source: the Book of Changes, Discussion of the Trigrams, says ‘Xun is Wood, Wind, the eldest daughter and entering.’ Later yang-house traditions extend this to wealth and networks."
            case .ja: source = "出典：『易経・説卦伝』「巽は木、風、長女、入」。後世の陽宅論では財・人脈・資源の流れに引き継ぎます。"
            case .ko: source = "출처: 《주역·설괘전》 ‘손은 나무·바람·장녀·들어감’이라 하며, 후대 양택론은 이를 재물·인맥·자원 흐름으로 풀이합니다."
            case .vi: source = "Nguồn: 《Kinh Dịch·Thuyết Quái》 ghi ‘Tốn là Mộc, là Gió, con gái trưởng và sự đi vào’; dương trạch hậu thế diễn giải thêm về tài lộc, quan hệ và dòng nguồn lực."
            case .th: source = "แหล่งที่มา: 《อี้จิง·ซัวกว้า》กล่าวว่า ‘ซวิ่นคือไม้ ลม บุตรสาวคนโต และการเข้า’; ตำราหยางไจ๋ภายหลังขยายความเป็นทรัพย์ เครือข่าย และการไหลของทรัพยากร"
            case .id: source = "Sumber klasik: 《I Ching·Shuo Gua》 menyebut ‘Xun adalah Kayu, Angin, putri sulung dan memasuki’; tradisi yang zhai kemudian mengaitkannya dengan rezeki, jaringan dan arus sumber daya."
            case .zhHant, .zhHans, .auto: source = ""
            }
        } else {
            switch language {
            case .en: source = "Classical source: the Book of Changes, Discussion of the Trigrams, says ‘Kan is Water, channels and concealment.’ Later yang-house traditions extend this to wealth flow and drainage."
            case .ja: source = "出典：『易経・説卦伝』「坎は水、溝瀆、隠伏」。後世の陽宅論では財の流れと水回りに引き継ぎます。"
            case .ko: source = "출처: 《주역·설괘전》 ‘감은 물·도랑·숨음’이라 하며, 후대 양택론은 이를 재물 흐름과 배수로 풀이합니다."
            case .vi: source = "Nguồn: 《Kinh Dịch·Thuyết Quái》 ghi ‘Khảm là Nước, mương rãnh và ẩn phục’; dương trạch hậu thế diễn giải thêm về dòng tài lộc và thoát nước."
            case .th: source = "แหล่งที่มา: 《อี้จิง·ซัวกว้า》กล่าวว่า ‘ข่านคือน้ำ คูคลอง และการซ่อนเร้น’; ตำราหยางไจ๋ภายหลังขยายความเป็นกระแสทรัพย์และทางระบายน้ำ"
            case .id: source = "Sumber klasik: 《I Ching·Shuo Gua》 menyebut ‘Kan adalah Air, saluran dan tersembunyi’; tradisi yang zhai kemudian mengaitkannya dengan arus rezeki dan drainase."
            case .zhHant, .zhHans, .auto: source = ""
            }
        }
        guard !source.isEmpty else { return lore }
        return "\(lore) \(source)"
    }

    private func missingCornerContent(gua: String) -> (title: String, lore: String, solution: String) {
        switch gua {
        case "乾", "Qian", "건", "Càn", "เฉียน":
            return (
                tr8(
                    "户型缺角 · 西北乾位", "戶型缺角 · 西北乾位", "Missing Corner · Northwest Qian",
                    "間取りの欠け・北西乾位", "평면 결손 · 서북 건위", "Khuyết góc nhà · Tây Bắc Càn vị",
                    "มุมเว้าแหว่ง · ทิศตะวันตกเฉียงเหนือเฉียน", "Sudut Hilang · Barat Laut Qian"
                ),
                tr8(
                    "西北乾位缺角常被用于提示家中长辈、男主人、事业支持和居住稳定性方面需要关注；当前判断基于房间框，需先核对真实外墙。",
                    "西北乾位缺角常被用於提示家中長輩、男主人、事業支持和居住穩定性方面需要關注；當前判斷基於房間框，需先核對真實外牆。",
                    "A northwest Qian gap is traditionally associated with elder support, the male householder, career backing and stability; verify the actual exterior wall because this result is inferred from room boxes.",
                    "北西の乾位の欠けは家長、父親、事業の後援および居住の安定性に留意が必要とされます。外壁の現況をご確認ください。",
                    "서북 건위 결손은 집안 어른, 가장, 사업적 후원 및 주거 안정성과 연관됩니다. 실제 외벽 상태를 먼저 확인하세요.",
                    "Khuyết góc Tây Bắc Càn vị thường báo hiệu cần chú ý đến người lớn tuổi, gia chủ nam, vận thế sự nghiệp và sự ổn định gia trạch.",
                    "มุมเว้าแหว่งทิศตะวันตกเฉียงเหนือเฉียน บ่งชี้ถึงสุขภาพผู้นำครอบครัว การเกื้อหนุนในหน้าที่การงาน และความมั่นคง ควรตรวจสอบผนังจริง อ้างอิงตำราฮวงจุ้ยโบราณ; ถ้อยคำเรื่องสุขภาพเป็นสัญลักษณ์ทางวัฒนธรรม ไม่ใช่การวินิจฉัยทางการแพทย์",
                    "Kekurangan sudut barat laut Qian dikaitkan dengan dukungan tetua, kepala keluarga, stabilitas karir dan rumah tangga."
                ),
                tr8(
                    "首选补足真实外墙或封闭式储物/设备空间；无法改造时，可用圆形金属灯具、白色或金色圆器、稳固高柜作视觉补足，保持干燥明亮，避免以大型水景或杂物堆积代替。",
                    "首選補足真實外牆或封閉式儲物／設備空間；無法改造時，可用圓形金屬燈具、白色或金色圓器、穩固高櫃作視覺補足，保持乾燥明亮，避免以大型水景或雜物堆積代替。",
                    "Prefer completing the exterior wall or using an enclosed storage/service space. If construction is impossible, use a round metal light, white or gold circular decor, or a stable tall cabinet as a visual countermeasure; keep it dry and bright, and avoid a large water feature or clutter.",
                    "外壁の補修や収納スペースの増設を推奨します。改造できない場合は丸型金属照明や安定感のある家具で補い、明るく保ちます。",
                    "외벽 보완이나 수납공간 배치를 권장합니다. 시공이 어려울 경우 원형 금속 조명, 금색 원형 소품, 견고한 수납장으로 보완하세요.",
                    "Ưu tiên hoàn thiện tường ngoài hoặc bố trí tủ chứa đồ kín. Nếu không thể cải tạo, dùng đèn kim loại tròn, vật phẩm tròn màu trắng kim.",
                    "แนะนำให้ปิดผนังให้สมบูรณ์ หรือใช้ตู้เก็บของแบบทึบ หากแก้ไขไม่ได้ ให้ใช้โคมไฟโลหะทรงกลม ของตกแต่งสีทองหรือขาวเพื่อเสริมพลัง",
                    "Lengkapi dinding luar atau pasang lemari tertutup; jika tidak memungkinkan, gunakan lampu logam bundar, dekorasi emas/putih bulat, atau kabinet kokoh."
                )
            )
        case "艮", "Gen", "간", "Cấn", "เกิ่น":
            return (
                tr8(
                    "户型缺角 · 东北艮位", "戶型缺角 · 東北艮位", "Missing Corner · Northeast Gen",
                    "間取りの欠け・北東艮位", "평면 결손 · 동북 간위", "Khuyết góc nhà · Đông Bắc Cấn vị",
                    "มุมเว้าแหว่ง · ทิศตะวันออกเฉียงเหนือเกิ่น", "Sudut Hilang · Timur Laut Gen"
                ),
                tr8(
                    "东北艮位缺角常被用于提示家庭稳定、子女成长、学习专注和储藏空间方面需要关注；当前判断基于房间框，需先核对真实外墙。",
                    "東北艮位缺角常被用於提示家庭穩定、子女成長、學習專注和儲藏空間方面需要關注；當前判斷基於房間框，需先核對真實外牆。",
                    "A northeast Gen gap is traditionally associated with household stability, children, study focus and storage; verify the actual exterior wall because this result is inferred from room boxes.",
                    "北東の艮位の欠けは家庭の安定、子どもの学業や成長、保管空間に留意が必要とされます。",
                    "동북 간위 결손은 가족의 안정, 자녀의 성장 및 학업 집중도와 연관됩니다. 실제 외벽 구조를 점검하세요.",
                    "Khuyết góc Đông Bắc Cấn vị liên quan đến sự ổn định gia đình, sự phát triển học tập của con cái và không gian tích trữ.",
                    "มุมเว้าแหว่งทิศตะวันออกเฉียงเหนือเกิ่น ส่งผลต่อความมั่นคงในครอบครัว การเติบโตและการเรียนรู้ของบุตรหลาน",
                    "Kekurangan sudut timur laut Gen dikaitkan dengan kestabilan rumah, tumbuh kembang anak, dan fokus belajar."
                ),
                tr8(
                    "首选补足墙体或设置封闭、整洁的储物柜；无法改造时，可放置黄色陶瓷、天然石材、方形地毯或暖色灯光作稳定补足，保持安静干燥，避免潮湿和杂乱。",
                    "首選補足牆體或設置封閉、整潔的儲物櫃；無法改造時，可放置黃色陶瓷、天然石材、方形地毯或暖色燈光作穩定補足，保持安靜乾燥，避免潮濕和雜亂。",
                    "Prefer completing the wall or adding a closed, orderly cabinet. If construction is impossible, use yellow ceramic, natural stone, a square rug or warm lighting to add visual stability; keep the area quiet and dry.",
                    "収納棚の設置を推奨します。黄色い陶器や天然石、四角いラグマットを配置して気を安定させます。",
                    "벽체를 보강하거나 수납장을 배치하세요. 노란색 도자기, 천연석, 사각형 러그나 따뜻한 조명으로 안정감을 보강하세요.",
                    "Nên bổ sung tường hoặc kê tủ kín gọn gàng. Có thể dùng gốm sứ màu vàng, đá tự nhiên, thảm vuông hoặc đèn ánh sáng ấm.",
                    "กั้นผนังหรือวางตู้เก็บของให้เป็นระเบียบ หรือจัดวางแจกันเซรามิกสีเหลือง หินธรรมชาติ พรมทรงสี่เหลี่ยม และไฟโทนอุ่น",
                    "Lengkapi dinding atau pasang lemari tertutup; gunakan keramik kuning, batu alam, karpet persegi, atau lampu hangat untuk stabilitas."
                )
            )
        case "巽", "Xun", "손", "Tốn", "ซวิ่น":
            return (
                tr8(
                    "户型缺角 · 东南巽位", "戶型缺角 · 東南巽位", "Missing Corner · Southeast Xun",
                    "間取りの欠け・南東巽位", "평면 결손 · 동남 손위", "Khuyết góc nhà · Đông Nam Tốn vị",
                    "มุมเว้าแหว่ง · ทิศตะวันออกเฉียงใต้ซวิ่น", "Sudut Hilang · Tenggara Xun"
                ),
                tr8(
                    "东南巽位缺角常被用于提示财务规划、资源流动、沟通关系和通风采光方面需要关注；出处：《易经·说卦传》：“巽为木，为风，为长女，为入。”传统阳宅缺角论将巽位引申为财帛、人脉与资源流动。解释：以上是古籍方位象征，当前判断基于房间框，需先核对真实外墙，财务事项请独立核实。",
                    "東南巽位缺角常被用於提示財務規劃、資源流動、溝通關係和通風採光方面需要關注；出處：《易經·說卦傳》：「巽為木，為風，為長女，為入。」傳統陽宅缺角論將巽位引申為財帛、人脈與資源流動。解釋：以上是古籍方位象徵，當前判斷基於房間框，需先核對真實外牆，財務事項請獨立核實。",
                    "A southeast Xun gap is traditionally associated with financial planning, resource flow, relationships, ventilation and daylight. The Book of Changes, Discussion of the Trigrams, says: ‘Xun is Wood, Wind, the eldest daughter and entering.’ Later yang-house traditions extend this to wealth and networks. Verify the actual exterior wall; check financial decisions independently.",
                    "南東の巽位の欠けは財政計画、人脈関係、風通しや日当たりに留意が必要とされます。",
                    "동남 손위 결손은 재정 계획, 자원 순환, 대인관계 및 채광·통풍에 주의가 필요함을 나타냅니다.",
                    "Khuyết góc Đông Nam Tốn vị liên quan đến tài chính, lưu thông của cải, giao tiếp xã hội và độ thông thoáng.",
                    "มุมเว้าแหว่งทิศตะวันออกเฉียงใต้ซวิ่น ส่งผลต่อการวางแผนการเงิน ความสัมพันธ์ และการระบายอากาศรับแสงแดด",
                    "Kekurangan sudut tenggara Xun dikaitkan dengan perencanaan keuangan, relasi sosial, serta ventilasi dan pencahayaan."
                ),
                tr8(
                    "首选补足外墙或设置连续的木质收纳/绿化界面；无法改造时，可用易养阔叶植物、木质柜体、青绿色软装和柔和照明作替代，保持通风，避免尖角、破损和堆物。",
                    "首選補足外牆或設置連續的木質收納／綠化界面；無法改造時，可用易養闊葉植物、木質櫃體、青綠色軟裝和柔和照明作替代，保持通風，避免尖角、破損和堆物。",
                    "Prefer completing the exterior wall or adding a continuous wood storage or planting boundary. If construction is impossible, use easy-care broad-leaf plants, wood cabinetry, teal-green textiles and soft lighting; keep ventilation clear and avoid sharp corners, damage and clutter.",
                    "木製キャビネットや観葉植物の設置を推奨します。青緑系のインテリアや柔らかな照明で補いましょう。",
                    "외벽 보강 또는 원목 수납장 배치를 권장합니다. 넓은 잎 식물, 청록색 패브릭, 부드러운 조명으로 기운을 북돋우세요.",
                    "Nên bổ sung tường hoặc vách gỗ. Có thể đặt cây xanh lá rộng, tủ gỗ, nội thất tông xanh lá và ánh sáng dịu nhẹ.",
                    "แนะนำให้ตกแต่งด้วยตู้ไม้ ต้นไม้ใบเขียวชอุ่ม ของตกแต่งโทนสีเขียว และแสงไฟนุ่มนวล ระบายอากาศให้โปร่งสบาย",
                    "Gunakan dinding kayu atau tanaman berdaun lebar, perabot kayu, dekorasi bernuansa hijau, dan pencahayaan lembut."
                )
            )
        case "坤", "Kun", "곤", "Khôn", "คุน":
            return (
                tr8(
                    "户型缺角 · 西南坤位", "戶型缺角 · 西南坤位", "Missing Corner · Southwest Kun",
                    "間取りの欠け・南西坤位", "평면 결손 · 서남 곤위", "Khuyết góc nhà · Tây Nam Khôn vị",
                    "มุมเว้าแหว่ง · ทิศตะวันตกเฉียงใต้คุน", "Sudut Hilang · Barat Daya Kun"
                ),
                tr8(
                    "西南坤位缺角常被用于提示家庭照料、伴侣关系、生活承托和居住安定方面需要关注；当前判断基于房间框，需先核对真实外墙。",
                    "西南坤位缺角常被用於提示家庭照料、伴侶關係、生活承托和居住安定方面需要關注；當前判斷基於房間框，需先核對真實外牆。",
                    "A southwest Kun gap is traditionally associated with caregiving, partnership, household support and stability; verify the actual exterior wall because this result is inferred from room boxes.",
                    "南西の坤位の欠けは家庭内のケア、夫婦関係、生活基盤の安定に留意が必要とされます。",
                    "서남 곤위 결손은 가족 돌봄, 부부 관계, 생활의 지지력 및 거주 안정성과 연관됩니다.",
                    "Khuyết góc Tây Nam Khôn vị nhắc nhở cần chú trọng đến tình cảm vợ chồng, sự bao dung và ổn định đời sống.",
                    "มุมเว้าแหว่งทิศตะวันตกเฉียงใต้คุน ส่งผลต่อความอบอุ่นในครอบครัว ความสัมพันธ์คู่ครอง และความมั่นคงในชีวิต",
                    "Kekurangan sudut barat daya Kun dikaitkan dengan keharmonisan pasangan, dukungan domestik, dan ketenangan hidup."
                ),
                tr8(
                    "首选补足墙体或设置低矮、稳定的封闭柜体；无法改造时，可用黄色或米色陶瓷、天然石材、方形地垫和暖光作替代，保持整洁稳定，避免空置、漏水和尖锐杂物。",
                    "首選補足牆體或設置低矮、穩定的封閉櫃體；無法改造時，可用黃色或米色陶瓷、天然石材、方形地墊和暖光作替代，保持整潔穩定，避免空置、漏水和尖銳雜物。",
                    "Prefer completing the wall or adding a low, stable closed cabinet. If construction is impossible, use yellow or beige ceramic, natural stone, a square mat and warm light; keep it orderly and stable, avoiding leaks and sharp clutter.",
                    "安定感のあるローキャビネットの設置を推奨します。黄色やベージュの陶器、天然石、角型マットで気を補いましょう。",
                    "낮고 안정된 수납장을 배치하세요. 황색이나 베이지색 도자기, 천연석, 사각 매트와 따뜻한 조명으로 보완하세요.",
                    "Nên bố trí tủ thấp vững chãi. Có thể đặt gốm sứ màu vàng/kem, đá tự nhiên, thảm vuông và đèn ánh sáng ấm.",
                    "จัดวางตู้ทึบทรงเตี้ยที่มั่นคง หรือใช้เครื่องปั้นดินเผาสีครีม/เหลือง หินธรรมชาติ พรมสี่เหลี่ยม และไฟโทนอบอุ่น",
                    "Gunakan lemari rendah yang stabil, keramik krem/kuning, batu alam, keset persegi, dan pencahayaan hangat."
                )
            )
        case "坎", "Kan", "감", "Khảm", "ข่าน":
            return (
                tr8(
                    "户型缺角 · 正北坎位", "戶型缺角 · 正北坎位", "Missing Corner · North Kan",
                    "間取りの欠け・正北坎位", "평면 결손 · 정북 감위", "Khuyết góc nhà · Chính Bắc Khảm vị",
                    "มุมเว้าแหว่ง · ทิศเหนือข่าน", "Sudut Hilang · Utara Kan"
                ),
                tr8(
                    "正北坎位缺角常被用于提示作息安全、情绪压力、财务流动和与水有关的使用空间；出处：《易经·说卦传》：“坎为水，为沟渎，为隐伏。”传统阳宅缺角论将坎位引申为财源、流动与水路。解释：以上是古籍方位象征，当前判断基于房间框，需先核对真实外墙、管线和排水，财务事项请独立核实。",
                    "正北坎位缺角常被用於提示作息安全、情緒壓力、財務流動和與水有關的使用空間；出處：《易經·說卦傳》：「坎為水，為溝瀆，為隱伏。」傳統陽宅缺角論將坎位引申為財源、流動與水路。解釋：以上是古籍方位象徵，當前判斷基於房間框，需先核對真實外牆、管線和排水，財務事項請獨立核實。",
                    "A north Kan gap is traditionally associated with rest, emotional pressure, financial flow and water-related utilities. The Book of Changes, Discussion of the Trigrams, says: ‘Kan is Water, channels and concealment.’ Later yang-house traditions extend this to wealth flow and drainage. Verify the exterior wall, pipes and drainage; check financial decisions independently.",
                    "北の坎位の欠けは休息の質、精神的ストレス、財の循環や配管・水回りの安全に留意が必要とされます。",
                    "정북 감위 결손은 휴식의 질, 감정적 스트레스, 재정 유동성 및 배수 상태와 연관됩니다.",
                    "Khuyết góc Chính Bắc Khảm vị nhắc nhở lưu ý đến giấc ngủ, áp lực tinh thần, dòng chảy tài chính và hệ thống cấp thoát nước.",
                    "มุมเว้าแหว่งทิศเหนือข่าน สัมพันธ์กับการพักผ่อน ความเครียด การหมุนเวียนของเงิน และระบบประปา",
                    "Kekurangan sudut utara Kan dikaitkan dengan kualitas istirahat, tekanan emosional, arus kas, dan saluran air."
                ),
                tr8(
                    "首选补足外墙并检查防水、排水和采光；无法改造时，可用深色稳重收纳、适度照明和金属/玻璃小件作替代，保持地面干燥，避免漏水、阴暗和大面积镜面。",
                    "首選補足外牆並檢查防水、排水和採光；無法改造時，可用深色穩重收納、適度照明和金屬／玻璃小件作替代，保持地面乾燥，避免漏水、陰暗和大面積鏡面。",
                    "Prefer completing the wall and checking waterproofing, drainage and daylight. If construction is impossible, use stable dark-toned storage, measured lighting and small metal or glass accents; keep floors dry and avoid leaks, darkness and large mirrors.",
                    "防水や排水を点検し壁を補強します。ダークトーンの落ち着いた収納棚や適切な照明で乾燥を保ちましょう。",
                    "외벽 및 방수·배수를 점검하세요. 짙은 색상의 안정감 있는 수납장, 적절한 조명과 금속 장식으로 건조하고 밝게 유지하세요.",
                    "Kiểm tra chống thấm thoát nước; dùng tủ lưu trữ màu sẫm vững chắc, bổ sung ánh sáng, giữ sàn nhà khô ráo thông thoáng.",
                    "ตรวจเช็กระบบกันซึมและทางระบายน้ำ ตกแต่งด้วยตู้โทนสีเข้ม ไฟส่องสว่างพอเหมาะ รักษาพื้นให้แห้งเสมอ",
                    "Periksa drainase dan kebocoran; gunakan tempat penyimpanan berwarna gelap, pencahayaan cukup, dan jaga lantai tetap kering."
                )
            )
        case "震", "Zhen", "진", "Chấn", "เจิ้น":
            return (
                tr8(
                    "户型缺角 · 正东震位", "戶型缺角 · 正東震位", "Missing Corner · East Zhen",
                    "間取りの欠け・正東震位", "평면 결손 · 정동 진위", "Khuyết góc nhà · Chính Đông Chấn vị",
                    "มุมเว้าแหว่ง · ทิศตะวันออกเจิ้น", "Sudut Hilang · Timur Zhen"
                ),
                tr8(
                    "正东震位缺角常被用于提示家庭行动力、长子成长、启动计划和日常通行；当前判断基于房间框，需先核对真实外墙和门窗。",
                    "正東震位缺角常被用於提示家庭行動力、長子成長、啟動計畫和日常通行；當前判斷基於房間框，需先核對真實外牆和門窗。",
                    "An east Zhen gap is traditionally associated with initiative, the eldest child, new plans and daily movement; verify the exterior wall, doors and windows because this result is inferred from room boxes.",
                    "東の震位の欠けは行動力、長男の成長、新たな計画の立ち上げや日常の動線に留意が必要とされます。",
                    "정동 진위 결손은 가족의 실행력, 장남의 성장, 새로운 계획의 추진력과 연관됩니다.",
                    "Khuyết góc Chính Đông Chấn vị liên quan đến sức sống, tính hành động, sự phát triển của trưởng nam và các kế hoạch mới.",
                    "มุมเว้าแหว่งทิศตะวันออกเจิ้น สัมพันธ์กับพลังขับเคลื่อน ความก้าวหน้าของบุตรชายคนโต และการเริ่มต้นสิ่งใหม่",
                    "Kekurangan sudut timur Zhen dikaitkan dengan inisiatif, putra sulung, dan permulaan rencana baru."
                ),
                tr8(
                    "首选补足外墙或形成连续的木质界面；无法改造时，可用易养绿植、竖向木柜、木质屏风和充足但不刺眼的照明作替代，保持通道顺畅，避免破损电器、尖角和杂物阻路。",
                    "首選補足外牆或形成連續的木質界面；無法改造時，可用易養綠植、豎向木櫃、木質屏風和充足但不刺眼的照明作替代，保持通道順暢，避免破損電器、尖角和雜物阻路。",
                    "Prefer completing the wall or creating a continuous wood boundary. If construction is impossible, use easy-care plants, vertical wood storage, a wood screen and even lighting; keep circulation clear and avoid damaged appliances, sharp corners and blocked paths.",
                    "木製の壁やパーテーションの増設を推奨します。観葉植物や木製家具、柔らかな照明で気の通りを良くします。",
                    "원목 파티션이나 수납장을 권장합니다. 싱싱한 식물, 키 큰 원목 가구, 충분한 조명으로 통로를 원활히 유지하세요.",
                    "Bổ sung tường hoặc vách ngăn gỗ. Bố trí cây xanh tươi tốt, tủ đứng bằng gỗ, bình phong gỗ và ánh sáng hài hòa.",
                    "เสริมแนวผนังไม้หรือระแนงไม้ ตกแต่งด้วยต้นไม้เขียวสดใส ตู้ไม้แนวตั้ง ฉากกั้นไม้ และเปิดทางเดินให้โล่งสบาย",
                    "Lengkapi dengan panel kayu atau sekat; tempatkan tanaman segar, lemari kayu vertikal, dan pencahayaan yang cukup."
                )
            )
        case "离", "Li", "이", "Ly", "หลี":
            return (
                tr8(
                    "户型缺角 · 正南离位", "戶型缺角 · 正南離位", "Missing Corner · South Li",
                    "間取りの欠け・正南離位", "평면 결손 · 정남 이위", "Khuyết góc nhà · Chính Nam Ly vị",
                    "มุมเว้าแหว่ง · ทิศใต้หลี", "Sudut Hilang · Selatan Li"
                ),
                tr8(
                    "正南离位缺角常被用于提示采光、可见度、表达沟通和家庭活力；当前判断基于房间框，需先核对真实外墙、窗户和消防条件。",
                    "正南離位缺角常被用於提示採光、可見度、表達溝通和家庭活力；當前判斷基於房間框，需先核對真實外牆、窗戶和消防條件。",
                    "A south Li gap is traditionally associated with daylight, visibility, communication and household vitality; verify the exterior wall, windows and fire-safety conditions because this result is inferred from room boxes.",
                    "南の離位の欠けは採光、自己表現、コミュニケーションや家庭の活気に留意が必要とされます。",
                    "정남 이위 결손은 채광, 대외적 명성, 소통 및 가족의 활력과 연관됩니다.",
                    "Khuyết góc Chính Nam Ly vị liên quan đến ánh sáng, danh tiếng, khả năng biểu đạt và sức sống của gia đình.",
                    "มุมเว้าแหว่งทิศใต้หลี สัมพันธ์กับแสงสว่าง ชื่อเสียง การสื่อสาร และความมีชีวิตชีวาของครอบครัว",
                    "Kekurangan sudut selatan Li dikaitkan dengan pencahayaan alami, reputasi, komunikasi, dan vitalitas keluarga."
                ),
                tr8(
                    "首选补足外墙并改善自然采光；无法改造时，可用合规的暖色照明、红紫色小面积软装和整洁的开放展示位作替代，避免明火、过热设备、遮挡逃生通道和过度反光。",
                    "首選補足外牆並改善自然採光；無法改造時，可用合規的暖色照明、紅紫色小面積軟裝和整潔的開放展示位作替代，避免明火、過熱設備、遮擋逃生通道和過度反光。",
                    "Prefer completing the wall and improving daylight. If construction is impossible, use code-compliant warm lighting, small red or purple accents and an orderly display area; avoid open flames, overheating devices, blocked exits and excessive glare.",
                    "採光を改善し壁を補完します。暖色系の照明やアクセントとしての赤・紫系のインテリアを活用します。",
                    "채광을 개선하고 벽을 보강하세요. 규격에 맞는 따뜻한 조명, 붉은색 계열 소품 및 깔끔한 장식 공간으로 보완하세요.",
                    "Cải thiện ánh sáng tự nhiên; dùng đèn ấm, điểm xuyết một chút sắc đỏ tím trang nhã và giữ khu vực gọn gàng.",
                    "ปรับปรุงการรับแสงธรรมชาติ ติดตั้งไฟโทนอุ่น ตกแต่งด้วยโทนสีแดงอมม่วงเล็กน้อย และจัดพื้นที่ให้โปร่งโล่งปลอดภัย",
                    "Tingkatkan pencahayaan; gunakan lampu hangat, aksen dekorasi merah/ungu kecil, dan tata area pajangan dengan rapi."
                )
            )
        case "兑", "Dui", "태", "Đoài", "ตุ้ย":
            return (
                tr8(
                    "户型缺角 · 正西兑位", "戶型缺角 · 正西兌位", "Missing Corner · West Dui",
                    "間取りの欠け・正西兌位", "평면 결손 · 정서 태위", "Khuyết góc nhà · Chính Tây Đoài vị",
                    "มุมเว้าแหว่ง · ทิศตะวันตกตุ้ย", "Sudut Hilang · Barat Dui"
                ),
                tr8(
                    "正西兑位缺角常被用于提示沟通表达、子女互动、收纳秩序和生活愉悦感；当前判断基于房间框，需先核对真实外墙和窗边空间。",
                    "正西兌位缺角常被用於提示溝通表達、子女互動、收納秩序和生活愉悅感；當前判斷基於房間框，需先核對真實外牆和窗邊空間。",
                    "A west Dui gap is traditionally associated with communication, children, storage order and enjoyment of daily life; verify the exterior wall and window-side space because this result is inferred from room boxes.",
                    "西の兌位の欠けは人間関係の調和、会話、収容秩序や生活の楽しみに留意が必要とされます。",
                    "정서 태위 결손은 원활한 대화, 자녀와의 교감, 수납 질서 및 생활의 기쁨과 연관됩니다.",
                    "Khuyết góc Chính Tây Đoài vị liên quan đến giao tiếp, tương tác với con cái, trật tự lưu trữ và niềm vui cuộc sống.",
                    "มุมเว้าแหว่งทิศตะวันตกตุ้ย ส่งผลต่อการพูดคุยสื่อสาร ปฏิสัมพันธ์กับลูกหลาน และความสุขในชีวิตประจำวัน",
                    "Kekurangan sudut barat Dui dikaitkan dengan komunikasi, keakraban anak, dan kerapian penyimpanan."
                ),
                tr8(
                    "首选补足外墙或设置整洁的封闭收纳；无法改造时，可用白色、金属色圆形物件、柔和灯光和易清洁材质作替代，保持安静整齐，避免尖锐金属、破损物品和噪声源。",
                    "首選補足外牆或設置整潔的封閉收納；無法改造時，可用白色、金屬色圓形物件、柔和燈光和易清潔材質作替代，保持安靜整齊，避免尖銳金屬、破損物品和噪聲源。",
                    "Prefer completing the wall or adding orderly closed storage. If construction is impossible, use white or metallic round objects, soft lighting and easy-clean materials; keep it quiet and orderly, avoiding sharp metal, damaged items and noise sources.",
                    "整然とした収納の設置を推奨します。白色やメタリックな丸型アイテム、優しい照明で整えましょう。",
                    "깔끔한 밀폐형 수납장을 배치하세요. 흰색 또는 메탈 원형 소품, 은은한 조명과 청결한 소재로 정돈하세요.",
                    "Bổ sung tường hoặc tủ chứa đồ gọn gàng. Có thể dùng đồ vật tròn màu trắng/ánh kim, ánh sáng êm dịu, giữ yên tĩnh sạch sẽ.",
                    "กั้นผนังหรือวางตู้เก็บของแบบมิดชิด ตกแต่งด้วยของทรงกลมสีขาวหรือสีเมทัลลิก แสงไฟนุ่มนวล และรักษาความสะอาดเงียบสงบ",
                    "Lengkapi dinding atau pasang lemari tertutup; gunakan dekorasi bundar putih/logam, lampu lembut, dan jaga ketenangan."
                )
            )
        default:
            return (
                tr8(
                    "户型缺角 · 当前方位", "戶型缺角 · 當前方位", "Missing Corner · Indicated Direction",
                    "間取りの欠け・該当方位", "평면 결손 · 해당 방위", "Khuyết góc nhà · Phương vị hiện tại",
                    "มุมเว้าแหว่ง · ทิศทางปัจจุบัน", "Sudut Hilang · Arah Terkait"
                ),
                tr8(
                    "房屋外接轮廓在当前方位出现空缺，可能影响户型边界完整性；当前结果基于房间框近似。",
                    "房屋外接輪廓在當前方位出現空缺，可能影響戶型邊界完整性；當前結果基於房間框近似。",
                    "The inferred footprint is open in the indicated direction; this result is an approximation based on room boxes.",
                    "建物の外郭輪郭に該当方位の欠けがあり、間取りの完全性に影響する可能性があります。",
                    "외곽 윤곽선의 해당 방위에 결손이 있어 평면의 완전성에 영향을 줄 수 있습니다.",
                    "Đường bao công trình ở phương vị này có khoảng trống, có thể ảnh hưởng đến sự vuông vức toàn diện.",
                    "ขอบเขตตัวอาคารในทิศทางนี้มีช่องเว้าแหว่ง อาจส่งผลต่อความสมบูรณ์ของรูปทรงบ้าน",
                    "Garis luar bangunan terbuka di arah ini, dapat mempengaruhi keutuhan bentuk rumah."
                ),
                tr8(
                    "核对对应外墙、阳台和附属空间，确认缺角是否真实存在。",
                    "核對對應外牆、陽台和附屬空間，確認缺角是否真實存在。",
                    "Check the corresponding exterior wall, balcony and attached spaces to confirm the actual outline.",
                    "外壁やベランダ、付帯空間を確認し、欠けの有無を実地でご確認ください。",
                    "해당 외벽, 발코니 및 부속 공간을 대조하여 실제 결손 여부를 확인하세요.",
                    "Đối chiếu tường ngoài, ban công và các không gian phụ để xác nhận góc khuyết thực tế.",
                    "ตรวจสอบแนวผนัง ระเบียง และพื้นที่ต่อเนื่อง เพื่อยืนยันว่ามีมุมแหว่งจริงหรือไม่",
                    "Periksa dinding luar, balkon, dan area tambahan untuk memastikan bentuk nyata."
                )
            )
        }
    }
    
    private func resolvePalace(geoAngle: Double) -> (dir: String, gua: String) {
        let lang = LocalizationManager.shared.effectiveLanguage
        let norm = geoAngle.truncatingRemainder(dividingBy: 360.0)
        let angle = norm < 0 ? norm + 360.0 : norm
        
        let index: Int
        if angle >= 337.5 || angle < 22.5 { index = 0 }       // North Kan
        else if angle >= 22.5 && angle < 67.5 { index = 1 }   // Northeast Gen
        else if angle >= 67.5 && angle < 112.5 { index = 2 }  // East Zhen
        else if angle >= 112.5 && angle < 157.5 { index = 3 } // Southeast Xun
        else if angle >= 157.5 && angle < 202.5 { index = 4 } // South Li
        else if angle >= 202.5 && angle < 247.5 { index = 5 } // Southwest Kun
        else if angle >= 247.5 && angle < 292.5 { index = 6 } // West Dui
        else { index = 7 }                                    // Northwest Qian
        
        switch lang {
        case .en:
            let dirs = ["North", "Northeast", "East", "Southeast", "South", "Southwest", "West", "Northwest"]
            let guas = ["Kan", "Gen", "Zhen", "Xun", "Li", "Kun", "Dui", "Qian"]
            return (dirs[index], guas[index])
        case .zhHant:
            let dirs = ["正北", "東北", "正東", "東南", "正南", "西南", "正西", "西北"]
            let guas = ["坎", "艮", "震", "巽", "離", "坤", "兌", "乾"]
            return (dirs[index], guas[index])
        case .ja:
            let dirs = ["北", "北東", "東", "南東", "南", "南西", "西", "北西"]
            let guas = ["坎", "艮", "震", "巽", "離", "坤", "兌", "乾"]
            return (dirs[index], guas[index])
        case .ko:
            let dirs = ["북", "북동", "동", "동남", "남", "남서", "서", "북서"]
            let guas = ["감", "간", "진", "손", "이", "곤", "태", "건"]
            return (dirs[index], guas[index])
        case .vi:
            let dirs = ["Bắc", "Đông Bắc", "Đông", "Đông Nam", "Nam", "Tây Nam", "Tây", "Tây Bắc"]
            let guas = ["Khảm", "Cấn", "Chấn", "Tốn", "Ly", "Khôn", "Đoài", "Càn"]
            return (dirs[index], guas[index])
        case .th:
            let dirs = ["ทิศเหนือ", "ตะวันออกเฉียงเหนือ", "ทิศตะวันออก", "ตะวันออกเฉียงใต้", "ทิศใต้", "ตะวันตกเฉียงใต้", "ทิศตะวันตก", "ตะวันตกเฉียงเหนือ"]
            let guas = ["ข่าน", "เกิ่น", "เจิ้น", "ซวิ่น", "หลี", "คุน", "ตุ้ย", "เฉียน"]
            return (dirs[index], guas[index])
        case .id:
            let dirs = ["Utara", "Timur Laut", "Timur", "Tenggara", "Selatan", "Barat Daya", "Barat", "Barat Laut"]
            let guas = ["Kan", "Gen", "Zhen", "Xun", "Li", "Kun", "Dui", "Qian"]
            return (dirs[index], guas[index])
        case .zhHans, .auto:
            let dirs = ["正北", "东北", "正东", "东南", "正南", "西南", "正西", "西北"]
            let guas = ["坎", "艮", "震", "巽", "离", "坤", "兑", "乾"]
            return (dirs[index], guas[index])
        }
    }
    
    private func evaluateRoom(type: FloorplanRoomType, palaceGua: String, palaceDir: String) -> (title: String, level: String, lore: String, advice: String) {
        switch (type, palaceGua) {
        case (.kitchen, "乾"), (.kitchen, "Qian"), (.kitchen, "건"), (.kitchen, "Càn"), (.kitchen, "เฉียน"):
            return (
                tr8("西北角厨房排烟与热源核验", "西北角廚房排煙與熱源核驗", "Northwest Kitchen Exhaust & Heat Check", "北西キッチン換気・熱源確認", "북서 주방 배기 및 열원 점검", "Kiểm tra hút mùi & nhiệt bếp Tây Bắc", "ตรวจการระบายอากาศและความร้อนครัวตะวันตกเฉียงเหนือ", "Cek Ventilasi & Panas Dapur Barat Laut"),
                "严重煞气",
                tr8(
                    "西北方位冬季常迎主导寒风，夏季下午易受西晒叠加热负荷，厨房设于此区需重点核验油烟倒灌、隔热距离与消防排风。",
                    "西北方位冬季常迎主導寒風，夏季下午易受西曬疊加熱負荷，廚房設於此區需重點核驗油煙倒灌、隔熱距離與消防排風。",
                    "Northwest kitchens often face prevailing winter crosswinds and afternoon western solar heat gain. Verify exhaust backdraft prevention, thermal clearance, and ventilation airflow on site.",
                    "北西側のキッチンは冬季の季節風や西日の熱負荷を受けやすいため、排気の逆流防止・断熱距離・換気経路を現地で確認してください。",
                    "북서쪽 주방은 겨울철 북서풍과 오후 서향 일사 열부하의 영향을 받기 쉬우므로 배기 역류 방지, 단열 거리, 환기 효율을 점검하세요.",
                    "Bếp hướng Tây Bắc thường chịu gió mùa và bức xạ nắng chiều; cần kiểm tra van chống gió ngược ống hút mùi, cách nhiệt và thông gió.",
                    "ครัวทิศตะวันตกเฉียงเหนือมักรับลมและแดดบ่าย ควรตรวจวาล์วกันลมย้อนของเครื่องดูดควัน ระยะกันความร้อน และการระบายอากาศ",
                    "Dapur barat laut sering terkena angin dan panas matahari sore; periksa katup anti-aliran balik exhaust, jarak panas, dan ventilasi."
                ),
                tr8(
                    "建议安装止逆阀与大风量侧吸油烟机，西向窗配置隔热遮阳帘并保持明火与可燃物安全间距。",
                    "建議安裝止逆閥與大風量側吸油煙機，西向窗配置隔熱遮陽簾並保持明火與可燃物安全間距。",
                    "Install a backdraft damper with a high-CFM range hood, add solar heat-blocking blinds on west-facing windows, and maintain safe fire clearance.",
                    "逆流防止ダンパー付き高排気レンジフードと遮熱ブラインドを採用し、火気周辺の安全な離隔距離を確保してください。",
                    "역류 방지 댐퍼와 고풍량 후드를 설치하고 서향 창에 차열 블라인드를 적용하며 화기 안전 거리를 확보하세요.",
                    "Lắp van một chiều cho ống hút mùi công suất cao, dùng rèm cách nhiệt cho cửa sổ hướng Tây và giữ khoảng cách an toàn cháy nổ.",
                    "ติดตั้งวาล์วกันลมย้อนพร้อมเครื่องดูดควันกำลังสูง ติดม่านกันความร้อนฝั่งตะวันตก และเว้นระยะปลอดภัยรอบเตา",
                    "Pasang katup anti-balik pada penghisap asap berkapasitas tinggi, tirai penahan panas di jendela barat, dan jaga jarak aman api."
                )
            )
        case (.bathroom, "乾"), (.bathroom, "Qian"), (.bathroom, "건"), (.bathroom, "Càn"), (.bathroom, "เฉียน"):
            return (
                tr8("西北角卫浴防潮与采暖核验", "西北角衛浴防潮與採暖核驗", "Northwest Bathroom Moisture & Warmth Check", "北西浴室の防湿・断熱確認", "북서 욕실 결로 및 단열 점검", "Kiểm tra chống ẩm & thông gió vệ sinh Tây Bắc", "ตรวจความชื้นและฉนวนห้องน้ำตะวันตกเฉียงเหนือ", "Cek Kelembapan & Isolasi Kamar Mandi Barat Laut"),
                "严重煞气",
                tr8(
                    "西北角冬季气温偏低、迎风面散热快，卫浴水汽易在冷墙面结露发霉，需重点核对墙地防水层、热风换气及干湿分区。",
                    "西北角冬季氣溫偏低、迎風面散熱快，衛浴水汽易在冷牆面結露發霉，需重點核對牆地防水層、熱風換氣及乾濕分區。",
                    "Northwest exterior corners experience faster winter heat loss, increasing condensation and mold risk in wet zones. Verify waterproofing, heated exhaust, and wet-dry separation.",
                    "北西の外壁コーナーは冬季に冷えやすく結露・カビのリスクが高いため、防水施工・換気乾燥機・乾湿分離を現地で確認してください。",
                    "북서 외벽 코너는 겨울철 결로와 곰팡이 위험이 높으므로 방수 시공, 온풍 환기, 건식·습식 분리를 현장에서 확인하세요.",
                    "Góc Tây Bắc dễ lạnh vào mùa đông gây đọng sương và nấm mốc trong khu ướt; cần kiểm tra chống thấm, quạt thông gió và phân khu khô–ướt.",
                    "มุมตะวันตกเฉียงเหนือมักเย็นและชื้นง่าย เกิดเชื้อราได้ง่าย ควรตรวจระบบกันซึม พัดลมดูดอากาศ และการแยกส่วนเปียก–แห้ง",
                    "Sudut barat laut lebih rentan kondensasi dan jamur di area basah; periksa lapisan kedap air, exhaust fan, dan pemisahan area basah-kering."
                ),
                tr8(
                    "建议做实体干湿分离与闭门器，配置延时排风浴霸及墙体保温防潮涂层，保持室内干燥。",
                    "建議做實體乾濕分離與閉門器，配置延時排風浴霸及牆體保溫防潮塗層，保持室內乾燥。",
                    "Add a physical wet-dry partition, timed humidity-sensing exhaust fan, and thermal moisture-barrier wall finish to keep the space dry.",
                    "乾湿分離パーティション、湿度センサー付き換気乾燥機、防カビ断熱仕上げを導入して乾燥状態を維持してください。",
                    "건습 분리 파티션, 습도 감지 지연 환기팬, 단열 방습 마감을 적용해 실내를 쾌적하게 유지하세요.",
                    "Tách khu khô–ướt rõ ràng, lắp quạt hút ẩm có hẹn giờ và sơn chống thấm chống mốc cho tường.",
                    "กั้นโซนเปียก–แห้ง ติดพัดลมดูดอากาศตั้งเวลา และทาสีกันชื้นป้องกันเชื้อรา",
                    "Buat pemisahan area basah-kering, pasang exhaust fan dengan pengatur waktu, dan gunakan pelapis dinding anti-lembap."
                )
            )
        case (.kitchen, "坎"), (.kitchen, "Kan"), (.kitchen, "감"), (.kitchen, "Khảm"), (.kitchen, "ข่าน"):
            return (
                tr8("北向厨房采光与冬季排风核验", "北向廚房採光與冬季排風核驗", "North Kitchen Daylight & Airflow Check", "北側キッチンの採光・換気確認", "북향 주방 채광 및 환기 점검", "Kiểm tra ánh sáng & thông gió bếp hướng Bắc", "ตรวจแสงธรรมชาติและระบายอากาศครัวทิศเหนือ", "Cek Pencahayaan & Ventilasi Dapur Utara"),
                "预警",
                tr8(
                    "正北方位直射日照较少、冬季湿度相对偏高，厨房高频用水与热源并存时需关注操作台补光、防滑排水及油烟排湿。",
                    "正北方位直射日照較少、冬季濕度相對偏高，廚房高頻用水與熱源並存時需關注操作台補光、防滑排水及油煙排濕。",
                    "North-facing kitchens receive minimal direct sunlight and retain higher winter humidity. Check task lighting, slip-resistant flooring, and moisture extraction.",
                    "北向きキッチンは直射日光が少なく湿気がこもりやすいため、手元照明・滑りにくい床材・排湿換気を重点的に確認してください。",
                    "정북향 주방은 직사광선이 적고 습도가 높아지기 쉬우므로 조리대 작업 조명, 미끄럼 방지 바닥, 제습 환기를 점검하세요.",
                    "Bếp hướng Bắc ít nắng trực tiếp và độ ẩm cao; cần bổ sung đèn chiếu sáng khu bếp, sàn chống trượt và hút ẩm hiệu quả.",
                    "ครัวทิศเหนือรับแสงแดดตรงน้อยและชื้นง่าย ควรเพิ่มไฟส่องเคาน์เตอร์ ปูพื้นกันลื่น และติดพัดลมระบายความชื้น",
                    "Dapur menghadap utara minim sinar matahari langsung dan lebih lembap; periksa lampu kerja, lantai anti-slip, dan ventilasi uap."
                ),
                tr8(
                    "建议在吊柜下方增设 4000K 中性任务照明，采用浅色易洁台面并保证水槽与灶具间隔 ≥ 60 cm。",
                    "建議在吊櫃下方增設 4000K 中性任務照明，採用淺色易潔台面並保證水槽與灶具間隔 ≥ 60 cm。",
                    "Add 4000K under-cabinet task lighting, use bright easy-clean surfaces, and keep at least 60 cm clearance between sink and cooktop.",
                    "吊戸棚下に4000Kの作業照明を設け、明るい仕上げ材とシンク・コンロ間60cm以上の離隔を確保してください。",
                    "상부장 하부에 4000K 작업 조명을 추가하고 밝은 마감재와 싱크대-쿡탑 간 60cm 이상 간격을 확보하세요.",
                    "Lắp đèn LED 4000K dưới tủ bếp, dùng bề mặt sáng dễ vệ sinh và giữ khoảng cách bồn rửa–bếp tối thiểu 60 cm.",
                    "ติดไฟ LED 4000K ใต้ตู้แขวน ใช้พื้นผิวสีสว่างทำความสะอาดง่าย และเว้นระยะอ่างล้างจานกับเตาอย่างน้อย 60 ซม.",
                    "Tambahkan lampu LED 4000K di bawah kabinet, gunakan permukaan terang mudah dibersihkan, dan jaga jarak wastafel-kompor ≥ 60 cm."
                )
            )
        case (.kitchen, "艮"), (.kitchen, "坤"), (.kitchen, "Gen"), (.kitchen, "Kun"),
             (.kitchen, "간"), (.kitchen, "곤"), (.kitchen, "Cấn"), (.kitchen, "Khôn"),
             (.kitchen, "เกิ่น"), (.kitchen, "คุน"):
            return (
                tr8("东北/西南角厨房温湿与通风核验", "東北/西南角廚房溫濕與通風核驗", "NE/SW Corner Kitchen Thermal & Ventilation Check", "北東・南西キッチン温湿・換気確認", "동북/서남 코너 주방 온습도·환기 점검", "Kiểm tra nhiệt ẩm & thông gió bếp góc ĐB/TN", "ตรวจอุณหภูมิและระบายอากาศครัวมุมตะวันออกเฉียงเหนือ/ตะวันตกเฉียงใต้", "Cek Termal & Ventilasi Dapur Sudut TL/BD"),
                "预警",
                tr8(
                    "东北角阴凉偏湿、西南角午后日照强烈（西晒显著），厨房设于斜角方位时温差与油烟滞留风险较高，需做好通风与隔热规划。",
                    "東北角陰涼偏濕、西南角午後日照強烈（西曬顯著），廚房設於斜角方位時溫差與油煙滯留風險較高，需做好通風與隔熱規劃。",
                    "Northeast corners stay cool and damp while southwest corners receive intense afternoon sun. Check thermal insulation, exhaust routing, and food storage temperature.",
                    "北東角は低温多湿、南西角は西日が強いため、断熱・換気経路および食品保管エリアの温度管理を確認してください。",
                    "동북 코너는 냉습하고 서남 코너는 오후 일사가 강해 온도 차와 환기 정체에 유의해야 합니다.",
                    "Góc Đông Bắc dễ ẩm lạnh còn góc Tây Nam chịu nắng chiều gắt; cần tối ưu cách nhiệt, hút mùi và khu bảo quản thực phẩm.",
                    "มุมตะวันออกเฉียงเหนือมักเย็นชื้น ส่วนมุมตะวันตกเฉียงใต้แดดบ่ายแรง ควรดูแลฉนวนกันความร้อนและการระบายอากาศ",
                    "Sudut timur laut cenderung lembap sementara barat daya terkena panas sore; optimalkan isolasi panas dan sirkulasi udara."
                ),
                tr8(
                    "建议采用双层 Low-E 隔热窗或遮阳百叶，优化排烟管道弯头数量（≤2 处），冰箱远离直射日照与灶具。",
                    "建議採用雙層 Low-E 隔熱窗或遮陽百葉，優化排煙管道彎頭數量（≤2 處），冰箱遠離直射日照與灶具。",
                    "Use Low-E insulated glazing or louvers, minimize exhaust duct bends (≤ 2), and position the refrigerator away from direct sun and heat.",
                    "Low-E断熱ガラスやブラインドを採用し、排気ダクトの屈曲を2箇所以下に抑え、冷蔵庫を直射日光と熱源から離してください。",
                    "Low-E 단열 유리나 블라인드를 사용하고 배기 덕트 굴곡을 2회 이하로 줄이며 냉장고를 직사광선과 열원에서 분리하세요.",
                    "Dùng kính cách nhiệt Low-E hoặc rèm sáo, hạn chế gấp khúc ống khói (≤ 2 đoạn) và đặt tủ lạnh xa nắng gắt, xa bếp.",
                    "ใช้กระจกกันความร้อน Low-E หรือมู่ลี่ ลดข้อต่อท่อดูดควัน (≤ 2 จุด) และวางตู้เย็นให้ห่างแดดและเตา",
                    "Gunakan kaca insulasi Low-E, minimalkan belokan pipa exhaust (≤ 2), dan jauhkan kulkas dari sinar matahari langsung serta kompor."
                )
            )
        case (.bathroom, "艮"), (.bathroom, "坤"), (.bathroom, "Gen"), (.bathroom, "Kun"),
             (.bathroom, "간"), (.bathroom, "곤"), (.bathroom, "Cấn"), (.bathroom, "Khôn"),
             (.bathroom, "เกิ่น"), (.bathroom, "คุน"):
            return (
                tr8("斜角卫浴排水坡度与防霉核验", "斜角衛浴排水坡度與防霉核驗", "Corner Bathroom Drainage & Humidity Check", "コーナー浴室の排水勾配・防カビ確認", "코너 욕실 배수 구배 및 방습 점검", "Kiểm tra thoát nước & chống ẩm vệ sinh góc", "ตรวจความลาดเอียงท่อน้ำทิ้งและกันชื้นห้องน้ำมุม", "Cek Drainase & Kelembapan Kamar Mandi Sudut"),
                "预警",
                tr8(
                    "东北/西南端头卫浴若无对流外窗，湿气易在墙角积聚并影响相邻房间墙面返潮，建议现场核验地漏坡度（≥1.5%）与排风效率。",
                    "東北/西南端頭衛浴若無對流外窗，濕氣易在牆角積聚並影響相鄰房間牆面返潮，建議現場核驗地漏坡度（≥1.5%）與排風效率。",
                    "Corner bathrooms without cross-ventilation can trap moisture and cause dampness on adjacent walls. Verify floor drainage slope (≥ 1.5%) and continuous exhaust capacity.",
                    "通風窓のないコーナー浴室は湿気が滞留し隣接壁の結露原因になります。床の排水勾配（1.5%以上）と換気風量を確認してください。",
                    "맞통풍 창이 없는 코너 욕실은 습기가 정체되어 인접 벽면 곰팡이를 유발할 수 있습니다. 바닥 배수 구배(1.5% 이상)와 환기량을 점검하세요.",
                    "Phòng vệ sinh góc thiếu thông gió chéo dễ đọng ẩm sang tường phòng kề; hãy kiểm tra độ dốc thoát sàn (≥ 1,5%) và quạt hút.",
                    "ห้องน้ำมุมที่ไม่มีหน้าต่างระบายอากาศข้ามฝั่งมักอับชื้น ควรตรวจความลาดเอียงพื้น (≥ 1.5%) และประสิทธิภาพพัดลมดูดอากาศ",
                    "Kamar mandi sudut tanpa ventilasi silang rentan lembap ke dinding sebelah; periksa kemiringan drainase (≥ 1,5%) dan kapasitas exhaust."
                ),
                tr8(
                    "建议选用防臭深水封地漏与大风量静音换气扇，邻近卧室墙体背面刷涂防水防潮底漆。",
                    "建議選用防臭深水封地漏與大風量靜音換氣扇，鄰近臥室牆體背面刷塗防水防潮底漆。",
                    "Use deep-seal floor drains, a quiet high-volume exhaust fan, and apply a waterproof vapor-barrier primer on shared bedroom walls.",
                    "防臭トラップ排水口と静音高風量換気扇を採用し、隣接寝室側の壁面に防湿プライマーを施工してください。",
                    "방취 트랩 배수구와 저소음 대풍량 환기팬을 설치하고 인접 침실 벽면에 방습 프라이머를 시공하세요.",
                    "Dùng phễu thu sàn ngăn mùi, quạt hút êm công suất cao và quét lớp lót chống thấm cho vách giáp phòng ngủ.",
                    "ใช้ตะแกรงกันกลิ่นแบบกักน้ำลึก พัดลมดูดอากาศเสียงเงียบกำลังสูง และทารองพื้นกันชื้นผนังด้านติดห้องนอน",
                    "Gunakan floor drain anti-bau, exhaust fan senyap berkapasitas besar, dan primer anti-lembap pada dinding yang berbatasan dengan kamar tidur."
                )
            )
        case (.bathroom, "中"), (.bathroom, "Center"), (.bathroom, "중"), (.bathroom, "Trung"), (.bathroom, "กลาง"), (.bathroom, "Tengah"):
            return (
                tr8("核心区无窗暗卫通风与隔音核验", "核心區無窗暗衛通風與隔音核驗", "Central Windowless Bathroom Ventilation Check", "中央コア暗浴室の換気・防音確認", "중앙 무창 욕실 환기 및 방음 점검", "Kiểm tra thông gió & cách âm vệ sinh trung tâm", "ตรวจระบายอากาศและกันเสียงห้องน้ำใจกลางบ้าน", "Cek Ventilasi & Akustik Kamar Mandi Tengah"),
                "严重煞气",
                tr8(
                    "卫浴位于户型几何中心通常属于无外窗暗卫，自然采光与自然通风受限，异味与水汽易向四周起居空间扩散，同时排水立管易产生噪音传导。",
                    "衛浴位於戶型幾何中心通常屬於無外窗暗衛，自然採光與自然通風受限，異味與水汽易向四周起居空間擴散，同時排水立管易產生噪音傳導。",
                    "A centrally located bathroom typically lacks exterior windows, limiting natural daylight and ventilation while allowing humidity and pipe noise to spread into surrounding rooms.",
                    "住戸中央の浴室は無窓になりやすく、自然採光・換気が不足して湿気や排水音が周囲の居室へ伝わりやすくなります。",
                    "평면 중앙 욕실은 창문이 없는 암실 구조가 많아 자연 채광과 환기가 불리하고 습기·배관 소음이 주변 방으로 퍼지기 쉽습니다.",
                    "Nhà vệ sinh ở tâm mặt bằng thường thiếu cửa sổ tự nhiên, dễ bí ẩm và truyền tiếng ồn ống xả sang các phòng xung quanh.",
                    "ห้องน้ำกลางบ้านมักไม่มีหน้าต่าง ทำให้ขาดแสงธรรมชาติและการระบายอากาศ รวมถึงมีเสียงท่อน้ำรบกวนห้องรอบข้าง",
                    "Kamar mandi di tengah denah umumnya tanpa jendela sehingga minim cahaya alami, rawan lembap, dan suara pipa mudah menyebar."
                ),
                tr8(
                    "建议配置带新风联动或 24 小时低噪微排风系统、排水管包覆隔音棉，并采用高显色防雾照明与密闭门条。",
                    "建議配置帶新風聯動或 24 小時低噪微排風系統、排水管包覆隔音棉，並採用高顯色防霧照明與密閉門條。",
                    "Install continuous low-noise mechanical exhaust, wrap drain stacks with acoustic insulation, and add high-CRI anti-fog lighting plus door perimeter seals.",
                    "24時間静音換気システムと排水管の防音被覆を導入し、高演色防曇照明と気密ドアパッキンを設置してください。",
                    "24시간 저소음 상시 환기 시스템과 배수관 흡음재를 적용하고 고연색 방습 조명 및 기밀 도어 씰을 설치하세요.",
                    "Lắp quạt thông gió liên tục độ ồn thấp, bọc cách âm ống thoát nước, dùng đèn chống mờ CRI cao và gioăng kín cửa.",
                    "ติดตั้งพัดลมระบายอากาศต่อเนื่องเสียงเบา หุ้มฉนวนกันเสียงท่อน้ำ ใช้ไฟกันฝ้าค่า CRI สูง และซีลขอบประตู",
                    "Pasang exhaust fan kontinu rendah bising, balut pipa drainase dengan peredam suara, serta gunakan lampu anti-embun CRI tinggi dan seal pintu."
                )
            )
        case (.study, "巽"), (.study, "坎"), (.study, "Xun"), (.study, "Kan"),
             (.study, "손"), (.study, "감"), (.study, "Tốn"), (.study, "Khảm"),
             (.study, "ซวิ่น"), (.study, "ข่าน"):
            return (
                tr8("书房采光柔和 · 静谧读写分区", "書房採光柔和 · 靜謐讀寫分區", "Soft-Daylight Quiet Study Zone", "穏やかな採光の書斎ゾーン", "부드러운 채광의 정숙 서재 구역", "Khu phòng làm việc ánh sáng dịu & yên tĩnh", "โซนห้องทำงานแสงนุ่มนวลและเงียบสงบ", "Zona Ruang Kerja Cahaya Lembut & Tenang"),
                "吉",
                tr8(
                    "东南/正北方位眩光较少、自然光均匀柔和，适合长时间阅读、屏幕办公与专注工作，减少午后屏幕反光疲劳。",
                    "東南/正北方位眩光較少、自然光均勻柔和，適合長時間閱讀、螢幕辦公與專注工作，減少午後螢幕反光疲勞。",
                    "Southeast and north sectors offer even, low-glare natural light ideal for reading, screen work, and sustained focus with minimal afternoon glare.",
                    "南東・北側はまぶしさが少なく均一な自然光が得られ、読書やモニター作業に適した落ち着いたワークスペースになります。",
                    "동남 및 북향 구역은 눈부심이 적고 균일한 자연광이 들어와 독서와 모니터 작업에 쾌적한 집중 환경을 제공합니다.",
                    "Hướng Đông Nam và Bắc có ánh sáng tự nhiên dịu đều, ít chói màn hình, rất phù hợp làm việc và đọc sách lâu dài.",
                    "ทิศตะวันออกเฉียงใต้และทิศเหนือมีแสงธรรมชาติสม่ำเสมอ ไม่แยงตา เหมาะสำหรับการอ่านหนังสือและทำงานหน้าจอ",
                    "Sektor tenggara dan utara memberikan cahaya alami merata minim silau, ideal untuk membaca dan bekerja di depan layar."
                ),
                tr8(
                    "建议书桌与窗户呈 90° 侧向采光，配置无频闪护眼台灯与人体工学椅，提升专注舒适度。",
                    "建議書桌與窗戶呈 90° 側向採光，配置無頻閃護眼台燈與人體工學椅，提升專注舒適度。",
                    "Position the desk at 90° to the window for glare-free side daylight, paired with flicker-free task lighting and ergonomic seating.",
                    "窓に対して90°の横向き採光となるようにデスクを配置し、フリッカーフリーの照明とエルゴノミクスチェアを組み合わせてください。",
                    "창문과 90° 측면 채광이 되도록 책상을 배치하고 플리커 프리 조명과 인체공학 의자를 함께 구성하세요.",
                    "Đặt bàn vuông góc 90° với cửa sổ để nhận ánh sáng ngang chống chói, kết hợp đèn bàn không nhấp nháy và ghế công thái học.",
                    "จัดโต๊ะทำมุม 90° กับหน้าต่างเพื่อรับแสงด้านข้างไม่สะท้อนจอ พร้อมโคมไฟถนอมสายตาและเก้าอี้เพื่อสุขภาพ",
                    "Posisikan meja 90° terhadap jendela untuk cahaya samping bebas silau, lengkapi lampu kerja bebas kedip dan kursi ergonomis."
                )
            )
        case (.masterBedroom, "坤"), (.masterBedroom, "延年"), (.masterBedroom, "Kun"), (.masterBedroom, "Yan Nian"),
             (.masterBedroom, "곤"), (.masterBedroom, "Khôn"), (.masterBedroom, "คุน"):
            return (
                tr8("主卧静区布局 · 休憩采光均衡", "主臥靜區佈局 · 休憩採光均衡", "Well-Positioned Quiet Master Bedroom", "静寂で均衡の取れた主寝室配置", "안정적인 정숙 구역 주침실 배치", "Phòng ngủ chính khu tĩnh & cân bằng sáng", "ห้องนอนใหญ่โซนเงียบสงบและแสงสมดุล", "Kamar Tidur Utama Zona Tenang & Seimbang"),
                "吉",
                tr8(
                    "该方位远离高频公共噪音动线且日照时长充足，有利于形成稳定的睡眠微气候与私密休憩体验。",
                    "該方位遠離高頻公共噪音動線且日照時長充足，有利於形成穩定的睡眠微氣候與私密休憩體驗。",
                    "Well separated from high-traffic public circulation with balanced daylight duration, supporting acoustic privacy and comfortable sleep.",
                    "共用動線の騒音から離れ日照バランスも良好で、プライバシーと快適な睡眠環境を確保しやすい配置です。",
                    "공용 동선 소음에서 분리되고 채광 균형이 좋아 프라이버시와 쾌적한 수면 환경을 유지하기 유리합니다.",
                    "Tách biệt luồng giao thông ồn ào và có thời lượng chiếu sáng hợp lý, tạo không gian nghỉ ngơi riêng tư yên tĩnh.",
                    "แยกจากเส้นทางสัญจรที่มีเสียงรบกวนและได้รับแสงพอเหมาะ ช่วยให้พักผ่อนได้อย่างเป็นส่วนตัวและสบาย",
                    "Terpisah dari jalur lalu lintas bising dengan durasi cahaya seimbang, mendukung privasi akustik dan tidur nyenyak."
                ),
                tr8(
                    "建议床头紧靠实墙避开卫生间排水管，配置双层遮光窗帘与柔和 2700K 睡前照明。",
                    "建議床頭緊靠實牆避開衛生間排水管，配置雙層遮光窗簾與柔和 2700K 睡前照明。",
                    "Place the headboard against a solid wall away from plumbing stacks, and use blackout curtains with warm 2700K bedside lighting.",
                    "ベッドヘッドは排水管を避けた堅固な壁面に配置し、遮光カーテンと2700Kの暖色系間接照明を採用してください。",
                    "침대 헤드는 배수관을 피한 단단한 벽에 배치하고 암막 커튼과 2700K 따뜻한 취침 조명을 사용하세요.",
                    "Đặt đầu giường tựa tường đặc tránh hộp kỹ thuật ống nước, kết hợp rèm cản sáng hai lớp và đèn ngủ 2700K dịu mắt.",
                    "วางหัวเตียงชิดผนังทึบห่างท่อน้ำ ใช้ม่านทึบแสงสองชั้นและไฟหัวเตียงโทนอุ่น 2700K",
                    "Sandarkan kepala ranjang ke dinding solid jauh dari pipa air, gunakan tirai blackout dan lampu tidur hangat 2700K."
                )
            )
        case (.door, "离"), (.door, "Li"), (.door, "이"), (.door, "Ly"), (.door, "หลี"):
            return (
                tr8("南向入户 · 采光与通风优良", "南向入戶 · 採光與通風優良", "South-Facing Entry · High Daylight & Airflow", "南向き玄関・優れた採光と通風", "남향 현관 · 우수한 채광 및 통풍", "Lối vào hướng Nam · Sáng & thông thoáng", "ทางเข้าทิศใต้ · แสงธรรมชาติและลมถ่ายเทดี", "Pintu Masuk Selatan · Cahaya & Sirkulasi Optimal"),
                "吉",
                tr8(
                    "正南朝向拥有全年最佳的冬季日照获取与夏季主导风通风条件，玄关明亮干燥、入户视觉体验通透。",
                    "正南朝向擁有全年最佳的冬季日照獲取與夏季主導風通風條件，玄關明亮乾燥、入戶視覺體驗通透。",
                    "South-facing orientation maximizes winter passive solar gain and prevailing summer breeze ventilation, keeping the entryway bright and dry.",
                    "南向きは冬季の自然採光と夏季の通風に最も有利で、明るく乾燥した快適なエントランスを形成できます。",
                    "정남향은 겨울철 일조 확보와 여름철 통풍에 유리해 밝고 쾌적한 현관 동선을 구성하기 좋습니다.",
                    "Hướng Nam đón nắng ấm mùa đông và gió mát mùa hè tối ưu, giúp sảnh vào luôn sáng sủa, khô ráo.",
                    "ทิศใต้รับแสงธรรมชาติและลมถ่ายเทได้ดีตลอดปี ทำให้โถงทางเข้าสว่าง แห้ง และโปร่งสบาย",
                    "Orientasi selatan memaksimalkan cahaya alami dan sirkulasi udara, menjaga area masuk tetap terang dan kering."
                ),
                tr8(
                    "建议保持玄关通道净宽 ≥ 1.1 m，配合感应暖光照明与换鞋收纳柜提升归家动线效率。",
                    "建議保持玄關通道淨寬 ≥ 1.1 m，配合感應暖光照明與換鞋收納櫃提升歸家動線效率。",
                    "Keep entry clearance ≥ 1.1 m wide with motion-activated warm lighting and organized shoe storage for smooth circulation.",
                    "玄関通路の有効幅を1.1m以上に保ち、人感センサー照明と収納で快適な動線を整えてください。",
                    "현관 통로 유효 폭을 1.1m 이상 유지하고 센서 조명과 수납장을 배치해 출입 동선을 최적화하세요.",
                    "Giữ lối đi sảnh rộng tối thiểu 1,1 m, kết hợp đèn cảm biến ánh sáng ấm và tủ giày gọn gàng.",
                    "รักษาความกว้างทางเดินโถงอย่างน้อย 1.1 เมตร พร้อมไฟเซ็นเซอร์แสงอุ่นและตู้เก็บรองเท้าที่เป็นระเบียบ",
                    "Jaga lebar bersih jalur masuk ≥ 1,1 m dengan lampu sensor hangat dan rak sepatu rapi untuk kelancaran sirkulasi."
                )
            )
        default:
            return (
                tr8("空间分区均衡 · 指标正常", "空間分區均衡 · 指標正常", "Balanced Spatial Layout", "バランスの取れた空間配置", "균형 잡힌 공간 구획", "Phân khu không gian cân bằng", "การจัดแบ่งพื้นที่สมดุล", "Tata Ruang Seimbang"),
                "平",
                tr8(
                    "该房间功能定位与方位采光、通风动线无明显冲突，整体空间利用率与舒适度均衡。",
                    "該房間功能定位與方位採光、通風動線無明顯衝突，整體空間利用率與舒適度均衡。",
                    "Room function aligns well with orientation daylight and ventilation paths with no major layout conflicts.",
                    "部屋の用途と方位の採光・通風動線に大きな矛盾はなく、快適性と空間効率のバランスが良好です。",
                    "실 용도와 방위 채광·환기 동선 간 뚜렷한 충돌이 없으며 공간 활용도가 균형적입니다.",
                    "Công năng phòng phù hợp với hướng chiếu sáng và thông gió, không có xung đột bố cục đáng kể.",
                    "การใช้งานห้องสอดคล้องกับทิศแสงและทางลม ไม่พบข้อขัดแย้งด้านผังพื้นที่ที่สำคัญ",
                    "Fungsi ruangan selaras dengan pencahayaan orientasi dan jalur ventilasi tanpa konflik tata letak utama."
                ),
                tr8(
                    "按常规家具尺度留足 75–90 cm 通行净距，并保持日常开窗换气与清洁维护即可。",
                    "按常規家具尺度留足 75–90 cm 通行淨距，並保持日常開窗換氣與清潔維護即可。",
                    "Maintain 75–90 cm furniture circulation clearance along with routine ventilation and upkeep.",
                    "家具周囲に75〜90cmの通行幅を確保し、日常的な換気と清掃を維持してください。",
                    "가구 주변에 75~90cm 통행 폭을 확보하고 일상적인 환기와 청결을 유지하세요.",
                    "Duy trì lối đi quanh nội thất 75–90 cm và thông gió, vệ sinh định kỳ.",
                    "เว้นระยะทางเดินรอบเฟอร์นิเจอร์ 75–90 ซม. และเปิดระบายอากาศทำความสะอาดตามปกติ",
                    "Pertahankan jarak sirkulasi furnitur 75–90 cm beserta ventilasi dan perawatan rutin."
                )
            )
        }
    }
}
