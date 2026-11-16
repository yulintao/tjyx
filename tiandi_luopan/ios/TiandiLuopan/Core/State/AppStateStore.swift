import Foundation
import Combine

/// 应用级 UI 状态中枢。
///
/// 把原先散落在 RootContentView 里的 @State 收进来：选中 Tab、引导页与待处理路由。
/// 深链 / 快捷指令 / Spotlight 的路由意图也在这里归一，视图只负责渲染。
public final class AppStateStore: ObservableObject {
    /// 启动落在户型页：它是主导航最左边的一页，也是唯一不依赖相机与动作传感器的入口。
    @Published public var selectedTab: AppTab = .floorplan
    @Published public var showOnboarding = false

    private let router: AppNavigationRouter

    /// 每个窗口各自持有一份页面状态：iPad 多窗口下两个窗口可以停在不同页，
    /// 只有路由单例（深链意图）是全局共享的。
    public init(router: AppNavigationRouter = .shared, initialTab: AppTab = .floorplan) {
        self.router = router
        self.selectedTab = initialTab
    }

    /// 幂等消费待处理路由。冷启动由视图挂载后调用，热启动由通知触发。
    public func consumePendingRoutes() {
        guard let route = router.consumeTabRoute() else { return }
        selectedTab = route.tab
    }
}
