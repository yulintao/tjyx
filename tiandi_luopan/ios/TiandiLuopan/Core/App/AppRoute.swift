import Foundation

/// 一次页面跳转意图。替代原先的（下标, 子页, 弹卡, 功能）四元组，
/// 让调用方只描述「去哪」，不关心 Tab 下标。
public struct AppRoute: Equatable {
    public let tab: AppTab

    public init(tab: AppTab) {
        self.tab = tab
    }
}
