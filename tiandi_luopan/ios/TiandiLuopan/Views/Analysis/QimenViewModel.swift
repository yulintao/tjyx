import Foundation
import Combine

/// 奇门遁甲页的状态中枢。
///
/// 视图层只保留布局与手势，把「什么时候需要重排、按什么口径重排、当前选中哪一宫/哪一种问事场景」
/// 全部收在这里。重算的门限规则（同一时辰内方位变化 1° 以内不重算）也集中在此，
/// 避免散落在多个 onChange / onReceive 里各写一份。
final class QimenViewModel: ObservableObject {

    /// 当前排盘结果。视图在首次进入或数据为空时用 `fallbackChart(heading:)` 兜底。
    @Published private(set) var chart: QimenChart?

    /// 时辰穿越用的自定义时间。
    @Published var selectedDate: Date = Date()
    /// 是否已进入「时辰穿越」模式（此时不再跟随当前时间）。
    @Published private(set) var isUsingCustomDate: Bool = false

    /// 用户点选的宫位；为空时跟随场景推荐宫。
    @Published var selectedPalaceId: Int?

    /// 一事一断的场景。
    @Published var selectedScenario: QimenScenarioType = .contract

    /// 付费墙开关。
    @Published var showPaywall: Bool = false

    private var lastHeading: Double?
    private var lastTimeKey: QimenChartTimeKey?

    init() {}

    /// 排盘基准时间：穿越模式下用用户选的时间，否则取当下一刻。
    var effectiveDate: Date {
        isUsingCustomDate ? selectedDate : Date()
    }

    /// 当前有效的宫位：用户手选优先，否则用场景推荐宫。
    func activePalaceId(recommendation: QimenScenarioRecommendation?) -> Int? {
        selectedPalaceId ?? recommendation?.recommendedPalaceId
    }

    /// 场景推荐（需要当前盘与方位）。
    func recommendation(heading: Double) -> QimenScenarioRecommendation? {
        guard let chart else { return nil }
        return QimenEngine.shared.evaluateScenario(
            selectedScenario,
            chart: chart,
            heading: heading
        )
    }

    /// 前/后移一个时辰（奇门按时家起局，每 2 小时换一局）。
    func shiftHour(by hours: Int, heading: Double) {
        let base = effectiveDate
        selectedDate = Calendar.current.date(byAdding: .hour, value: hours, to: base) ?? base
        isUsingCustomDate = true
        refresh(force: true, heading: heading, isActive: true)
    }

    /// 用户直接改了日期控件。
    func setCustomDate(_ date: Date, heading: Double) {
        selectedDate = date
        isUsingCustomDate = true
        refresh(force: true, heading: heading, isActive: true)
    }

    /// 回到此刻，退出穿越模式。
    func resetToNow(heading: Double) {
        isUsingCustomDate = false
        selectedDate = Date()
        refresh(force: true, heading: heading, isActive: true)
    }

    /// 切换问事场景，并把选中宫跳到该场景的首选宫。
    func selectScenario(_ scenario: QimenScenarioType, heading: Double) {
        selectedScenario = scenario
        guard let chart else { return }
        let rec = QimenEngine.shared.evaluateScenario(scenario, chart: chart, heading: heading)
        selectedPalaceId = rec.recommendedPalaceId
    }

    /// 重排。`force` 用于语言切换、回到前台这类必须重算的场合；
    /// 否则同一时辰内方位变化不足 1° 时直接跳过，避免传感器噪声引起整表刷行。
    func refresh(force: Bool = false, heading: Double, isActive: Bool) {
        guard isActive else { return }
        let timeKey = QimenEngine.shared.chartTimeKey(for: effectiveDate)

        if !force, let lastHeading, let lastTimeKey, lastTimeKey == timeKey {
            let rawDelta = abs(heading - lastHeading)
            let delta = min(rawDelta, 360.0 - rawDelta)
            if delta < 1.0 { return }
        }

        self.lastHeading = heading
        lastTimeKey = timeKey
        chart = QimenEngine.shared.calculateChart(date: effectiveDate, heading: heading)
    }
}
