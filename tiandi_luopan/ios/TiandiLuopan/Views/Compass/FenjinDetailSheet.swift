import SwiftUI

// MARK: - 一百二十分金定位与方位参考详解弹窗 (Fenjin Detail Sheet)

public struct FenjinDetailSheet: View {
    public let fenjin: FenjinItem
    @ObservedObject private var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        // Keep the detail card live while the user rotates the compass. The
        // value passed when presenting the sheet is only the initial snapshot.
        let currentHeading = motion.headingState.facingAngle
        let currentFenjin = Fenjin120Data.shared.resolveFenjin(for: currentHeading)
        let isEn = (lang.effectiveLanguage == .en)
        let accent: Color = currentFenjin.isAuspicious ? .green : .red
        let rawSlotOffset = (currentHeading - currentFenjin.startAngle + 360.0).truncatingRemainder(dividingBy: 360.0)
        let slotProgress = min(max(rawSlotOffset / 3.0, 0.0), 1.0)

        return NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // 分金头卡 + 3° 刻度定位条
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                let belongPrefix = lang.t("fenjin_mountain_belong")
                                let belongSep = (belongPrefix.hasSuffix(":") || belongPrefix.hasSuffix("：")) ? " " : "："
                                Text("【\(currentFenjin.localizedJiaziName)】\(lang.t("fenjin_title_suffix"))")
                                    .adaptiveFont(size: 24, weight: .bold, design: .serif)
                                    .foregroundColor(Color.yanGold)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.65)
                                Text("\(belongPrefix)\(belongSep)\(currentFenjin.localizedMountainName) · \(lang.t("fenjin_index_prefix"))\(currentFenjin.index)\(lang.t("fenjin_title_suffix"))")
                                    .adaptiveFont(size: 12)
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.75)
                            }
                            Spacer()
                            Text(currentFenjin.localizedGrade)
                                .adaptiveFont(size: 12, weight: .bold)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(accent.opacity(0.2))
                                .foregroundColor(accent)
                                .cornerRadius(7)
                        }

                        // 3.0° 区间进度可视化
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Text(lang.t("fenjin_range_section"))
                                    .adaptiveFont(size: 11, weight: .semibold)
                                    .foregroundColor(.white.opacity(0.72))
                                Spacer()
                                Text(String(format: "%.1f° / %.1f°", currentHeading, currentFenjin.centerAngle))
                                    .adaptiveFont(size: 11, weight: .bold, design: .monospaced)
                                    .foregroundColor(.yanCyan)
                            }
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.1))
                                        .frame(height: 8)
                                    Circle()
                                        .fill(Color.yanGold)
                                        .frame(width: 12, height: 12)
                                        .offset(x: max(0, min(geo.size.width - 12, geo.size.width * CGFloat(slotProgress) - 6)))
                                }
                            }
                            .frame(height: 12)
                            HStack {
                                Text(String(format: "%.1f°", currentFenjin.startAngle))
                                Spacer()
                                Text("\(lang.t("fenjin_center_deg")) \(String(format: "%.1f°", currentFenjin.centerAngle))")
                                    .foregroundColor(.yanGold)
                                Spacer()
                                Text(String(format: "%.1f°", currentFenjin.endAngle))
                            }
                            .adaptiveFont(size: 9.5, design: .monospaced)
                            .foregroundColor(.white.opacity(0.55))
                        }

                        Button(action: {
                            motion.lockAtFacingAngle(currentFenjin.centerAngle)
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: "scope")
                                Text(isEn
                                     ? String(format: "Lock to Fenjin Center %.1f°", currentFenjin.centerAngle)
                                     : String(format: "一键锁至该分金正中 %.1f°", currentFenjin.centerAngle))
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
                    .padding(14)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.16))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(accent.opacity(0.32), lineWidth: 1)
                    )
                    
                    // 孤虚旺相秘传断语
                    VStack(alignment: .leading, spacing: 8) {
                        Text(lang.t("fenjin_lore_section"))
                            .adaptiveFont(size: 14, weight: .bold)
                            .foregroundColor(.yanGold)
                        Text(currentFenjin.localizedLore)
                            .adaptiveFont(size: 13.5)
                            .lineSpacing(4)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.yanGold.opacity(0.09))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yanGold.opacity(0.28), lineWidth: 1)
                    )
                    
                    // 立向指引
                    VStack(alignment: .leading, spacing: 8) {
                        Label(lang.t("fenjin_guidance_section"), systemImage: "safari.fill")
                            .adaptiveFont(size: 14, weight: .bold)
                            .foregroundColor(.yanCyan)
                        Text(currentFenjin.isAuspicious ?
                             lang.t("fenjin_auspicious_advice") :
                             lang.t("fenjin_inauspicious_advice"))
                            .adaptiveFont(size: 13)
                            .foregroundColor(.white.opacity(0.82))
                            .lineSpacing(4)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.15))
                    .cornerRadius(12)
                }
                .padding(16)
            }
            .background(Color(red: 0.07, green: 0.07, blue: 0.09).ignoresSafeArea())
            .navigationBarTitle(lang.t("fenjin_detail_title"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }
}
