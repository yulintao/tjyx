import SwiftUI
import Foundation
import UIKit

// MARK: - 功能页 4: 关于 (About Page)

public struct AboutPageView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showTestFlightRateTip: Bool = false
    @State private var legalDocument: LegalDocument? = nil

    public init() {}

    public var body: some View {
        List {
            // 1. 版本信息与应用标识
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "compass.drawing")
                        .font(.system(size: 42))
                        .foregroundColor(Color.yanGoldSoft)
                    Text(appNameTitle)
                        .adaptiveFont(size: 16, weight: .bold)
                        .foregroundColor(.white)
                    Text(lang.t("settings_app_version") + " " + lang.t("settings_version_value"))
                        .adaptiveFont(size: 12)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }

            Section(header: Text(lang.t("about_documents_purchases"))) {
                Link(destination: LegalLinks.privacyPolicy) {
                    Label(lang.t("legal_privacy_button"), systemImage: "hand.raised.fill")
                }
                Link(destination: LegalLinks.termsOfUse) {
                    Label(lang.t("about_terms"), systemImage: "doc.text")
                }
                Link(destination: LegalLinks.support) {
                    Label(lang.t("about_contact"), systemImage: "envelope")
                }
            }
            .foregroundColor(Color.yanCyan)

            // 2. 评分反馈
            Section {
                Button(action: {
                    handleRateAppTap()
                }) {
                    HStack {
                        Label(SettingsLocalizationHelpers.rateAppTitle(lang), systemImage: "star.bubble.fill")
                            .foregroundColor(Color.yanGoldSoft)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .adaptiveFont(size: 11)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // 3. 理论基础与安全警示
            Section(header: Text(lang.t("settings_theory_base"))) {
                HStack {
                    Text(lang.t("settings_theory_base"))
                    Spacer()
                    Text(lang.t("settings_theory_desc"))
                        .foregroundColor(.secondary)
                        .adaptiveFont(size: 12)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Label(lang.t("settings_safety_title"), systemImage: "exclamationmark.shield.fill")
                        .adaptiveFont(size: 13, weight: .semibold)
                        .foregroundColor(.orange)
                    Text(lang.t("settings_safety_disclaimer"))
                        .adaptiveFont(size: 11)
                        .foregroundColor(.secondary)
                        .lineSpacing(3)
                }
                .padding(.vertical, 2)
            }

            // 4. 合规与安全说明
            Section(header: Text(legalSectionTitle)) {
                Button {
                    legalDocument = .compliance
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.shield.fill")
                        Text(lang.t("legal_compliance_button"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .adaptiveFont(size: 10, weight: .semibold)
                    }
                }
                .adaptiveFont(size: 12, weight: .semibold)
                .foregroundColor(.orange)
            }
        }
        .listStyle(InsetGroupedListStyle())
        .frame(maxWidth: horizontalSizeClass == .regular ? 900 : 700)
        .frame(maxWidth: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitle(lang.t("settings_menu_about"), displayMode: .inline)
        .preferredColorScheme(.dark)
        .sheet(item: $legalDocument) { document in
            LegalDocumentSheet(
                title: lang.t(document.titleKey),
                bodyText: lang.t(document.bodyKey)
            )
        }
        .overlay(
            Group {
                if showTestFlightRateTip {
                    FloorplanConfirmDialog(
                        title: SettingsLocalizationHelpers.testFlightRateAlertTitle(lang),
                        message: SettingsLocalizationHelpers.testFlightRateAlertMessage(lang),
                        confirmTitle: lang.t("done"),
                        cancelTitle: nil,
                        confirmColor: Color.yanGoldDeep,
                        onConfirm: { showTestFlightRateTip = false },
                        onCancel: { showTestFlightRateTip = false }
                    )
                }
            }
        )
    }

    private var appNameTitle: String {
        switch lang.effectiveLanguage {
        case .zhHans: return "天机演象 · 天地罗盘"
        case .zhHant: return "天機演象 · 天地羅盤"
        case .en: return "Tiandi Luopan"
        case .ja: return "天地羅盤"
        case .ko: return "천지나침반"
        case .vi: return "Thiên Địa La Bàn"
        case .th: return "เข็มทิศฟ้าดิน"
        case .id: return "Tiandi Luopan"
        default: return "天机演象 · 天地罗盘"
        }
    }

    private var legalSectionTitle: String {
        switch lang.effectiveLanguage {
        case .zhHans: return "条款与合规"
        case .zhHant: return "條款與合規"
        case .en: return "Terms & Compliance"
        case .ja: return "利用規約とコンプライアンス"
        case .ko: return "이용약관 및 규정 준수"
        case .vi: return "Điều khoản & Tuân thủ"
        case .th: return "ข้อกำหนดและการปฏิบัติตามกฎระเบียบ"
        case .id: return "Ketentuan & Kepatuhan"
        default: return "条款与合规"
        }
    }

    private func handleRateAppTap() {
        if !LegalLinks.appStoreID.isEmpty,
           let url = URL(string: "https://apps.apple.com/app/id\(LegalLinks.appStoreID)?action=write-review"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
            return
        }

        if RetentionServiceManager.isTestFlightOrDebug {
            showTestFlightRateTip = true
        }
        RetentionServiceManager.shared.requestImmediateReview()
    }
}
