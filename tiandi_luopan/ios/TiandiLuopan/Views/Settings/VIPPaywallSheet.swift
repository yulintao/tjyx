import SwiftUI
import StoreKit
import Combine

// MARK: - VIP 权限拦截遮罩卡片 (VIP Lock Card View)

public struct VIPLockCardView: View {
    @ObservedObject private var iap = StoreKitIAPManager.shared
    public let title: String
    public let featureDesc: String
    public var badge: String = LocalizationManager.shared.t("vip_badge_title")
    public var targetProductId: IAPProductID = .vipYearly
    public var onUnlockTap: () -> Void
    
    public init(
        title: String,
        featureDesc: String,
        badge: String = LocalizationManager.shared.t("vip_badge_title"),
        targetProductId: IAPProductID = .vipYearly,
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
                        .foregroundColor(Color.goldText)
                        .adaptiveFont(size: 20)
                    Text(badge)
                        .adaptiveFont(size: 10, weight: .bold)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.semWarn.opacity(0.2))
                        .foregroundColor(Color.semWarn)
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
                            colors: [Color.goldText, Color(red: 0.75, green: 0.55, blue: 0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.black)
                    .cornerRadius(8)
                }
                
                RestorePurchasesButton()
            }
        }
        .padding(14)
        .background(Color.surfaceCard)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.goldDeep.opacity(0.4), lineWidth: 1)
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

struct RestorePurchasesButton: View {
    enum Style {
        case compact
        case settingsRow
    }

    var presentsResult = true
    var style: Style = .compact
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var resultMessage = ""
    @State private var showResult = false

    var body: some View {
        Button {
            if presentsResult {
                iap.restorePurchases { message in
                    resultMessage = message
                    showResult = true
                }
            } else {
                iap.restorePurchases()
            }
        } label: {
            HStack(spacing: 8) {
                if style == .settingsRow { Image(systemName: "arrow.clockwise") }
                if iap.isRestoringPurchases { ProgressView().tint(Color.yanCyan) }
                Text(lang.t(iap.isRestoringPurchases ? "iap_restoring" : "restore_purchases"))
                    .fixedSize(horizontal: false, vertical: true)
                if style == .settingsRow { Spacer() }
            }
            .font(style == .settingsRow ? .body : .system(size: 12, weight: .semibold))
            .foregroundColor(Color.yanCyan)
            .frame(maxWidth: .infinity, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(iap.isProcessingPurchase)
        .alert(lang.t("restore_purchases"), isPresented: $showResult) {
            Button(lang.t("done"), role: .cancel) {}
        } message: {
            Text(resultMessage)
        }
    }
}

/// Shared by both direct purchase entry points. Keep the full billing details
/// and legal links immediately above the purchase action on every screen size.
struct PurchaseDisclosureView: View {
    let productID: IAPProductID
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared

    init(productID: IAPProductID) { self.productID = productID }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(iap.subscriptionPurchaseTerms(for: productID)?.title ?? productID.title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            if productID.includesAllFeatures {
                Text(lang.t("membership_benefits_notice"))
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
            }
            if productID == .vipYearly {
                if let terms = iap.subscriptionPurchaseTerms(for: productID) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lang.t("subscription_billing_price"))
                            .font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
                        Text(terms.localizedPricePerPeriod)
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(Color.yanGold)
                        Text(lang.t("subscription_billing_period") + ": " + terms.localizedPeriod)
                            .font(.system(size: 13)).foregroundColor(.white)
                    }
                    .accessibilityIdentifier("purchase.subscription.billing")
                } else {
                    Text(iap.isLoadingProducts ? lang.t("price_loading") : lang.t("subscription_details_unavailable"))
                        .font(.system(size: 13)).foregroundColor(.semWarn)
                }
                Text(lang.t("vip_legal_agreement"))
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
            } else {
                Text(iap.localizedPrice(for: productID))
                    .font(.system(size: 19, weight: .bold)).foregroundColor(Color.yanGold)
                Text(lang.t("purchase_one_time_notice"))
                    .font(.system(size: 12)).foregroundColor(.white.opacity(0.8))
            }
            VStack(alignment: .leading, spacing: 0) {
                Link(destination: LegalLinks.termsOfUse) {
                    Label(lang.t("legal_terms_button"), systemImage: "doc.text")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("purchase.terms")
                Link(destination: LegalLinks.privacyPolicy) {
                    Label(lang.t("legal_privacy_button"), systemImage: "hand.raised")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .accessibilityIdentifier("purchase.privacy")
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color.yanCyan)
        }
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - 全功能专业版 VIP 收银台弹窗 (VIP Paywall Sheet)

public struct VIPPaywallSheet: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    
    @State private var selectedProductId: String = IAPProductID.vipYearly.rawValue
    @State private var isPurchasing: Bool = false
    @State private var alertMsg: String = ""
    @State private var alertIsError: Bool = false
    @State private var showAlert: Bool = false
    @State private var successToast: String = ""

    /// 购买成功后给一次明确的成功反馈（触感 + 轻提示），再关闭付费页，避免静默 dismiss 的不确定感
    private func completePurchase(_ message: String) {
        isPurchasing = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        withAnimation { successToast = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation { successToast = "" }
            presentationMode.wrappedValue.dismiss()
        }
    }

    private var purchaseSuccessText: String {
        lang.effectiveLanguage == .en ? "Purchase successful · Benefits unlocked" : "购买成功 · 权益已解锁"
    }
    private var creditsAddedText: String {
        lang.effectiveLanguage == .en ? "Credits added to your account" : "次数已到账"
    }
    
    public init(defaultProductId: IAPProductID = .vipYearly) {
        _selectedProductId = State(initialValue: defaultProductId.rawValue)
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.08, green: 0.08, blue: 0.10)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 1. 顶部尊贵皇冠 Banner
                        VStack(spacing: 6) {
                            Image(systemName: selectedIsSingleProduct
                                  ? (selectedIAPProduct == .floorplanSingle ? "house.fill" : "scroll.fill")
                                  : "crown.fill")
                                .adaptiveFont(size: 40)
                                .foregroundColor(Color.goldText)
                                .padding(.top, 12)
                            
                            Text(selectedIsSingleProduct
                                 ? selectedIAPProduct.title
                                 : LocalizationManager.shared.t("vip_sheet_title"))
                                .adaptiveFont(size: 18, weight: .bold)
                                .foregroundColor(.white)
                            
                            Text(selectedIsSingleProduct
                                 ? selectedIAPProduct.desc
                                 : LocalizationManager.shared.t("vip_sheet_subtitle"))
                                .adaptiveFont(size: 11)
                                .foregroundColor(.white.opacity(0.65))
                        }
                        
                        // 2. 核心特权清单（仅展示空间测绘与户型 3D 专业能力，符合 4.3(b) 规范）
                        VStack(spacing: 8) {
                            if selectedIsSingleProduct {
                                privilegeItem(
                                    icon: selectedProductId == IAPProductID.floorplanSingle.rawValue ? "house.fill" : "scroll.fill",
                                    title: selectedIAPProduct.title,
                                    desc: selectedIAPProduct.desc
                                )
                            } else {
                                privilegeItem(icon: "house.fill", title: LocalizationManager.shared.t("privilege_floorplan_title"), desc: LocalizationManager.shared.t("privilege_floorplan_desc"))
                                privilegeItem(icon: "camera.viewfinder", title: LocalizationManager.shared.t("privilege_ar_title"), desc: LocalizationManager.shared.t("privilege_ar_desc"))
                                privilegeItem(icon: "view.3d", title: LocalizationManager.shared.t("vr_survey_title"), desc: LocalizationManager.shared.t("3d_metric_depth_width"))
                            }
                        }
                        .padding(12)
                        .background(Color(red: 0.12, green: 0.12, blue: 0.15))
                        .cornerRadius(12)
                        .padding(.horizontal, 16)
                        
                        // 3. 商品套餐选择
                        VStack(spacing: 8) {
                            productChoiceCard(
                                id: .vipYearly,
                                tag: LocalizationManager.shared.t("product_vip_yearly_tag"),
                                isSelected: selectedProductId == IAPProductID.vipYearly.rawValue
                            )
                            
                            Group {
                                productChoiceCard(
                                    id: .proLifetime,
                                    tag: LocalizationManager.shared.t("product_pro_lifetime_tag"),
                                    isSelected: selectedProductId == IAPProductID.proLifetime.rawValue
                                )
                            
                                productChoiceCard(
                                    id: .floorplanSingle,
                                    tag: LocalizationManager.shared.t("product_floorplan_single_tag"),
                                    isSelected: selectedProductId == IAPProductID.floorplanSingle.rawValue
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        if !iap.isLoadingProducts,
                           let reason = iap.purchaseUnavailableMessageKey(for: selectedIAPProduct) {
                            HStack(spacing: 8) {
                                Text(lang.t(reason))
                                    .adaptiveFont(size: 10)
                                    .foregroundColor(.semWarn.opacity(0.9))
                                Spacer()
                                Button(lang.t(reason == "iap_storage_unavailable" ? "iap_retry_purchase" : "reload_prices")) {
                                    iap.retryPurchaseAvailability()
                                }
                                .adaptiveFont(size: 11, weight: .semibold)
                                .foregroundColor(.yanCyan)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        PurchaseDisclosureView(productID: selectedIAPProduct)
                            .padding(12)
                            .background(Color.white.opacity(0.04))
                            .cornerRadius(10)
                            .padding(.horizontal, 16)

                        // 4. 购买与恢复操作按键
                        VStack(spacing: 10) {
                            Button(action: {
                                isPurchasing = true
                                iap.purchase(productId: selectedProductId)
                            }) {
                                HStack {
                                    if isPurchasing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                            .padding(.trailing, 4)
                                    }
                                    Text(isPurchasing ? LocalizationManager.shared.t("vip_connecting_store") : "\(selectedIsSingleProduct ? LocalizationManager.shared.t("pay_securely") : LocalizationManager.shared.t("unlock_vip_now")) (\(iap.localizedBillingPrice(for: selectedIAPProduct)))")
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .adaptiveFont(size: 14, weight: .bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    LinearGradient(
                                        colors: [Color.goldText, Color(red: 0.75, green: 0.55, blue: 0.2)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.black)
                                .cornerRadius(10)
                            }
                            .disabled(iap.isProcessingPurchase || iap.isLoadingProducts || !iap.canPurchaseProduct(for: selectedIAPProduct))
                            
                            RestorePurchasesButton(presentsResult: false)
                            .padding(.top, 2)
                        }
                        .padding(.horizontal, 16)
                        
                        // 5. 使用范围说明
                        VStack(spacing: 4) {
                            Text(LocalizationManager.shared.t("settings_safety_disclaimer"))
                                .adaptiveFont(size: 10)
                                .foregroundColor(.semWarn.opacity(0.75))
                                .multilineTextAlignment(.center)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    .frame(maxWidth: 640)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarTitle(LocalizationManager.shared.t("vip_member_center"), displayMode: .inline)
            .navigationBarItems(trailing: Button(LocalizationManager.shared.t("close")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay(
            Group {
                if !successToast.isEmpty {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.semJi)
                            Text(successToast)
                                .adaptiveFont(size: 13, weight: .semibold)
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, DS.padL)
                        .padding(.vertical, DS.padM)
                        .background(Color.surfaceElevated)
                        .cornerRadius(DS.radiusM)
                        .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(Color.semJi.opacity(0.5), lineWidth: 1))
                        .padding(.bottom, 60)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: successToast)
        )
        .onAppear {
            iap.clearTransientMessages()
            iap.refreshProductsIfNeeded()
        }
        .onReceive(iap.$isVIPUser) { isVip in
            if isVip { completePurchase(purchaseSuccessText) }
        }
        .onReceive(iap.$isLifetimeUser) { isLifetime in
            if isLifetime { completePurchase(purchaseSuccessText) }
        }
        .onReceive(iap.$floorplanCreditsCount) { count in
            if isPurchasing && count > 0 && selectedProductId == IAPProductID.floorplanSingle.rawValue {
                completePurchase(creditsAddedText)
            }
        }
        .onReceive(iap.$tianjiCreditsCount) { count in
            if isPurchasing && count > 0 && selectedProductId == IAPProductID.tianjiSingle.rawValue {
                completePurchase(creditsAddedText)
            }
        }
        .onReceive(iap.$isProcessingPurchase) { processing in
            isPurchasing = processing && !iap.isRestoringPurchases
        }
        .onReceive(iap.$lastErrorMessage.compactMap { $0 }) { message in
            isPurchasing = false
            alertIsError = true
            alertMsg = message
            showAlert = true
            iap.clearTransientMessages()
        }
        .onReceive(iap.$lastStatusMessage.compactMap { $0 }) { message in
            isPurchasing = false
            alertIsError = false
            alertMsg = message
            showAlert = true
            iap.clearTransientMessages()
        }
        .overlay(
            Group {
                if showAlert {
                    FloorplanConfirmDialog(
                        title: alertIsError
                            ? LocalizationManager.shared.t("payment_failed_title")
                            : LocalizationManager.shared.t("payment_status_title"),
                        message: alertMsg,
                        confirmTitle: LocalizationManager.shared.t("done"),
                        cancelTitle: nil,
                        confirmColor: Color.goldDeep,
                        onConfirm: { showAlert = false },
                        onCancel: { showAlert = false }
                    )
                }
            }
        )
    }
    
    private var selectedIAPProduct: IAPProductID {
        IAPProductID(rawValue: selectedProductId) ?? .vipYearly
    }

    private var selectedIsSingleProduct: Bool {
        selectedIAPProduct == .floorplanSingle || selectedIAPProduct == .tianjiSingle
    }
    
    private func privilegeItem(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .adaptiveFont(size: 14)
                .foregroundColor(Color.goldDeep)
                .frame(width: 20)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .adaptiveFont(size: 13, weight: .bold)
                    .foregroundColor(.white)
                Text(desc)
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.65))
            }
            Spacer()
        }
    }
    
    private func productChoiceCard(id: IAPProductID, tag: String, isSelected: Bool) -> some View {
        Button(action: {
            selectedProductId = id.rawValue
        }) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(id.title)
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(tag)
                            .adaptiveFont(size: 9, weight: .bold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(isSelected ? Color.semWarn.opacity(0.3) : Color.white.opacity(0.1))
                            .foregroundColor(isSelected ? .semWarn : .white.opacity(0.7))
                            .cornerRadius(3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(id.desc)
                        .adaptiveFont(size: 10)
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Text(iap.localizedBillingPrice(for: id))
                    .adaptiveFont(size: 15, weight: .bold, design: .monospaced)
                    .foregroundColor(Color.goldText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(isSelected ? Color.goldDeep.opacity(0.15) : Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.goldDeep : Color.white.opacity(0.08), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
