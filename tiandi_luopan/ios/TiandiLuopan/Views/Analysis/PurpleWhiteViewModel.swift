import Foundation
import Combine

/// 紫白飞星页的状态中枢。
///
/// 只管两件事：什么时候该重算（节气月、日历日、朝向扇区三者任一变化才重算），
/// 以及当前选中哪一宫。视图层不再持有盘面与时间。
final class PurpleWhiteViewModel: ObservableObject {

    @Published private(set) var chart: PurpleWhiteChart?
    @Published var selectedDate: Date = Date()
    @Published private(set) var isUsingCustomDate: Bool = false
    @Published var selectedPalaceId: Int?
    @Published var showPaywall: Bool = false

    private var lastFacingSector: Int?
    private var lastCalendarDayKey: Int?
    private var lastSolarTermIndex: Int?

    init() {}

    var effectiveDate: Date { isUsingCustomDate ? selectedDate : Date() }

    /// 当前解读的宫位：手选优先，否则跟随当前朝向宫。
    func activePalaceId(chart: PurpleWhiteChart) -> Int {
        selectedPalaceId ?? chart.currentFacingPalace
    }

    /// 流月切换（按节气月推 30 天）。
    func shiftMonth(byDays days: Int, heading: Double) {
        let base = effectiveDate
        selectedDate = Calendar.current.date(byAdding: .day, value: days, to: base) ?? base
        isUsingCustomDate = true
        refresh(force: true, heading: heading, isActive: true)
    }

    func setCustomDate(_ date: Date, heading: Double) {
        selectedDate = date
        isUsingCustomDate = true
        refresh(force: true, heading: heading, isActive: true)
    }

    func resetToNow(heading: Double) {
        isUsingCustomDate = false
        selectedDate = Date()
        refresh(force: true, heading: heading, isActive: true)
    }

    func refresh(force: Bool = false, heading: Double, isActive: Bool) {
        guard isActive else { return }
        let date = effectiveDate
        let sector = facingSector(for: heading)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let calendarDayKey = (components.year ?? 0) * 10_000
            + (components.month ?? 0) * 100
            + (components.day ?? 0)
        let termIndex = SolarTimeCalculator.shared.solarTermIndex(for: date)

        if !force, lastFacingSector == sector, lastCalendarDayKey == calendarDayKey,
           lastSolarTermIndex == termIndex { return }

        lastFacingSector = sector
        lastCalendarDayKey = calendarDayKey
        lastSolarTermIndex = termIndex
        chart = PurpleWhiteEngine.shared.calculateChart(date: date, heading: heading)
    }

    /// 把朝向折算成九宫编号，用于判断是否需要重排。
    private func facingSector(for heading: Double) -> Int {
        let normalized = (heading.truncatingRemainder(dividingBy: 360.0) + 360.0)
            .truncatingRemainder(dividingBy: 360.0)
        switch normalized {
        case 337.5..<360.0, 0.0..<22.5: return 1
        case 22.5..<67.5: return 8
        case 67.5..<112.5: return 3
        case 112.5..<157.5: return 4
        case 157.5..<202.5: return 9
        case 202.5..<247.5: return 2
        case 247.5..<292.5: return 7
        default: return 6
        }
    }
}
