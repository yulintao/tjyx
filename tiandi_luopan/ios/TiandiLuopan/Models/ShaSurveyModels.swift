import Foundation
import CoreGraphics
import Combine

// MARK: - 全景形煞数据模型 (外部标注 / 距离判级 / 八宫聚合 / 室内外统一档案)
// 补齐 AR 实景测绘的三大缺口：距离参与严重度分级、结构化标记持久化、
// 360° 全景聚合报告；并将室内体检（HouseSpatialSurvey）与外部标注
// 合并为一份"全景形煞档案"。

/// 外部形煞标注来源
public enum ShaRecordSource: String, Codable {
    case ai        // OnDeviceShaAnalyzer 自动识别
    case manual    // 用户手动拖框锁定
}

public enum InteriorSurveySource: String, Codable {
    case measured, virtual, projection
}

/// 单条外部形煞现场标注（结构化记录，Codable 可持久化/导出）
public struct ExteriorShaRecord: Identifiable, Codable, Equatable {
    public let id: UUID
    public let shaID: String          // ExteriorShaEngine database key（tianzhan/luchong/...）
    public let bearingDegrees: Double // 绝对方位角 0..360
    /// Heading at capture time. Optional for backward-compatible decoding of
    /// records created before capture headings were persisted.
    public let capturedHeadingDegrees: Double?
    public let elevationDegrees: Double // 目标仰角（俯为负，仰为正）
    public let distanceMeters: Float?   // LiDAR/AR 深度；nil = 无深度数据
    public let confidence: Double?      // AI 置信度；手动标注为 nil
    public let capturedAt: Date
    public let source: ShaRecordSource
    public let note: String?

    public init(
        id: UUID = UUID(),
        shaID: String,
        bearingDegrees: Double,
        capturedHeadingDegrees: Double? = nil,
        elevationDegrees: Double = 0,
        distanceMeters: Float? = nil,
        confidence: Double? = nil,
        capturedAt: Date = Date(),
        source: ShaRecordSource = .manual,
        note: String? = nil
    ) {
        self.id = id
        self.shaID = shaID
        self.bearingDegrees = bearingDegrees
        self.capturedHeadingDegrees = capturedHeadingDegrees
        self.elevationDegrees = elevationDegrees
        self.distanceMeters = distanceMeters
        self.confidence = confidence
        self.capturedAt = capturedAt
        self.source = source
        self.note = note
    }

    /// 八宫（八方）索引：绝对方位模式下 0=正北，每 45° 一格。
    /// 全景报告会通过 `palaceIndex(relativeTo:)` 以采集基准朝向分组。
    public var palaceIndex: Int {
        absolutePalaceIndex(for: bearingDegrees)
    }

    /// Eight-palace index relative to a survey baseline heading. This keeps
    /// the report stable when a user turns the phone after taking records.
    public func palaceIndex(relativeTo headingDegrees: Double) -> Int {
        let relative = bearingDegrees - headingDegrees
        return absolutePalaceIndex(for: relative)
    }

    private func absolutePalaceIndex(for bearing: Double) -> Int {
        guard bearing.isFinite else { return 0 }
        let norm = (bearing.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        return Int(norm / 45.0) % 8
    }
}

/// 距离分级：形煞严重度随距离加权（近者愈凶、远者渐轻）
public enum ShaDistanceGrade: String, Codable {
    case criticalNear  // < 30m：加重一级
    case staticLevel   // 30~100m：保持静态等级
    case mitigatedFar  // > 100m：减轻一级
}

public enum ExteriorShaSeverityResolver {

    public static func grade(for distanceMeters: Float?) -> ShaDistanceGrade {
        guard let d = distanceMeters, d > 0, d.isFinite else { return .staticLevel }
        if d < 30.0 { return .criticalNear }
        if d > 100.0 { return .mitigatedFar }
        return .staticLevel
    }

    /// 静态严重度（ExteriorShaEngine 类型固有）+ 实测距离 → 最终判级
    public static func effectiveSeverity(
        staticSeverity: ShaSeverity,
        distanceMeters: Float?
    ) -> ShaSeverity {
        switch grade(for: distanceMeters) {
        case .criticalNear:
            switch staticSeverity {
            case .notice: return .minor
            case .minor: return .warning
            case .warning: return .critical
            case .critical: return .critical
            }
        case .mitigatedFar:
            switch staticSeverity {
            case .critical: return .warning
            case .warning: return .minor
            case .minor: return .minor
            case .notice: return .notice
            }
        case .staticLevel:
            return staticSeverity
        }
    }
}

/// 全景（八宫）外部形煞分布报告：环绕一周采集的多条标注按方位归宫
public struct ShaPanoramaReport: Identifiable, Codable {
    public let id: UUID
    public let capturedAt: Date
    public let headingDegrees: Double     // 采集时的罗盘基准朝向
    public let records: [ExteriorShaRecord]

    public init(
        id: UUID = UUID(),
        capturedAt: Date = Date(),
        headingDegrees: Double,
        records: [ExteriorShaRecord]
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.headingDegrees = headingDegrees
        self.records = records
    }

    /// 按采集基准朝向的八宫分组（0=基准朝向…7=其余方位），未扫描宫位为空数组。
    public var palacesByIndex: [[ExteriorShaRecord]] {
        var result = Array(repeating: [ExteriorShaRecord](), count: 8)
        for record in records {
            result[record.palaceIndex(relativeTo: headingDegrees)].append(record)
        }
        return result
    }

    /// 已覆盖的宫位数
    public var scannedPalaceCount: Int {
        palacesByIndex.filter { !$0.isEmpty }.count
    }

    /// 按最终判级统计（结合距离加权）
    public func severityCounts(staticSeverityLookup: (String) -> ShaSeverity) -> [ShaSeverity: Int] {
        var counts: [ShaSeverity: Int] = [:]
        for record in records {
            let base = staticSeverityLookup(record.shaID)
            let effective = ExteriorShaSeverityResolver.effectiveSeverity(
                staticSeverity: base,
                distanceMeters: record.distanceMeters
            )
            counts[effective, default: 0] += 1
        }
        return counts
    }
}

/// 全景形煞统一档案：罗盘朝向 + 室内体检 + 外部标注聚合
/// —— 打通"室内外两张皮"，一次输出全景形煞分析结论
public struct PanoramaFengShuiArchive: Identifiable, Codable {
    public let id: UUID
    public let createdAt: Date
    public let compassHeading: Double
    public let interior: HouseSpatialSurvey?    // 室内体检（RoomPlan/LiDAR/户型图）
    public let exterior: [ExteriorShaRecord]    // 外部形煞标注

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        compassHeading: Double,
        interior: HouseSpatialSurvey?,
        exterior: [ExteriorShaRecord]
    ) {
        self.id = id
        self.createdAt = createdAt
        self.compassHeading = compassHeading
        self.interior = interior
        self.exterior = exterior
    }

    /// 室内检出条目数
    public var interiorShaCount: Int { interior?.shaItems.count ?? 0 }

    /// 外部标注数
    public var exteriorShaCount: Int { exterior.count }

    /// 形煞总条数（室内条目 + 外部标注）
    public var totalShaCount: Int { interiorShaCount + exteriorShaCount }
}

// MARK: - 全景形煞档案共享存储 (室内体检与外部标注的单一消费入口)
// ARVisionView（外部标注）与 ARSpatialSurveyView / ARRoomPlanCaptureView
// （室内体检）分别写入，报告页统一读取，打通"室内外两张皮"。

public final class ShaSurveyStore: ObservableObject {
    public static let shared = ShaSurveyStore()

    /// Changes only when the active property changes, not on ordinary edits.
    /// Every open capture/editor holds its original ID until it is dismissed.
    @Published public private(set) var propertyID = UUID()
    /// Durable identity for reminders/archives; propertyID remains the stale-writer generation.
    @Published public private(set) var propertyKey = UUID().uuidString

    /// 外部形煞标注（按采集顺序）
    @Published public private(set) var records: [ExteriorShaRecord] = []
    /// 最近一次室内体检（RoomPlan/LiDAR/户型图路径）
    @Published public private(set) var latestInterior: HouseSpatialSurvey?
    @Published public private(set) var interiorSource: InteriorSurveySource?
    @Published public private(set) var siteFacts: [XuanKongSiteFact] = []

    private let storageKey = "tianji.sha_survey_store.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { persist(); return }
        records = snapshot.records
        latestInterior = snapshot.latestInterior
        siteFacts = snapshot.siteFacts ?? []
        propertyKey = snapshot.propertyKey ?? propertyKey
        interiorSource = snapshot.interiorSource ?? latestInterior.map { survey in
            if survey.scanMethod.localizedCaseInsensitiveContains("VR") || survey.scanMethod.contains("仿真") { return .virtual }
            if survey.scanMethod.contains("RoomPlan") || survey.scanMethod.contains("AR") || survey.scanMethod.contains("LiDAR") { return .measured }
            return .projection
        }
        persist()
    }

    private struct Snapshot: Codable {
        let records: [ExteriorShaRecord]
        let latestInterior: HouseSpatialSurvey?
        var siteFacts: [XuanKongSiteFact]? = nil
        var propertyKey: String? = nil
        var interiorSource: InteriorSurveySource? = nil
    }

    private func persist() {
        let snapshot = Snapshot(records: records, latestInterior: latestInterior, siteFacts: siteFacts,
                                propertyKey: propertyKey, interiorSource: interiorSource)
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: storageKey)
    }

    /// A property switch replaces the entire archive, including empty slots.
    /// Updating one slot in isolation would retain another property's model.
    @discardableResult
    public func replaceProperty(measured: HouseSpatialSurvey?, virtual: HouseSpatialSurvey?, exterior: [ExteriorShaRecord],
                                siteFacts: [XuanKongSiteFact] = [],
                                propertyKey: String? = nil,
                                expectedPropertyID: UUID? = nil) -> Bool {
        if let expectedPropertyID, !isCurrentProperty(expectedPropertyID) { return false }
        if expectedPropertyID == nil {
            propertyID = UUID()
            self.propertyKey = propertyKey ?? UUID().uuidString
        }
        defaults.set(measured.flatMap { try? JSONEncoder().encode($0) }, forKey: SpatialSurveyArchiveKeys.measured)
        defaults.set(virtual.flatMap { try? JSONEncoder().encode($0) }, forKey: SpatialSurveyArchiveKeys.virtual)
        records = exterior
        latestInterior = measured ?? virtual
        interiorSource = measured != nil ? .measured : (virtual != nil ? .virtual : nil)
        self.siteFacts = siteFacts.filter { (0...8).contains($0.palaceID) }
        persist()
        return true
    }

    public func setSiteFact(_ kind: XuanKongSiteFactKind, palaceID: Int, present: Bool, propertyID: UUID) {
        guard isCurrentProperty(propertyID), (0...8).contains(palaceID) else { return }
        let fact = XuanKongSiteFact(palaceID: palaceID, kind: kind)
        siteFacts.removeAll { $0.id == fact.id }
        if present { siteFacts.append(fact) }
        persist()
    }

    /// Refresh geometry for the current house without turning it into a property switch.
    @discardableResult
    public func refreshMeasuredSurvey(_ survey: HouseSpatialSurvey?, propertyID: UUID) -> Bool {
        replaceProperty(measured: survey, virtual: nil, exterior: records, siteFacts: siteFacts,
                        expectedPropertyID: propertyID)
    }

    public func isCurrentProperty(_ id: UUID) -> Bool { propertyID == id }

    /// UI and capture completions call this on the main thread. Validate before
    /// touching either archive slot or the combined panorama snapshot.
    @discardableResult
    public func saveSurvey(_ survey: HouseSpatialSurvey, key: String, propertyID: UUID) -> Bool {
        guard isCurrentProperty(propertyID),
              key == SpatialSurveyArchiveKeys.measured || key == SpatialSurveyArchiveKeys.virtual,
              let data = try? JSONEncoder().encode(survey) else { return false }
        defaults.set(data, forKey: key)
        let hasMeasuredArchive = defaults.data(forKey: SpatialSurveyArchiveKeys.measured) != nil
        if key == SpatialSurveyArchiveKeys.measured || !hasMeasuredArchive {
            latestInterior = survey
            interiorSource = key == SpatialSurveyArchiveKeys.measured ? .measured : .virtual
            persist()
        }
        NotificationCenter.default.post(name: key == SpatialSurveyArchiveKeys.measured
                                       ? .didUpdateMeasuredSpatialSurvey : .didUpdateHouseSpatialSurvey, object: nil)
        return true
    }

    @discardableResult
    public func addRecord(_ record: ExteriorShaRecord, propertyID: UUID) -> Bool {
        guard isCurrentProperty(propertyID) else { return false }
        records.append(record)
        persist()
        return true
    }

    @discardableResult
    public func updateInterior(_ survey: HouseSpatialSurvey?, propertyID: UUID) -> Bool {
        guard isCurrentProperty(propertyID) else { return false }
        latestInterior = survey
        interiorSource = survey == nil ? nil : .projection
        persist()
        return true
    }

    public func clearRecords() {
        records.removeAll()
        persist()
    }

    public func removeRecord(id: UUID) {
        records.removeAll(where: { $0.id == id })
        persist()
    }

    public func removeLastRecord() {
        guard !records.isEmpty else { return }
        records.removeLast()
        persist()
    }

    /// 室内外统一档案（任一侧有数据即非空）
    public var archive: PanoramaFengShuiArchive? {
        guard !records.isEmpty || latestInterior != nil else { return nil }
        let capturedHeading = records.lazy
            .compactMap { $0.capturedHeadingDegrees }
            .first(where: { $0.isFinite })
        let interiorHeading = latestInterior?.resolvedHouseFacing
        let fallbackHeading = CompassMotionManager.shared.headingState.facingAngle
        let heading = [capturedHeading, interiorHeading, fallbackHeading]
            .compactMap { $0 }
            .first(where: { $0.isFinite }) ?? 0.0
        return PanoramaFengShuiArchive(
            compassHeading: heading,
            interior: latestInterior,
            exterior: records
        )
    }
}

// MARK: - 空间测绘 → 方位测量 → 专业计算 → 综合报告 全流程状态中心 (SpatialWorkflowStore)

/// 圆周均值与角离散度计算器：正确处理 359° / 1° 跨正北零点，给出标准差 σ 与稳定度等级。
public struct BearingSampleSummary: Codable, Equatable {
    public let meanDegrees: Double
    public let sigmaDegrees: Double
    public let sampleCount: Int
    public let minMagneticUT: Double
    public let maxMagneticUT: Double
    public let isStable: Bool

    public static func compute(anglesDegrees: [Double], magneticSamplesUT: [Double] = []) -> BearingSampleSummary? {
        let valid = anglesDegrees.filter { $0.isFinite }
        guard !valid.isEmpty else { return nil }
        var sumSin = 0.0
        var sumCos = 0.0
        for deg in valid {
            let rad = deg * .pi / 180.0
            sumSin += sin(rad)
            sumCos += cos(rad)
        }
        let n = Double(valid.count)
        let meanRad = atan2(sumSin / n, sumCos / n)
        var meanDeg = meanRad * 180.0 / .pi
        if meanDeg < 0 { meanDeg += 360.0 }
        let r = min(1.0, max(1e-9, hypot(sumSin / n, sumCos / n)))
        let sigmaRad = sqrt(max(0.0, -2.0 * log(r)))
        let sigmaDeg = sigmaRad * 180.0 / .pi
        let validMag = magneticSamplesUT.filter { $0.isFinite }
        let minMag = validMag.min() ?? 48.0
        let maxMag = validMag.max() ?? 48.0
        return BearingSampleSummary(
            meanDegrees: meanDeg,
            sigmaDegrees: sigmaDeg,
            sampleCount: valid.count,
            minMagneticUT: minMag,
            maxMagneticUT: maxMag,
            isStable: sigmaDeg <= 2.0 && (maxMag - minMag) <= 12.0
        )
    }
}

/// 水平多边形几何计算工具（Shoelace 面积与周长，供 AR 打点与单元测试共用）。
public enum SpatialPolygonMath {
    public static func areaSqMeters(xzPoints: [(x: Double, z: Double)]) -> Double {
        guard xzPoints.count >= 3 else { return 0 }
        var acc = 0.0
        for i in 0..<xzPoints.count {
            let a = xzPoints[i]
            let b = xzPoints[(i + 1) % xzPoints.count]
            acc += a.x * b.z - b.x * a.z
        }
        return abs(acc) * 0.5
    }

    public static func perimeterMeters(xzPoints: [(x: Double, z: Double)]) -> Double {
        guard xzPoints.count >= 2 else { return 0 }
        var total = 0.0
        for i in 0..<(xzPoints.count - 1) {
            total += hypot(xzPoints[i + 1].x - xzPoints[i].x, xzPoints[i + 1].z - xzPoints[i].z)
        }
        if xzPoints.count >= 3 {
            let last = xzPoints[xzPoints.count - 1]
            let first = xzPoints[0]
            total += hypot(first.x - last.x, first.z - last.z)
        }
        return total
    }
}

public struct WorkflowSurveyTelemetry: Codable, Equatable {
    public var source: String
    public var widthMeters: Double?
    public var depthMeters: Double?
    public var areaSqMeters: Double?
    public var ceilingHeightMeters: Double?
    public var roomCount: Int
    public var scanQualityScore: Int?
    public var updatedAt: Date
}

public struct WorkflowBearingTelemetry: Codable, Equatable, Identifiable {
    public var id: UUID = UUID()
    public var bearingDegrees: Double
    public var sigmaDegrees: Double? = nil
    public var sampleCount: Int? = nil
    public var northReferenceRaw: String
    public var declinationDegrees: Double
    public var magneticStrengthUT: Double
    public var isLevel: Bool
    public var pitchDegrees: Double
    public var rollDegrees: Double
    public var sourceLabel: String
    public var capturedAt: Date
}

public struct WorkflowCalculationTelemetry: Codable, Equatable {
    public var moduleName: String
    public var period: Int
    public var sittingFacing: String
    public var bearingDegrees: Double
    public var solarTerm: String
    public var pillarsSummary: String
    public var formulaBasis: String
    public var computedAt: Date
}

public final class SpatialWorkflowStore: ObservableObject {
    public static let shared = SpatialWorkflowStore()

    @Published public private(set) var survey: WorkflowSurveyTelemetry?
    @Published public private(set) var bearing: WorkflowBearingTelemetry?
    @Published public private(set) var bearingStations: [WorkflowBearingTelemetry] = []
    @Published public private(set) var calculation: WorkflowCalculationTelemetry?

    private let storageKey = "tianji.spatial_workflow_store.v1"
    private let defaults: UserDefaults

    private struct PersistedState: Codable {
        var survey: WorkflowSurveyTelemetry?
        var bearing: WorkflowBearingTelemetry?
        var bearingStations: [WorkflowBearingTelemetry]?
        var calculation: WorkflowCalculationTelemetry?
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode(PersistedState.self, from: data) {
            self.survey = decoded.survey
            self.bearing = decoded.bearing
            self.bearingStations = decoded.bearingStations ?? []
            self.calculation = decoded.calculation
        }
    }

    public var hasSurvey: Bool { survey != nil }
    public var hasBearing: Bool { bearing != nil }
    public var hasCalculation: Bool { calculation != nil }
    public var completedStages: Int {
        (hasSurvey ? 1 : 0) + (hasBearing ? 1 : 0) + (hasCalculation ? 1 : 0)
    }

    public func recordSurvey(
        source: String,
        widthMeters: Double?,
        depthMeters: Double?,
        areaSqMeters: Double?,
        ceilingHeightMeters: Double?,
        roomCount: Int,
        scanQualityScore: Int? = nil
    ) {
        let next = WorkflowSurveyTelemetry(
            source: source,
            widthMeters: widthMeters,
            depthMeters: depthMeters,
            areaSqMeters: areaSqMeters,
            ceilingHeightMeters: ceilingHeightMeters,
            roomCount: roomCount,
            scanQualityScore: scanQualityScore,
            updatedAt: Date()
        )
        let apply = {
            self.survey = next
            self.persist()
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    public func recordInstrumentBearing(
        bearingDegrees: Double,
        northReferenceRaw: String,
        declinationDegrees: Double,
        magneticStrengthUT: Double,
        isLevel: Bool,
        pitchDegrees: Double,
        rollDegrees: Double,
        sourceLabel: String,
        sigmaDegrees: Double? = nil,
        sampleCount: Int? = nil
    ) {
        let normalized = (bearingDegrees.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let next = WorkflowBearingTelemetry(
            bearingDegrees: normalized,
            sigmaDegrees: sigmaDegrees,
            sampleCount: sampleCount,
            northReferenceRaw: northReferenceRaw,
            declinationDegrees: declinationDegrees,
            magneticStrengthUT: magneticStrengthUT,
            isLevel: isLevel,
            pitchDegrees: pitchDegrees,
            rollDegrees: rollDegrees,
            sourceLabel: sourceLabel,
            capturedAt: Date()
        )
        let apply = {
            self.bearing = next
            self.bearingStations.insert(next, at: 0)
            if self.bearingStations.count > 8 {
                self.bearingStations = Array(self.bearingStations.prefix(8))
            }
            self.persist()
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    public func selectStation(_ station: WorkflowBearingTelemetry) {
        let apply = {
            self.bearing = station
            self.persist()
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    public func clearStations() {
        let apply = {
            self.bearingStations.removeAll()
            self.persist()
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    public func recordCalculation(
        moduleName: String,
        period: Int,
        sittingFacing: String,
        bearingDegrees: Double,
        solarTerm: String,
        pillarsSummary: String,
        formulaBasis: String
    ) {
        let next = WorkflowCalculationTelemetry(
            moduleName: moduleName,
            period: period,
            sittingFacing: sittingFacing,
            bearingDegrees: bearingDegrees,
            solarTerm: solarTerm,
            pillarsSummary: pillarsSummary,
            formulaBasis: formulaBasis,
            computedAt: Date()
        )
        let apply = {
            self.calculation = next
            self.persist()
        }
        if Thread.isMainThread { apply() } else { DispatchQueue.main.async(execute: apply) }
    }

    public func generateVerifiableReportText(date: Date = Date()) -> String {
        let lang = LocalizationManager.shared.effectiveLanguage
        let isEn = (lang == .en)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let motion = CompassMotionManager.shared
        let activeBearing = bearing?.bearingDegrees ?? motion.headingState.facingAngle
        let headingState = Mountain24Data.shared.resolveHeadingState(heading: activeBearing)
        let period = calculation?.period ?? FlyingStarsEngine.shared.currentPeriod(for: date)
        let solar = SolarTimeCalculator.shared.calculate(
            date: date,
            longitude: motion.hasLocationFix ? motion.longitude : 120.0
        )
        let xkChart = FlyingStarsEngine.shared.calculateChart(
            period: period,
            sitting: headingState.sittingMountain,
            facing: headingState.facingMountain,
            useTiGua: headingState.isJianXiang,
            date: date
        )
        let bz = BaZhaiEngine.shared.analyze(
            sittingPalace: headingState.sittingMountain.palace,
            facingPalace: headingState.facingMountain.palace
        )
        let qm = QimenEngine.shared.calculateChart(date: date, heading: activeBearing)

        var lines: [String] = []
        lines.append(isEn ? "=== TianJi Integrated Spatial & Calculation Report ===" : "=== 天机演象 · 空间测绘与方位计算综合报告 ===")
        lines.append((isEn ? "Generated: " : "生成时间：") + formatter.string(from: date))
        lines.append("")

        lines.append(isEn ? "[1. Spatial Survey (AR / LiDAR / Floorplan)]" : "【一、空间测绘数据（AR / LiDAR / 户型图）】")
        if let s = survey {
            lines.append((isEn ? "Source: " : "测绘来源：") + s.source)
            lines.append((isEn ? "Rooms: " : "房间数量：") + "\(s.roomCount)")
            if let w = s.widthMeters, let d = s.depthMeters {
                lines.append(String(format: isEn ? "Span (W × D): %.2f m × %.2f m" : "开间 × 进深：%.2f m × %.2f m", w, d))
            }
            if let area = s.areaSqMeters {
                lines.append(String(format: isEn ? "Measured Area: %.2f ㎡" : "实测面积：%.2f ㎡", area))
            }
            if let h = s.ceilingHeightMeters {
                lines.append(String(format: isEn ? "Ceiling Height: %.2f m" : "层高净高：%.2f m", h))
            }
            if let q = s.scanQualityScore {
                lines.append((isEn ? "Scan Quality Score: " : "扫描质量评分：") + "\(q)/100")
            }
        } else {
            lines.append(isEn ? "No spatial scan saved yet. Import a floorplan or run AR/LiDAR scan." : "尚未录入实测空间数据（可导入户型图或启动 AR/LiDAR 扫描）。")
        }
        lines.append("")

        lines.append(isEn ? "[2. Orientation Instrument Telemetry]" : "【二、电子方位仪测量记录】")
        if let b = bearing {
            let refLabel = b.northReferenceRaw == "true_north"
                ? (isEn ? "True North (WMM)" : "真北（WMM 磁偏角校正）")
                : (isEn ? "Magnetic North" : "地磁北")
            let sigmaSuffix: String
            if let sigma = b.sigmaDegrees, let count = b.sampleCount {
                sigmaSuffix = String(format: isEn ? " · σ=%.2f° (n=%d)" : " · 离散度 σ=%.2f°（%d 次采样）", sigma, count)
            } else {
                sigmaSuffix = ""
            }
            lines.append(String(format: isEn ? "Locked Bearing: %.1f° (%@)%@" : "锁定方位角：%.1f°（%@）%@", b.bearingDegrees, refLabel, sigmaSuffix))
            lines.append(String(format: isEn ? "Declination: %+.2f° · Field: %.1f μT" : "磁偏角：%+.2f° · 磁场强度：%.1f μT", b.declinationDegrees, b.magneticStrengthUT))
            lines.append(String(format: isEn ? "Tilt (Pitch/Roll): %.1f° / %.1f° (%@)" : "双轴水平仪（俯仰/横滚）：%.1f° / %.1f°（%@）",
                                b.pitchDegrees, b.rollDegrees, b.isLevel ? (isEn ? "Level" : "已端平") : (isEn ? "Tilted" : "存在倾角")))
            lines.append((isEn ? "Captured At: " : "采样时间：") + formatter.string(from: b.capturedAt))
        } else {
            lines.append(String(format: isEn ? "Live Bearing: %.1f° (Not yet locked via instrument)" : "当前实时方位：%.1f°（建议在方位仪中端平后锁定）", activeBearing))
        }
        if bearingStations.count > 1 {
            lines.append(isEn ? "Recorded Stations:" : "历史测站采样点：")
            for (idx, st) in bearingStations.prefix(5).enumerated() {
                let sig = st.sigmaDegrees.map { String(format: " ±%.2f°", $0) } ?? ""
                lines.append(String(format: "  #%d %@: %.1f°%@ (%.0f μT)", idx + 1, st.sourceLabel, st.bearingDegrees, sig, st.magneticStrengthUT))
            }
        }
        lines.append("")

        lines.append(isEn ? "[3. Verifiable Algorithmic Calculation Summary]" : "【三、可验证数理计算模块输出】")
        lines.append((isEn ? "24-Sector Mapping: " : "二十四山映射：") + "\(headingState.sittingMountain.localizedName)山\(headingState.facingMountain.localizedName)向 · \(headingState.kongWangLevel.localizedTitle)")
        lines.append((isEn ? "Astronomical Solar Term: " : "天文节气与干支：") + "\(solar.solarTermName) · \(solar.baziGanzhi)")
        lines.append((isEn ? "XuanKong Matrix: " : "玄空飞星排盘：") + "\(period)运 · \(LocalizationManager.shared.t(xkChart.pattern.titleKey)) · \(headingState.isJianXiang ? (isEn ? "Ti-Gua" : "替卦") : (isEn ? "Xia-Gua" : "下卦"))")
        lines.append((isEn ? "BaZhai Trigram Table: " : "八宅大游年表：") + "\(bz.localizedHouseGua) · \(bz.localizedHouseType)")
        lines.append((isEn ? "QiMen Calendrical Bureau: " : "时家奇门历法局：") + qm.title)
        lines.append("")

        lines.append(isEn
            ? "Note: All spatial geometry values are device-sensor estimates requiring on-site tape verification. Classical calculation tables are deterministic mathematical/calendrical mappings for cultural reference only."
            : "说明：空间尺寸由设备传感器估算，施工前请现场复核；玄空/八宅/三合/奇门输出均为基于实测方位角与天文历法的确定性规则计算，仅供建筑文化与数理研究参考。")

        return lines.joined(separator: "\n")
    }

    /// 导出结构化、可审计 JSON 报告（包含实测空间几何、仪器遥测精度与四大计算模块完整矩阵）。
    public func generateVerifiableReportJSON(date: Date = Date()) -> String {
        let motion = CompassMotionManager.shared
        let activeBearing = bearing?.bearingDegrees ?? motion.headingState.facingAngle
        let headingState = Mountain24Data.shared.resolveHeadingState(heading: activeBearing)
        let period = calculation?.period ?? FlyingStarsEngine.shared.currentPeriod(for: date)
        let solar = SolarTimeCalculator.shared.calculate(
            date: date,
            longitude: motion.hasLocationFix ? motion.longitude : 120.0
        )
        let xkChart = FlyingStarsEngine.shared.calculateChart(
            period: period,
            sitting: headingState.sittingMountain,
            facing: headingState.facingMountain,
            useTiGua: headingState.isJianXiang,
            date: date
        )
        let bz = BaZhaiEngine.shared.analyze(
            sittingPalace: headingState.sittingMountain.palace,
            facingPalace: headingState.facingMountain.palace
        )
        let qm = QimenEngine.shared.calculateChart(date: date, heading: activeBearing)

        struct AuditablePayload: Encodable {
            struct XuanKongCellDTO: Encodable {
                let palace: String
                let periodStar: Int
                let mountainStar: Int
                let facingStar: Int
            }
            struct BaZhaiRowDTO: Encodable {
                let palace: String
                let direction: String
                let star: String
            }
            struct QiMenCellDTO: Encodable {
                let palaceId: Int
                let palace: String
                let door: String
                let star: String
                let god: String
            }
            let schemaVersion: String
            let generatedAtISO8601: String
            let survey: WorkflowSurveyTelemetry?
            let activeBearing: WorkflowBearingTelemetry?
            let bearingStations: [WorkflowBearingTelemetry]
            let resolvedBearingDegrees: Double
            let sittingMountain: String
            let facingMountain: String
            let isTiGua: Bool
            let solarTerm: String
            let baziGanzhi: String
            let xuanKongPeriod: Int
            let xuanKongPattern: String
            let xuanKongPalaces: [XuanKongCellDTO]
            let baZhaiHouseGua: String
            let baZhaiHouseType: String
            let baZhaiTable: [BaZhaiRowDTO]
            let qimenBureau: String
            let qimenPalaces: [QiMenCellDTO]
        }

        let payload = AuditablePayload(
            schemaVersion: "1.0",
            generatedAtISO8601: ISO8601DateFormatter().string(from: date),
            survey: survey,
            activeBearing: bearing,
            bearingStations: bearingStations,
            resolvedBearingDegrees: activeBearing,
            sittingMountain: headingState.sittingMountain.name,
            facingMountain: headingState.facingMountain.name,
            isTiGua: headingState.isJianXiang,
            solarTerm: solar.solarTermName,
            baziGanzhi: solar.baziGanzhi,
            xuanKongPeriod: period,
            xuanKongPattern: xkChart.patternType,
            xuanKongPalaces: xkChart.palaces.map {
                .init(palace: $0.palaceName, periodStar: $0.periodStar, mountainStar: $0.mountainStar, facingStar: $0.facingStar)
            },
            baZhaiHouseGua: bz.houseGua,
            baZhaiHouseType: bz.houseType,
            baZhaiTable: bz.items.map {
                .init(palace: $0.guaName, direction: $0.direction, star: $0.star.rawValue)
            },
            qimenBureau: qm.title,
            qimenPalaces: qm.cells.map {
                .init(palaceId: $0.palaceId, palace: $0.palaceName, door: $0.doorName, star: $0.starName, god: $0.godName)
            }
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private func persist() {
        let state = PersistedState(
            survey: survey,
            bearing: bearing,
            bearingStations: bearingStations,
            calculation: calculation
        )
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: storageKey)
        }
    }
}
