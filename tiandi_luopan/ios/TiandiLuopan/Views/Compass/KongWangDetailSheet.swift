import SwiftUI

// MARK: - 空亡与兼向全景诊断弹窗 (KongWang Detail Sheet - PRD 6.1)

public struct KongWangDetailSheet: View {
    public let heading: Double
    @ObservedObject private var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        // The heading passed by CompassMainView is the opening snapshot. Read
        // the live manager here so an open diagnosis follows subsequent
        // compass movement instead of showing stale void-boundary data.
        let currentHeading = motion.headingState.facingAngle
        let m = Mountain24Data.shared.mountain(for: currentHeading)
        let rawDelta = abs(currentHeading - m.centerAngle)
        let delta = min(rawDelta, 360.0 - rawDelta)
        let kwLevel = motion.headingState.kongWangLevel
        let kwStatusText: String
        let kwGradeText: String
        let kwColor: Color
        let kwDesc: String
        let kwRemedyText: String
        
        switch kwLevel {
        case .largeVoid:
            kwStatusText = lang.t("kw_large_title")
            kwGradeText = lang.t("kw_large_grade")
            kwColor = .semXiong
            kwDesc = lang.t("kw_large_desc")
            kwRemedyText = lang.t("kw_large_remedy")
        case .smallVoid:
            kwStatusText = lang.t("kw_small_title")
            kwGradeText = lang.t("kw_small_grade")
            kwColor = .semWarn
            kwDesc = lang.t("kw_small_desc")
            kwRemedyText = lang.t("kw_small_remedy")
        case .jianXiang:
            kwStatusText = lang.t("kw_sub_title")
            kwGradeText = lang.t("kw_sub_grade")
            kwColor = .yellow
            kwDesc = lang.t("kw_sub_desc")
            kwRemedyText = lang.t("kw_sub_remedy")
        case .pure:
            kwStatusText = lang.t("kw_pure_title")
            kwGradeText = lang.t("kw_pure_grade")
            kwColor = .semJi
            kwDesc = lang.t("kw_pure_desc")
            kwRemedyText = lang.t("kw_pure_remedy")
        }
        
        let isEn = (lang.effectiveLanguage == .en)
        let clampedProgress = min(max(delta / 7.5, 0.0), 1.0)

        return NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 状态头卡 + 偏离度可视化标尺
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(kwStatusText)
                                    .adaptiveFont(size: 20, weight: .bold)
                                    .foregroundColor(kwColor)
                                Text("\(lang.t("kw_heading_prefix")): \(String(format: "%.1f", currentHeading))° · \(m.localizedName) (\(lang.t("kw_center_prefix")) \(String(format: "%.1f", m.centerAngle))° \(lang.t("kw_deviation_prefix")) \(String(format: "%.1f", delta))°)")
                                    .adaptiveFont(size: 12, design: .monospaced)
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                            }
                            Spacer()
                            Text(kwGradeText)
                                .adaptiveFont(size: 12, weight: .bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(kwColor.opacity(0.2))
                                .foregroundColor(kwColor)
                                .cornerRadius(7)
                        }

                        // 0° ~ 7.5° 山向中心偏离标尺
                        VStack(alignment: .leading, spacing: 5) {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 8)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(kwColor)
                                        .frame(width: max(8, geo.size.width * CGFloat(clampedProgress)), height: 8)
                                }
                            }
                            .frame(height: 8)
                            HStack {
                                Text("0° \(isEn ? "Center" : "正中")")
                                Spacer()
                                Text("1.5° \(isEn ? "Sub" : "兼向")")
                                Spacer()
                                Text("6.5° \(isEn ? "Void" : "空亡")")
                                Spacer()
                                Text("7.5°")
                            }
                            .adaptiveFont(size: 9.5, design: .monospaced)
                            .foregroundColor(.white.opacity(0.55))
                        }

                        if delta > 0.3 {
                            Button(action: {
                                motion.lockAtFacingAngle(m.centerAngle)
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "scope")
                                    Text(isEn
                                         ? String(format: "Lock to Center %.1f° (%@)", m.centerAngle, m.localizedName)
                                         : String(format: "一键锁至本山正中 %.1f°（%@）", m.centerAngle, m.localizedName))
                                }
                                .adaptiveFont(size: 11.5, weight: .bold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 9)
                                .background(Color.yanCyan.opacity(0.18))
                                .foregroundColor(.yanCyan)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(14)
                    .background(Color.surfaceCard)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(kwColor.opacity(0.35), lineWidth: 1)
                    )
                    
                    // 诊断解析
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lang.t("kw_principle_section"))
                            .adaptiveFont(size: 14, weight: .bold)
                            .foregroundColor(.yanGold)
                        Text(kwDesc)
                            .adaptiveFont(size: 13)
                            .lineSpacing(4)
                            .foregroundColor(.white.opacity(0.88))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.surfaceElevated)
                    .cornerRadius(12)
                    
                    // 地师调理
                    VStack(alignment: .leading, spacing: 8) {
                        Label(lang.t("kw_master_remedy_section"), systemImage: "lightbulb.fill")
                            .adaptiveFont(size: 14, weight: .bold)
                            .foregroundColor(.yanGold)
                        Text(kwRemedyText)
                            .adaptiveFont(size: 13)
                            .lineSpacing(4)
                            .foregroundColor(.white.opacity(0.88))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yanGold.opacity(0.09))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yanGold.opacity(0.28), lineWidth: 1)
                    )
                }
                .padding(16)
            }
            .background(Color(red: 0.086, green: 0.075, blue: 0.059).ignoresSafeArea())
            .navigationBarTitle(lang.t("kw_sheet_title"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }
}
