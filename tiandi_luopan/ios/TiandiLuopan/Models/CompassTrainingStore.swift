import Foundation
import Combine
import SwiftUI

// MARK: - 罗盘测绘训练档案 (Compass Training Profile)
// 定位：把「正确使用专业方位仪」拆成可练习的技能关卡，全部基于真实测量动作，
// 不涉及任何占卜/命理结论；用于提升工具易用性与学习反馈（App Store 4.2/4.3 合规）。

public enum TrainingBadge: String, CaseIterable, Identifiable {
    case firstSample   = "first_sample"
    case steadyHand    = "steady_hand"
    case levelMaster   = "level_master"
    case navAligned    = "nav_aligned"
    case twoStations   = "two_stations"
    case cleanRead     = "clean_read"
    case explorer      = "explorer"
    // 分析模块
    case palaceScout   = "palace_scout"
    case chartReader   = "chart_reader"
    case sourceVerifier = "source_verifier"
    // 户型模块
    case roomPlanner   = "room_planner"
    case layoutAuditor = "layout_auditor"
    case areaMeasurer  = "area_measurer"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .firstSample: return "scope"
        case .steadyHand:  return "hand.raised"
        case .levelMaster: return "level"
        case .navAligned:  return "safari.fill"
        case .twoStations: return "mappin.and.ellipse"
        case .cleanRead:   return "checkmark.seal.fill"
        case .explorer:    return "sparkles"
        case .palaceScout: return "square.grid.3x3.fill"
        case .chartReader: return "chart.bar.doc.horizontal"
        case .sourceVerifier: return "doc.badge.gearshape"
        case .roomPlanner: return "bed.double.fill"
        case .layoutAuditor: return "checklist"
        case .areaMeasurer: return "ruler"
        }
    }

    public func title(_ isEn: Bool) -> String {
        switch self {
        case .firstSample: return isEn ? "First Reading"  : "首次测量"
        case .steadyHand:  return isEn ? "Steady Hands"    : "稳如磐石"
        case .levelMaster: return isEn ? "Level Pro"      : "水平达人"
        case .navAligned:  return isEn ? "True North Ready"  : "真北对齐"
        case .twoStations: return isEn ? "Site Surveyor"  : "多点勘测"
        case .cleanRead:   return isEn ? "Clear Signal"   : "信号纯净"
        case .explorer:    return isEn ? "Explorer"       : "探索者"
        case .palaceScout: return isEn ? "Palace Scout"   : "九宫探查"
        case .chartReader: return isEn ? "Chart Interpreter"   : "盘面解读"
        case .sourceVerifier: return isEn ? "Source Verifier" : "溯源核验"
        case .roomPlanner: return isEn ? "Room Planner"   : "房间规划"
        case .layoutAuditor: return isEn ? "Layout Reviewer" : "户型体检"
        case .areaMeasurer: return isEn ? "Area Measurement"  : "面积测算"
        }
    }

    public func detail(_ isEn: Bool) -> String {
        switch self {
        case .firstSample: return isEn ? "Complete a steady bearing sample" : "完成一次稳态均值采样"
        case .steadyHand:  return isEn ? "Hold the device level for 3 seconds" : "连续保持设备水平 3 秒"
        case .levelMaster: return isEn ? "Complete sampling while the device is level" : "在水平状态下完成采样"
        case .navAligned:  return isEn ? "Measure after true-north calibration" : "在真北校准后完成测量"
        case .twoStations: return isEn ? "Log two or more survey stations" : "记录两个及以上勘测站点"
        case .cleanRead:   return isEn ? "Sample with low magnetic interference" : "在低磁干扰下完成采样"
        case .explorer:    return isEn ? "Try all instrument tools" : "体验全部仪器工具"
        case .palaceScout: return isEn ? "Explore palaces in the nine-grid chart" : "查看九宫盘面中的宫位"
        case .chartReader: return isEn ? "Open a verification module" : "打开一个可验证计算模块"
        case .sourceVerifier: return isEn ? "Review the calculation audit card" : "查看算法溯源核验卡"
        case .roomPlanner: return isEn ? "Add or adjust a room in the floorplan" : "在户型中添加或调整房间"
        case .layoutAuditor: return isEn ? "Complete a whole-home layout review" : "完成一次全屋布局体检"
        case .areaMeasurer: return isEn ? "Measure a room area" : "完成房间面积测算"
        }
    }
}

public enum TrainingDrill: String, CaseIterable, Identifiable {
    case level    = "level"
    case sample   = "sample"
    case lock     = "lock"
    case sync     = "sync"
    case explore  = "explore"
    case audit     = "audit"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .level:  return "level"
        case .sample: return "scope"
        case .lock:   return "lock.fill"
        case .sync:   return "square.and.arrow.up"
        case .explore: return "square.grid.3x3.fill"
        case .audit:   return "checklist"
        }
    }

    public func title(_ isEn: Bool) -> String {
        switch self {
        case .level:  return isEn ? "Level"    : "调平"
        case .sample: return isEn ? "Sample"   : "采样"
        case .lock:   return isEn ? "Lock"     : "锁定"
        case .sync:   return isEn ? "Sync"     : "同步"
        case .explore: return isEn ? "Explore" : "探查"
        case .audit:   return isEn ? "Audit"   : "体检"
        }
    }

    public var xp: Int {
        switch self {
        case .level:  return 10
        case .sample: return 25
        case .lock:   return 15
        case .sync:   return 20
        case .explore: return 12
        case .audit:   return 18
        }
    }

    /// 关卡所属模块，用于分模块展示进度
    public var module: String {
        switch self {
        case .level, .sample, .lock, .sync: return "compass"
        case .explore: return "analysis"
        case .audit:   return "floorplan"
        }
    }

    /// 对应主 Tab 索引，供每日挑战一键跳转
    public var targetTab: Int {
        switch module {
        case "compass": return 2
        case "analysis": return 3
        default: return 0
        }
    }
}

public final class CompassTrainingStore: ObservableObject {
    public static let shared = CompassTrainingStore()

    @Published public private(set) var xp: Int = 0
    @Published public private(set) var badges: Set<String> = []
    @Published public private(set) var completedDrills: Set<String> = []
    @Published public private(set) var drillCounts: [String: Int] = [:]
    @Published public private(set) var activeDays: Set<String> = []
    @Published public private(set) var usedTools: Set<String> = []
    @Published public private(set) var dailyChallengeDoneDate: String = ""
    @Published public private(set) var lastEarnedTitle: String = ""
    @Published public private(set) var showEarnedToast: Bool = false

    private let defaults = UserDefaults.standard
    private let xpKey = "compass_training_xp"
    private let badgesKey = "compass_training_badges"
    private let drillsKey = "compass_training_drills"
    private let countsKey = "compass_training_counts"
    private let daysKey = "compass_training_days"
    private let toolsKey = "compass_training_tools"
    private let dailyDoneKey = "compass_training_daily_done"

    private init() {
        self.xp = defaults.integer(forKey: xpKey)
        if let saved = defaults.stringArray(forKey: badgesKey) { self.badges = Set(saved) }
        if let saved = defaults.stringArray(forKey: drillsKey) { self.completedDrills = Set(saved) }
        if let saved = defaults.dictionary(forKey: countsKey) as? [String: Int] { self.drillCounts = saved }
        if let saved = defaults.stringArray(forKey: daysKey) { self.activeDays = Set(saved) }
        if let saved = defaults.stringArray(forKey: toolsKey) { self.usedTools = Set(saved) }
        self.dailyChallengeDoneDate = defaults.string(forKey: dailyDoneKey) ?? ""
    }

    public var level: Int { xp / 100 + 1 }
    public var levelProgress: Double { Double(xp % 100) / 100.0 }
    public func levelTitle(isEn: Bool = false) -> String {
        if isEn {
            switch level {
            case 1: return "Trainee"
            case 2: return "Junior Surveyor"
            case 3: return "Surveyor"
            case 4: return "Senior Surveyor"
            default: return "Master Surveyor"
            }
        }
        switch level {
        case 1: return "见习测绘员"
        case 2: return "初级测绘员"
        case 3: return "中级测绘员"
        case 4: return "高级测绘员"
        default: return "资深测绘师"
        }
    }

    public func isBadgeEarned(_ badge: TrainingBadge) -> Bool { badges.contains(badge.rawValue) }
    public func isDrillDone(_ drill: TrainingDrill) -> Bool { completedDrills.contains(drill.rawValue) }

    // MARK: - 日期 / 每日挑战 / 连续打卡

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    private static let seedFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyyMMdd"
        return f
    }()

    private func dayKey(_ date: Date) -> String {
        Self.dayFormatter.string(from: date)
    }

    /// 每天按日期确定性轮换一个关卡（同一天所有设备一致）。
    public func dailyChallenge(for date: Date = Date()) -> TrainingDrill {
        let seed = Int(Self.seedFormatter.string(from: date)) ?? 0
        return TrainingDrill.allCases[seed % TrainingDrill.allCases.count]
    }

    public func isDailyChallengeDone(_ date: Date = Date()) -> Bool {
        dailyChallengeDoneDate == dayKey(date)
    }

    /// 连续活动天数（含今天；今天未活动则从昨天算起）。
    public var streakDays: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var cursor = today
        if !activeDays.contains(dayKey(cursor)), let prev = cal.date(byAdding: .day, value: -1, to: cursor) {
            cursor = prev
        }
        var count = 0
        while activeDays.contains(dayKey(cursor)) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return count
    }

    /// 关卡星级：累计完成 1/3/5 次对应 1/2/3 星。
    public func stars(for drill: TrainingDrill) -> Int {
        let n = drillCounts[drill.rawValue] ?? 0
        if n >= 5 { return 3 }
        if n >= 3 { return 2 }
        if n >= 1 { return 1 }
        return 0
    }

    public var totalDrillCompletions: Int { drillCounts.values.reduce(0, +) }

    /// 完成一次关卡动作；重复动作给少量经验，首次额外提示。
    public func completeDrill(_ drill: TrainingDrill, isEn: Bool = false) {
        let first = completedDrills.insert(drill.rawValue).inserted
        let count = (drillCounts[drill.rawValue] ?? 0) + 1
        drillCounts[drill.rawValue] = count

        let today = dayKey(Date())
        activeDays.insert(today)

        var earned = first ? drill.xp : max(2, drill.xp / 5)
        var note = first ? drill.title(isEn) + (isEn ? " completed" : "完成") : ""

        // 每日挑战：当天首次完成轮换关卡，双倍经验
        if drill == dailyChallenge(), dailyChallengeDoneDate != today {
            dailyChallengeDoneDate = today
            earned += drill.xp
            note = isEn ? "Daily challenge complete" : "每日挑战完成"
        }
        // 连续打卡加成
        if streakDays >= 3 { earned += 5 }

        addXP(earned, title: note, isEn: isEn)
        persist()
    }

    public func earnBadge(_ badge: TrainingBadge, isEn: Bool = false) {
        guard badges.insert(badge.rawValue).inserted else { return }
        activeDays.insert(dayKey(Date()))
        addXP(30, title: badge.title(isEn), isEn: isEn)
        persist()
    }

    /// 记录一次仪器工具的使用；体验齐全后解锁探索者徽章。
    public func recordTool(_ tool: String, isEn: Bool = false) {
        guard usedTools.insert(tool).inserted else { return }
        activeDays.insert(dayKey(Date()))
        if usedTools.count >= 4 { earnBadge(.explorer, isEn: isEn) }
        else { persist() }
    }

    private var toastToken: Int = 0

    private func addXP(_ amount: Int, title: String, isEn: Bool) {
        let oldLevel = level
        xp += amount
        // 升级优先展示升级文案；否则展示本次动作文案。
        // 两条路径只调度一次 toast，避免同一动作产生多次发布与多次持久化。
        let message = level > oldLevel ? levelUpText(isEn: isEn)
                                       : (title.isEmpty ? "" : "+\(amount) XP · \(title)")
        if !message.isEmpty {
            lastEarnedTitle = message
            toastToken += 1
            let token = toastToken
            withAnimation { showEarnedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                guard token == self.toastToken else { return }
                withAnimation { self.showEarnedToast = false }
            }
        }
    }

    private func levelUpText(isEn: Bool) -> String {
        "LEVEL \(level) · \(levelTitle(isEn: isEn))"
    }

    private func persist() {
        defaults.set(xp, forKey: xpKey)
        defaults.set(Array(badges), forKey: badgesKey)
        defaults.set(Array(completedDrills), forKey: drillsKey)
        defaults.set(drillCounts, forKey: countsKey)
        defaults.set(Array(activeDays), forKey: daysKey)
        defaults.set(Array(usedTools), forKey: toolsKey)
        defaults.set(dailyChallengeDoneDate, forKey: dailyDoneKey)
    }
}
