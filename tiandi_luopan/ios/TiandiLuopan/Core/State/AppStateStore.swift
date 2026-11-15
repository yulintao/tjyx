import Foundation
import Combine

/// 应用级 UI 状态中枢。
///
/// 把原先散落在 RootContentView 里的 @State 收进来：选中 Tab、引导页与「今日黄历」卡片。
/// 深链 / 快捷指令 / Spotlight 的路由意图也在这里归一，视图只负责渲染。
public final class AppStateStore: ObservableObject {
    @Published public var selectedTab: AppTab = .ar
    @Published public var showOnboarding = false
    @Published public var showShortcutDailyCard = false

    private let router: AppNavigationRouter

    /// 每个窗口各自持有一份页面状态：iPad 多窗口下两个窗口可以停在不同页，
    /// 只有路由单例（深链意图）是全局共享的。
    public init(router: AppNavigationRouter = .shared, initialTab: AppTab = .ar) {
        self.router = router
        self.selectedTab = initialTab
    }

    /// 幂等消费待处理路由。冷启动由视图挂载后调用，热启动由通知触发。
    public func consumePendingRoutes() {
        // 黄历卡片是横跨各页的浮层，不再需要先跳到某个专属页面。
        if router.consumeAlmanac() {
            showOnboarding = false
            showShortcutDailyCard = true
        }
        guard let route = router.consumeTabRoute() else { return }
        selectedTab = route.tab
        if route.openDailyCard {
            showOnboarding = false
            showShortcutDailyCard = true
        }
    }
}
