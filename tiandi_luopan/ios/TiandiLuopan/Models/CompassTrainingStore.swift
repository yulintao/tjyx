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
        }
    }

    public func title(_ isEn: Bool) -> String {
        switch self {
        case .firstSample: return isEn ? "First Reading"  : "首次测量"
        case .steadyHand:  return isEn ? "Steady Hand"    : "稳如磐石"
        case .levelMaster: return isEn ? "Level Pro"      : "水平达人"
        case .navAligned:  return isEn ? "North Aligned"  : "真北对齐"
        case .twoStations: return isEn ? "Site Surveyor"  : "多点勘测"
        case .cleanRead:   return isEn ? "Clean Signal"   : "信号纯净"
        case .explorer:    return isEn ? "Explorer"       : "探索者"
        }
    }

    public func detail(_ isEn: Bool) -> String {
        switch self {
        case .firstSample: return isEn ? "Complete a steady bearing sample" : "完成一次稳态均值采样"
        case .steadyHand:  return isEn ? "Keep the device level for 3 seconds" : "连续保持设备水平 3 秒"
        case .levelMaster: return isEn ? "Finish sampling while perfectly level" : "在水平状态下完成采样"
        case .navAligned:  return isEn ? "Calibrate with true north enabled" : "在真北校准后完成测量"
        case .twoStations: return isEn ? "Record two survey stations" : "记录两个及以上勘测站点"
        case .cleanRead:   return isEn ? "Sample with low magnetic interference" : "在低磁干扰下完成采样"
        case .explorer:    return isEn ? "Try every instrument tool once" : "体验全部仪器工具"
        }
    }
}

public enum TrainingDrill: String, CaseIterable, Identifiable {
    case level    = "level"
    case sample   = "sample"
    case lock     = "lock"
    case sync     = "sync"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .level:  return "level"
        case .sample: return "scope"
        case .lock:   return "lock.fill"
        case .sync:   return "square.and.arrow.up"
        }
    }

    public func title(_ isEn: Bool) -> String {
        switch self {
        case .level:  return isEn ? "Level"    : "调平"
        case .sample: return isEn ? "Sample"   : "采样"
        case .lock:   return isEn ? "Lock"     : "锁定"
        case .sync:   return isEn ? "Sync"     : "同步"
        }
    }

    public var xp: Int {
        switch self {
        case .level:  return 10
        case .sample: return 25
        case .lock:   return 15
        case .sync:   return 20
        }
    }
}

public final class CompassTrainingStore: ObservableObject {
    public static let shared = CompassTrainingStore()

    @Published public private(set) var xp: Int = 0
    @Published public private(set) var badges: Set<String> = []
    @Published public private(set) var completedDrills: Set<String> = []
    @Published public private(set) var lastEarnedTitle: String = ""
    @Published public private(set) var showEarnedToast: Bool = false

    private let defaults = UserDefaults.standard
    private let xpKey = "compass_training_xp"
    private let badgesKey = "compass_training_badges"
    private let drillsKey = "compass_training_drills"

    private init() {
        self.xp = defaults.integer(forKey: xpKey)
        if let saved = defaults.stringArray(forKey: badgesKey) { self.badges = Set(saved) }
        if let saved = defaults.stringArray(forKey: drillsKey) { self.completedDrills = Set(saved) }
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

    /// 完成一次关卡动作；重复动作给少量经验，首次额外提示。
    public func completeDrill(_ drill: TrainingDrill, isEn: Bool = false) {
        let first = completedDrills.insert(drill.rawValue).inserted
        addXP(first ? drill.xp : max(2, drill.xp / 5), title: first ? drill.title(isEn) + (isEn ? " complete" : " · 完成") : "")
        persist()
    }

    public func earnBadge(_ badge: TrainingBadge, isEn: Bool = false) {
        guard badges.insert(badge.rawValue).inserted else { return }
        addXP(30, title: badge.title(isEn))
        persist()
    }

    private func addXP(_ amount: Int, title: String) {
        let oldLevel = level
        xp += amount
        if !title.isEmpty {
            lastEarnedTitle = "+\(amount) XP · \(title)"
            withAnimation { showEarnedToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation { self.showEarnedToast = false }
            }
        }
        if level > oldLevel {
            lastEarnedTitle = isEnLocalizedLevelUp()
        }
    }

    private func isEnLocalizedLevelUp() -> String {
        "LEVEL \(level) · \(levelTitle(isEn: false))"
    }

    private func persist() {
        defaults.set(xp, forKey: xpKey)
        defaults.set(Array(badges), forKey: badgesKey)
        defaults.set(Array(completedDrills), forKey: drillsKey)
    }
}
