import Foundation
import Combine
import CoreGraphics

/// 玄空页的全部可变状态与排盘规则。
///
/// 视图此前把元运、下卦/替卦手选锁定、分析日期、九宫选中宫、缓存盘面与五六个 sheet
/// 开关一起摊在 body 里；任何一次刷新都要重新走一遍 `captureAnalysis → calculateChart →
/// deepAnalysis`，而盘面又只在「坐向、元运、日期、语言」变化时才该重算。
/// 把这些规则集中到 ViewModel 后，视图只需要在事件点上请求刷新。
final class XuanKongViewModel: ObservableObject {

    // MARK: 立极与时间
    /// 是否按户型档案立极（而非按实时罗盘）。
    @Published var analyzeHome: Bool = false
    /// 首次打开玄空页时自动选择一次数据来源，之后不再覆盖用户的选择。
    @Published var didChooseSource: Bool = false
    @Published var analysisDate: Date = Date()
    /// 跟随今天：跨零点/回到前台时自动把分析日期拨到当前。
    @Published var followsToday: Bool = true

    // MARK: 元运与下卦/替卦
    @Published var selectedPeriod: Int = FlyingStarsEngine.shared.currentPeriod(for: Date())
    /// 手动替卦锁定：nil 表示跟随传感器的兼向判定；非 nil 表示用户已手动指定。
    /// 换坐/向山后必须重置回跟随，否则用户已看清的盘会被新样本改写。
    @Published var starMode = FlyingStarModeSelection()
    @Published var lastCurrentPeriod: Int = FlyingStarsEngine.shared.currentPeriod(for: Date())

    // MARK: 排盘结果
    @Published private(set) var chart: XuanKongChart?
    @Published private(set) var deepAnalysis: XuanKongDeepAnalysis?
    @Published private(set) var lastAnalysisSnapshot: TianJiAnalysisSnapshot?
    @Published var selectedPalaceIndex: Int = 4

    // MARK: 导航与弹层
    @Published var selectedFeature: AnalysisFeature?
    @Published var toolRequest: AnalysisToolRequest?
    @Published var reportSnapshot: TianJiAnalysisSnapshot?
    @Published var showTianJiShuSheet: Bool = false
    @Published var showDailySignSheet: Bool = false
    @Published var showPaywall: Bool = false
    @Published var showMountainPickerSheet: Bool = false

    // MARK: - 刷新

    /// 重排盘面。只有可见且停在玄空页时才计算，其余情况直接释放缓存。
    func refresh(isActive: Bool,
                 motionHeading: CompassHeadingState,
                 homeFacing: Double?,
                 homeLayout: SavedFloorplanLayout?) {
        guard isActive, selectedFeature == .xuanKong else {
            chart = nil
            deepAnalysis = nil
            return
        }
        let isFirstChart = chart == nil
        let snapshot = captureAnalysis(motionHeading: motionHeading,
                                       homeFacing: homeFacing,
                                       homeLayout: homeLayout)
        let updated = snapshot.flyingStarsChart()
        let deep = snapshot.deepAnalysis(chart: updated)
        lastAnalysisSnapshot = snapshot
        if isFirstChart { selectedPalaceIndex = deep.priorities.first?.id ?? 4 }
        deepAnalysis = deep
        chart = updated
    }

    /// 只丢弃盘面缓存（返回功能菜单时用），不改变立极来源与手选锁定。
    func clearChartCache() {
        chart = nil
        deepAnalysis = nil
    }

    /// 丢弃缓存并回到跟随传感器。
    func invalidate() {
        lastAnalysisSnapshot = nil
        chart = nil
        starMode.restoreAutomatic()
    }

    /// 定时器/前台回到时的日期维护：跟随今天则拨到当前，元运若原本跟随当前则继续跟随。
    /// 返回是否发生了日期或元运变化（视图据此决定要不要刷新）。
    @discardableResult
    func syncClockToNow() -> Bool {
        let now = Date()
        var changed = false
        if followsToday {
            analysisDate = now
            changed = true
        }
        let currentPeriod = FlyingStarsEngine.shared.currentPeriod(for: now)
        // 用户主动选过历史元运就不动；只有原本就跟着当前元运的才跨年跟随。
        if selectedPeriod == lastCurrentPeriod, selectedPeriod != currentPeriod {
            selectedPeriod = currentPeriod
            changed = true
        }
        lastCurrentPeriod = currentPeriod
        return changed
    }

    /// 长卷报告用的当前快照：优先复用最近一次的排盘快照。
    func snapshotForReport(motionHeading: CompassHeadingState,
                           homeFacing: Double?,
                           homeLayout: SavedFloorplanLayout?) -> TianJiAnalysisSnapshot {
        captureAnalysis(motionHeading: motionHeading, homeFacing: homeFacing, homeLayout: homeLayout)
    }

    // MARK: - 快照采集

    private func captureAnalysis(motionHeading: CompassHeadingState,
                                 homeFacing: Double?,
                                 homeLayout: SavedFloorplanLayout?) -> TianJiAnalysisSnapshot {
        let usesHome = analyzeHome && homeFacing != nil
        let heading = usesHome ? (homeFacing ?? motionHeading.facingAngle) : motionHeading.facingAngle
        let headingState = Mountain24Data.shared.resolveHeadingState(heading: heading)
        let surveyStore = ShaSurveyStore.shared
        let context = usesHome
            ? XuanKongHomeContextBuilder.build(layout: homeLayout, survey: surveyStore.latestInterior,
                exterior: surveyStore.records, facts: surveyStore.siteFacts)
            : nil
        let report = usesHome ? homeLayout.map { layout in
            FloorplanEngine.shared.auditFloorplan(rooms: layout.rooms,
                centroid: CGPoint(x: layout.centroidX, y: layout.centroidY), heading: layout.compassRotation,
                aspectRatio: CGFloat(layout.aspectRatio ?? 1), date: analysisDate).report
        } ?? [] : []
        return TianJiAnalysisSnapshot(heading: heading, period: selectedPeriod,
            useTiGua: starMode.usesTiGua(automatic: headingState.isJianXiang), reportDate: analysisDate)
            .capturing(context: context, propertyKey: usesHome ? surveyStore.propertyKey : nil,
                floorplanReport: report, panoramaArchive: usesHome ? surveyStore.archive : nil)
    }
}
