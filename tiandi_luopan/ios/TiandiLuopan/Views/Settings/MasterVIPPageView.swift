import SwiftUI
import Foundation
import UIKit

// MARK: - 功能页 1: 大师会员 (Master VIP Page)

public struct MasterVIPPageView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @Binding var selectedProductId: String

    public init(selectedProductId: Binding<String>) {
        self._selectedProductId = selectedProductId
    }

    private var isProUnlocked: Bool {
        iap.hasUnlockedVIP
    }

    private var selectedProductIsAvailable: Bool {
        guard let product = IAPProductID(rawValue: selectedProductId) else { return false }
        return iap.canPurchaseProduct(for: product)
    }

    public var body: some View {
        List {
            // 1. 会员状态与多档位收银台
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "crown.fill")
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Text(lang.t("vip_member_center"))
                            .adaptiveFont(size: 16, weight: .bold)
                            .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                        Spacer()
                        Text(isProUnlocked ? lang.t("vip_user") : lang.t("standard_user"))
                            .adaptiveFont(size: 11, weight: .bold)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(isProUnlocked ? Color.green.opacity(0.3) : Color.yellow.opacity(0.3))
                            .foregroundColor(isProUnlocked ? .green : .yellow)
                            .cornerRadius(6)
                    }

                    // 四档商品卡片选择
                    VStack(spacing: 8) {
                        productRow(id: .proLifetime, tag: lang.t("product_pro_lifetime_tag"))
                        productRow(id: .vipYearly, tag: lang.t("product_vip_yearly_tag"))
                        productRow(id: .floorplanSingle, tag: lang.t("product_floorplan_single_tag"))
                        productRow(id: .tianjiSingle, tag: lang.t("product_tianji_single_tag"))
                    }
                    .padding(.vertical, 4)

                    if !iap.isLoadingProducts,
                       let selectedProduct = IAPProductID(rawValue: selectedProductId),
                       let reason = iap.purchaseUnavailableMessageKey(for: selectedProduct) {
                        HStack(spacing: 8) {
                            Text(lang.t(reason))
                                .adaptiveFont(size: 10)
                                .foregroundColor(.orange.opacity(0.9))
                            Spacer()
                            Button(lang.t(reason == "iap_storage_unavailable" ? "iap_retry_purchase" : "reload_prices")) {
                                iap.retryPurchaseAvailability()
                            }
                            .adaptiveFont(size: 11, weight: .semibold)
                            .foregroundColor(.yanCyan)
                        }
                    }

                    if let selectedProduct = IAPProductID(rawValue: selectedProductId) {
                        PurchaseDisclosureView(productID: selectedProduct)
                            .padding(.vertical, 8)
                    }

                    // 购买与恢复按钮
                    if !iap.isLifetimeUser && (!isProUnlocked || selectedProductId == IAPProductID.proLifetime.rawValue) {
                        Button(action: {
                            iap.purchase(productId: selectedProductId)
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "applelogo")
                                Text(lang.t("pay_securely"))
                                Spacer()
                            }
                            .adaptiveFont(size: 13, weight: .bold)
                            .padding(.vertical, 10)
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
                        .buttonStyle(.plain)
                        .disabled(iap.isProcessingPurchase || iap.isLoadingProducts || !selectedProductIsAvailable)
                    }

                    RestorePurchasesButton(presentsResult: false)
                        .padding(.top, 2)
                }
                .padding(.vertical, 4)
            }

            // 2. VIP 尊享特权矩阵
            if let selectedProduct = IAPProductID(rawValue: selectedProductId), selectedProduct.includesAllFeatures {
                Section(header: Text(lang.t("vip_privilege_header"))) {
                    privilegeRow(icon: "person.2.fill", title: lang.t("fra_title"))
                    privilegeRow(icon: "sparkles", title: lang.t("privilege_qimen_title"))
                    privilegeRow(icon: "calendar.badge.clock", title: lang.t("privilege_purplewhite_title"))
                    privilegeRow(icon: "house.fill", title: lang.t("privilege_floorplan_title"))
                    privilegeRow(icon: "scroll.fill", title: lang.t("privilege_tianji_title"))
                    privilegeRow(icon: "camera.viewfinder", title: lang.t("ar_title"))
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .frame(maxWidth: horizontalSizeClass == .regular ? 900 : 700)
        .frame(maxWidth: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitle(lang.t("settings_menu_vip"), displayMode: .inline)
        .preferredColorScheme(.dark)
        .onAppear { iap.refreshProductsIfNeeded() }
    }

    private func productRow(id: IAPProductID, tag: String) -> some View {
        let isSelected = selectedProductId == id.rawValue

        return Button(action: {
            selectedProductId = id.rawValue
        }) {
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(id.title)
                            .adaptiveFont(size: 13, weight: .bold)
                            .foregroundColor(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : .white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(tag)
                            .adaptiveFont(size: 9, weight: .bold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(Color.yellow.opacity(0.25))
                            .foregroundColor(Color.yellow)
                            .cornerRadius(3)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    Text(id.desc)
                        .adaptiveFont(size: 11)
                        .foregroundColor(.white.opacity(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(iap.localizedBillingPrice(for: id))
                    .adaptiveFont(size: 15, weight: .bold, design: .monospaced)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(isSelected ? Color(red: 0.22, green: 0.19, blue: 0.12) : Color(red: 0.12, green: 0.13, blue: 0.17))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.12), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func privilegeRow(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .adaptiveFont(size: 13)
                .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                .frame(width: 20)
            Text(title)
                .adaptiveFont(size: 12)
                .foregroundColor(.white.opacity(0.85))
            Spacer()
            Text(lang.t("vip_short"))
                .adaptiveFont(size: 9, weight: .bold)
                .foregroundColor(.yellow)
        }
    }
}
