import SwiftUI
import Foundation
import UIKit

// MARK: - 系统设置总览视图 (Settings Root View)

public struct SettingsView: View {
    public var isActive: Bool = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @ObservedObject var kuaProfile = UserKuaProfileManager.shared
    @ObservedObject var retention = RetentionServiceManager.shared

    /// 弹层状态与选中商品统一由 ViewModel 持有，视图不再各存一份。
    @StateObject private var viewModel = SettingsViewModel()

    private static let appearanceConfigured: Void = {
        UITableView.appearance().backgroundColor = UIColor(red: 18/255.0, green: 18/255.0, blue: 22/255.0, alpha: 1.0)
    }()

    public init(isActive: Bool = true) {
        self.isActive = isActive
        _ = Self.appearanceConfigured
    }

    public var body: some View {
        Group {
            if isActive {
                NavigationView {
                    List {
                        // 顶部用户/会员概要卡片
                        userHeaderSection

                        // 4 大功能模块菜单组
                        Section {
                            // 收费暂停：会员中心入口先撤下，功能全部开放；定价定案后再恢复。

                            // 模块 2: 宅主命卦与节气提醒
                            NavigationLink(destination: OwnerKuaReminderPageView()) {
                                menuRow(
                                    icon: "person.crop.circle.badge.checkmark",
                                    iconColor: Color.yanCyan,
                                    title: lang.t("settings_menu_kua_reminder"),
                                    subtitle: kuaProfileSubtitle
                                )
                            }

                            NavigationLink(destination: PersonalProfileDataView()) {
                                menuRow(icon: "person.crop.circle.badge.minus", iconColor: Color.yanCyan,
                                        title: lang.t("profile_data_title"))
                            }

                            // 模块 3: 界面语言设置
                            NavigationLink(destination: LanguagePreferencesPageView()) {
                                menuRow(
                                    icon: "globe",
                                    iconColor: Color(red: 0.35, green: 0.65, blue: 0.95),
                                    title: lang.t("settings_menu_language"),
                                    subtitle: lang.currentSetting.displayName
                                )
                            }

                            // 模块 4: 关于
                            NavigationLink(destination: AboutPageView()) {
                                menuRow(
                                    icon: "info.circle.fill",
                                    iconColor: Color.orange,
                                    title: lang.t("settings_menu_about"),
                                    subtitle: "v" + lang.t("settings_version_value")
                                )
                            }
                        }
                    }
                    .listStyle(InsetGroupedListStyle())
                    .frame(maxWidth: horizontalSizeClass == .regular ? 900 : 700)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.ignoresSafeArea())
                    .navigationBarTitle(lang.t("tab_settings"), displayMode: .inline)
                    .preferredColorScheme(.dark)
                    .onAppear {
                        guard isActive else { return }
                        viewModel.activate(iap: iap)
                    }
                    .onReceive(iap.$lastErrorMessage) { message in
                        guard isActive else { return }
                        viewModel.handlePurchaseMessage(message, isError: true, iap: iap)
                    }
                    .onReceive(iap.$lastStatusMessage) { message in
                        guard isActive else { return }
                        viewModel.handlePurchaseMessage(message, isError: false, iap: iap)
                    }
                }
                .navigationViewStyle(StackNavigationViewStyle())
                .preferredColorScheme(.dark)
            } else {
                Color.clear.ignoresSafeArea()
            }
        }
        .overlay(
            Group {
                if let alert = viewModel.alert {
                    FloorplanConfirmDialog(
                        title: alert.isError ? lang.t("payment_failed_title") : lang.t("payment_status_title"),
                        message: alert.message,
                        confirmTitle: lang.t("done"),
                        cancelTitle: nil,
                        confirmColor: Color(red: 0.83, green: 0.68, blue: 0.21),
                        onConfirm: { viewModel.dismissAlert() },
                        onCancel: { viewModel.dismissAlert() }
                    )
                } else if retention.showNotificationPermissionDeniedAlert {
                    FloorplanConfirmDialog(
                        title: SettingsLocalizationHelpers.notificationPermissionDeniedTitle(lang),
                        message: SettingsLocalizationHelpers.notificationPermissionDeniedMessage(lang),
                        confirmTitle: SettingsLocalizationHelpers.goToSettingsTitle(lang),
                        cancelTitle: lang.t("cancel"),
                        confirmColor: Color.yanCyan,
                        onConfirm: {
                            retention.showNotificationPermissionDeniedAlert = false
                            retention.openSystemNotificationSettings()
                        },
                        onCancel: {
                            retention.showNotificationPermissionDeniedAlert = false
                        }
                    )
                }
            }
        )
    }

    private var userHeaderSection: some View {
        Section {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.25, green: 0.26, blue: 0.3), Color(red: 0.15, green: 0.16, blue: 0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    Image(systemName: "person.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(userHeaderSubtitle)
                        .adaptiveFont(size: 11)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    private var userHeaderSubtitle: String {
        switch lang.effectiveLanguage {
        case .zhHans: return "天机演象 · 专业风水罗盘与玄空理气"
        case .zhHant: return "天機演象 · 專業風水羅盤與玄空理氣"
        case .en: return "Tiandi Luopan · Professional Feng Shui Compass"
        case .ja: return "天地羅盤 · プロ向け風水羅盤と玄空理気"
        case .ko: return "천지나침반 · 전문 풍수 나침반 및 현공이기"
        case .vi: return "Thiên Địa La Bàn · Huyền Không Phong Thủy"
        case .th: return "เข็มทิศฟ้าดิน · เข็มทิศฮวงจุ้ยมืออาชีพ"
        case .id: return "Tiandi Luopan · Kompas Feng Shui Profesional"
        default: return "天机演象 · 专业风水罗盘与玄空理气"
        }
    }

    private var kuaProfileSubtitle: String {
        if kuaProfile.canUsePersonalAnalysis {
            return "\(kuaProfile.birthYear) · \(kuaProfile.localizedLifeKuaName(language: lang.effectiveLanguage))"
        } else {
            return ""
        }
    }

    private func menuRow(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        badgeColor: Color? = nil
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(iconColor)
            }

            Text(title)
                .adaptiveFont(size: 15, weight: .medium)
                .foregroundColor(.white)

            Spacer()

            if let badge = badge {
                Text(badge)
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background((badgeColor ?? .yellow).opacity(0.25))
                    .foregroundColor(badgeColor ?? .yellow)
                    .cornerRadius(6)
            } else if let subtitle = subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .adaptiveFont(size: 13)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 3)
    }
}
