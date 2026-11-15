import Foundation
import Combine

/// 设置页的展示状态。
///
/// 视图不再自己维护 4 个平行 @State（弹层是否显示、文案、是否错误、选中商品），
/// 也不需要知道 StoreKit 管理器「先呈现再清理瞬时消息」的时序。
public final class SettingsViewModel: ObservableObject {
    public struct Alert: Equatable {
        public let message: String
        public let isError: Bool

        public init(message: String, isError: Bool) {
            self.message = message
            self.isError = isError
        }
    }

    @Published public var selectedProductId: String = IAPProductID.proLifetime.rawValue
    @Published public private(set) var alert: Alert?

    public init() {}

    /// 页面激活：清掉上次残留的瞬时消息并刷新商品列表。
    public func activate(iap: StoreKitIAPManager) {
        alert = nil
        iap.clearTransientMessages()
        iap.refreshProductsIfNeeded()
    }

    /// 支付成功/失败共用一条呈现路径，避免两处 onReceive 各写一遍状态机。
    public func handlePurchaseMessage(_ message: String?, isError: Bool, iap: StoreKitIAPManager) {
        guard let message else { return }
        alert = Alert(message: message, isError: isError)
        iap.clearTransientMessages()
    }

    public func dismissAlert() {
        alert = nil
    }
}
