import SwiftUI
import StoreKit
import Combine

// MARK: - VIP 权限拦截遮罩卡片 (VIP Lock Card View)

public struct VIPLockCardView: View {
    @ObservedObject private var iap = StoreKitIAPManager.shared
    public let title: String
    public let featureDesc: String
    public var badge: String = LocalizationManager.shared.t("vip_badge_title")
    public var targetProductId: IAPProductID = .proLifetime
    public var onUnlockTap: () -> Void
    
    public init(
        title: String,
        featureDesc: String,
        badge: String = LocalizationManager.shared.t("vip_badge_title"),
        targetProductId: IAPProductID = .proLifetime,
        onUnlockTap: @escaping () -> Void
    ) {
        self.title = title
        self.featureDesc = featureDesc
        self.badge = badge
        self.targetProductId = targetProductId
        self.onUnlockTap = onUnlockTap
    }
    
    public var body: some View {
        VStack(spacing: 12) {
            // 窄分栏右栏里标题、徽章与图标横排会互相穿插；标题独占一行，
            // 图标与徽章另起一行，长词语言也能完整换行。
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .adaptiveFont(size: 15, weight: .bold)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        .adaptiveFont(size: 20)
                    Text(badge)
                        .adaptiveFont(size: 10, weight: .bold)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow.opacity(0.2))
                        .foregroundColor(Color.yellow)
                        .cornerRadius(4)
                    Spacer(minLength: 0)
                }
            }
            
            Text(featureDesc)
                .adaptiveFont(size: 12)
                .foregroundColor(.white.opacity(0.75))
                .lineSpacing(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 8) {
                Button(action: onUnlockTap) {
                    HStack(spacing: 6) {
                        Image(systemName: "crown.fill")
                        Text("\(purchaseActionTitle) (\(iap.localizedBillingPrice(for: targetProductId)))")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .adaptiveFont(size: 12, weight: .bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.8, blue: 0.35), Color(red: 0.75, green: 0.55, blue: 0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.13, green: 0.12, blue: 0.11))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        // iPad 自适应：锁定卡在宽屏（iPad / Duo 内屏）上限制最大宽度并居中，
        // 避免说明文字被拉到 1000pt 宽、单行过长影响可读性；iPhone 上无影响。
        .frame(maxWidth: 640)
        // 外层全宽 frame 负责居中：只写 maxWidth: 640 时，父容器若非居中对齐
        // 会贴边显示，兑现不了上面注释里的「居中」。
        .frame(maxWidth: .infinity)
    }

    private var purchaseActionTitle: String {
        switch targetProductId {
        case .vipYearly, .proLifetime:
            return LocalizationManager.shared.t("unlock_vip_now")
        case .floorplanSingle, .tianjiSingle:
            return LocalizationManager.shared.t("pay_securely")
        }
    }
}
