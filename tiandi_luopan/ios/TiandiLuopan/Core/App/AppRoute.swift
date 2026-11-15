import Foundation

/// 一次页面跳转意图。替代原先的（下标, 子页, 弹卡, 功能）四元组，
/// 让调用方只描述「去哪」，不关心 Tab 下标与子页编号。
public struct AppRoute: Equatable {
    public let tab: AppTab
    public let anchor: AnalysisAnchor?
    public let openDailyCard: Bool

    public init(tab: AppTab,
                anchor: AnalysisAnchor? = nil,
                openDailyCard: Bool = false) {
        self.tab = tab
        self.anchor = anchor
        self.openDailyCard = openDailyCard
    }
}

/// 理气页的落点：既可表达「某个功能」，也可表达「旧子页编号」。
/// 旧编号由 `AnalysisFeature.legacySubTab` / `fromLegacySubTab` 负责双向换算。
public enum AnalysisAnchor: Equatable {
    case feature(AnalysisFeature)
    case legacySubTab(Int)

    /// 归一成具体功能；无法换算的旧子页返回 nil。
    public var feature: AnalysisFeature? {
        switch self {
        case .feature(let f):
            return f
        case .legacySubTab(let sub):
            return AnalysisFeature.fromLegacySubTab(sub)
        }
    }

    /// 归一成旧子页编号，供仍按子页索引工作的视图使用。
    public var legacySubTab: Int? {
        switch self {
        case .feature(let f):
            return f.legacySubTab
        case .legacySubTab(let sub):
            return sub
        }
    }
}
