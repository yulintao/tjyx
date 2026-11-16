import SwiftUI
import Foundation
import UIKit

// MARK: - 功能页 2: 宅主命卦与节气提醒 (Owner Life Gua & Solar Terms Page)

public struct OwnerKuaReminderPageView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject private var iap = StoreKitIAPManager.shared
    @ObservedObject var kuaProfile = UserKuaProfileManager.shared
    @ObservedObject var retention = RetentionServiceManager.shared
    @ObservedObject var lang = LocalizationManager.shared

    public enum ActiveSheet: Identifiable {
        case editOwnerKua
        case addFamilyMember

        public var id: String {
            switch self {
            case .editOwnerKua: return "editOwnerKua"
            case .addFamilyMember: return "addFamilyMember"
            }
        }
    }

    @State private var activeSheet: ActiveSheet? = nil

    public init() {}

    public var body: some View {
        List {
            Section {
                NavigationLink(lang.t("profile_data_title"), destination: PersonalProfileDataView())
            }
            // 1. 宅主本命卦人宅配卦
            Section(header: Text(SettingsLocalizationHelpers.ownerBirthYearTitle(lang))) {
                Toggle(SettingsLocalizationHelpers.ownerProfileEnableTitle(lang), isOn: $kuaProfile.isProfileEnabled)

                if kuaProfile.isProfileEnabled {
                    HStack {
                        Text(SettingsLocalizationHelpers.ownerBirthYearTitle(lang))
                        Spacer()
                        Button(action: {
                            activeSheet = .editOwnerKua
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            HStack(spacing: 4) {
                                Text("\(kuaProfile.birthYear) · \(kuaProfile.localizedZodiac(language: lang.effectiveLanguage)) · \(kuaProfile.localizedLifeKuaName(language: lang.effectiveLanguage))")
                                    .adaptiveFont(size: 12, weight: .bold)
                                    .foregroundColor(Color.yanGoldSoft)
                                Image(systemName: "pencil.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.yanCyan)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    Picker(SettingsLocalizationHelpers.ownerGenderTitle(lang), selection: $kuaProfile.isMale) {
                        Text(SettingsLocalizationHelpers.maleLabel(lang)).tag(true)
                        Text(SettingsLocalizationHelpers.femaleLabel(lang)).tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    // 本命卦吉凶方位简卡（点击也可直接修改生辰）
                    Button(action: {
                        activeSheet = .editOwnerKua
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        kuaInfoCard
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }

            // 2. 全家成员命卦档案与智能分房 (Family Members Section)
            if kuaProfile.isProfileEnabled {
                Section(
                    header: HStack {
                        Text(SettingsLocalizationHelpers.familySectionTitle(lang, count: kuaProfile.familyMembers.count))
                        Spacer()
                        Button(action: {
                            activeSheet = .addFamilyMember
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            HStack(spacing: 3) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 11))
                                Text(SettingsLocalizationHelpers.addFamilyMemberButton(lang))
                                    .adaptiveFont(size: 11, weight: .bold)
                            }
                            .foregroundColor(.yanCyan)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                ) {
                    if kuaProfile.familyMembers.isEmpty {
                        Button(action: {
                            activeSheet = .addFamilyMember
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 22))
                                    .foregroundColor(.yanCyan)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(SettingsLocalizationHelpers.emptyFamilyTitle(lang))
                                        .adaptiveFont(size: 13, weight: .bold)
                                        .foregroundColor(.white)
                                    Text(SettingsLocalizationHelpers.emptyFamilySubtitle(lang))
                                        .adaptiveFont(size: 11)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                    } else {
                        ForEach(kuaProfile.familyMembers) { member in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(member.displayName)
                                        .adaptiveFont(size: 13, weight: .bold)
                                        .foregroundColor(.white)
                                    Text("【\(member.localizedGuaBadge)】")
                                        .adaptiveFont(size: 11, weight: .bold)
                                        .foregroundColor(Color.yanGoldSoft)
                                    Spacer()

                                    // 出生年份微调菜单
                                    Menu {
                                        ForEach((1920...2026).reversed(), id: \.self) { yr in
                                            Button(action: {
                                                kuaProfile.updateFamilyMember(id: member.id, birthYear: yr)
                                            }) {
                                                HStack {
                                                    Text("\(String(yr))年")
                                                    if yr == member.birthYear {
                                                        Image(systemName: "checkmark")
                                                    }
                                                }
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 2) {
                                            Text(member.formattedBirth)
                                                .adaptiveFont(size: 11, weight: .semibold)
                                            Image(systemName: "chevron.down")
                                                .font(.system(size: 8, weight: .bold))
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.white.opacity(0.08))
                                        .foregroundColor(.white)
                                        .cornerRadius(5)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    // 性别切换
                                    Button(action: {
                                        kuaProfile.updateFamilyMember(id: member.id, isMale: !member.isMale)
                                    }) {
                                        Text(member.isMale ? SettingsLocalizationHelpers.maleLabel(lang) : SettingsLocalizationHelpers.femaleLabel(lang))
                                            .adaptiveFont(size: 11, weight: .bold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.yanCyan.opacity(0.18))
                                            .foregroundColor(.yanCyan)
                                            .cornerRadius(5)
                                    }
                                    .buttonStyle(PlainButtonStyle())

                                    // 删除按钮
                                    Button(action: {
                                        withAnimation {
                                            kuaProfile.removeFamilyMember(id: member.id)
                                        }
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                    }) {
                                        Image(systemName: "trash.circle.fill")
                                            .font(.system(size: 15))
                                            .foregroundColor(.white.opacity(0.45))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }

                                Text(member.personalWealthAndStudySummary)
                                    .adaptiveFont(size: 11)
                                    .foregroundColor(.white.opacity(0.75))
                            }
                            .padding(.vertical, 4)
                        }

                        // 底部“+ 添加家庭成员”按钮行
                        Button(action: {
                            activeSheet = .addFamilyMember
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            HStack {
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12, weight: .bold))
                                Text(SettingsLocalizationHelpers.addFamilyMemberButton(lang))
                                    .adaptiveFont(size: 13, weight: .bold)
                                Spacer()
                            }
                            .foregroundColor(.yanCyan)
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }

            } else {
                Section { OwnerGuaVIPGate { EmptyView() } }

            // 3. 二十四节气交节与九星换月提醒
            Section(
                header: Text(SettingsLocalizationHelpers.solarTermNotifyTitle(lang)),
                footer: Text(SettingsLocalizationHelpers.solarTermNotifyDesc(lang))
                    .adaptiveFont(size: 11)
                    .foregroundColor(.secondary)
            ) {
                Toggle(SettingsLocalizationHelpers.solarTermNotifyTitle(lang), isOn: Binding(
                    get: { retention.solarTermNotificationsEnabled },
                    set: { retention.setSolarTermNotifications(enabled: $0) }
                ))
            }
        }
        .listStyle(InsetGroupedListStyle())
        .frame(maxWidth: horizontalSizeClass == .regular ? 900 : 700)
        .frame(maxWidth: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitle(lang.t("settings_menu_kua_reminder"), displayMode: .inline)
        .preferredColorScheme(.dark)
        .sheet(item: $activeSheet) { sheet in
            OwnerGuaVIPGate {
            switch sheet {
            case .editOwnerKua:
                EditOwnerKuaDialog(
                    isPresented: Binding(
                        get: { activeSheet == .editOwnerKua },
                        set: { if !$0 { activeSheet = nil } }
                    ),
                    sittingPalace: "坎",
                    onSaved: {}
                )
            case .addFamilyMember:
                AddFamilyMemberDialog(
                    isPresented: Binding(
                        get: { activeSheet == .addFamilyMember },
                        set: { if !$0 { activeSheet = nil } }
                    ),
                    ownerBirthYear: kuaProfile.birthYear,
                    ownerIsMale: kuaProfile.isMale,
                    onConfirm: { role, customName, birthDate, year, isMale in
                        kuaProfile.addFamilyMember(role: role, customName: customName, birthDate: birthDate, birthYear: year, isMale: isMale)
                        activeSheet = nil
                    }
                )
            }
            }
        }
    }

    private var kuaInfoCard: some View {
        let compat = kuaProfile.evaluateCompatibility(sittingPalace: "坎")

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.text.rectangle.fill")
                    .foregroundColor(Color.yanGoldSoft)
                Text(compat.localizedOwnerGuaName)
                    .adaptiveFont(size: 14, weight: .bold)
                    .foregroundColor(.white)
                Spacer()
                Text(compat.localizedLifeGroup)
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.yanCyan.opacity(0.2))
                    .foregroundColor(Color.yanCyan)
                    .cornerRadius(5)
            }

            Divider().background(Color.white.opacity(0.12))

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(lang.effectiveLanguage == .en ? "Auspicious Directions" : "四大吉方")
                        .adaptiveFont(size: 10, weight: .semibold)
                        .foregroundColor(.green.opacity(0.9))
                    Text("生气 · 延年 · 天医 · 伏位")
                        .adaptiveFont(size: 11)
                        .foregroundColor(.white.opacity(0.85))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text(lang.effectiveLanguage == .en ? "Inauspicious Directions" : "四大凶方")
                        .adaptiveFont(size: 10, weight: .semibold)
                        .foregroundColor(.red.opacity(0.9))
                    Text("绝命 · 五鬼 · 六煞 · 祸害")
                        .adaptiveFont(size: 11)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .padding(10)
        .background(Color(red: 0.12, green: 0.13, blue: 0.17))
        .cornerRadius(8)
    }
}
