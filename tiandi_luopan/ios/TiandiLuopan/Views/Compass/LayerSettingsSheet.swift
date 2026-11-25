import SwiftUI

// MARK: - 罗盘圈层图层配置与预设选择弹窗 (Layer Settings Sheet)

public struct LayerSettingsSheet: View {
    @ObservedObject var layers = CompassLayerManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        let isEn = (lang.effectiveLanguage == .en)
        return NavigationView {
            List {
                // 流派预设一键切换
                Section(header: Text(lang.t("preset_section_title"))) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CompassPreset.allCases) { preset in
                                let isSelected = (layers.activePreset == preset)
                                Button(action: {
                                    layers.applyPreset(preset)
                                }) {
                                    HStack(spacing: 5) {
                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 11, weight: .bold))
                                        }
                                        Text(preset.localizedTitle)
                                            .adaptiveFont(size: 12.5, weight: isSelected ? .bold : .medium)
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: DS.touchMin)
                                    .background(isSelected ? Color.yanGold : Color.white.opacity(0.08))
                                    .foregroundColor(isSelected ? .black : .white)
                                    .cornerRadius(9)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // 圈层开关自定义（含一键全开/精简测绘快捷操作）
                Section(header: HStack {
                    Text(lang.t("layers_custom_section"))
                    Spacer()
                    Button(isEn ? "Minimal" : "精简测量") {
                        layers.showDegreeTicks = true
                        layers.showMountain24 = true
                        layers.showEightGua = true
                        layers.showSolarTerms = false
                        layers.showHexagrams64 = false
                        layers.showFenjin120 = false
                    }
                    .adaptiveFont(size: 10.5, weight: .semibold)
                    .frame(minHeight: DS.touchMin)
                    .foregroundColor(.yanCyan)
                    Text("·").foregroundColor(.secondary)
                    Button(isEn ? "All On" : "全开") {
                        layers.showDegreeTicks = true
                        layers.showSolarTerms = true
                        layers.showHexagrams64 = true
                        layers.showFenjin120 = true
                        layers.showMountain24 = true
                        layers.showEightGua = true
                    }
                    .adaptiveFont(size: 10.5, weight: .semibold)
                    .frame(minHeight: DS.touchMin)
                    .foregroundColor(.yanGold)
                }) {
                    Toggle(lang.t("layer_degree_ticks"), isOn: $layers.showDegreeTicks)
                    Toggle(lang.t("layer_solar_terms"), isOn: $layers.showSolarTerms)
                    Toggle(lang.t("layer_hexagrams64"), isOn: $layers.showHexagrams64)
                    Toggle(lang.t("layer_fenjin120"), isOn: $layers.showFenjin120)
                    Toggle(lang.t("layer_mountain24"), isOn: $layers.showMountain24)
                    Toggle(lang.t("layer_eight_gua"), isOn: $layers.showEightGua)
                }
                .tint(Color.yanGold)
                
                // 天池仪器与指针（移除财神/喜神金标，保持专业测量仪表纯净）
                Section(header: Text(lang.t("tianchi_section"))) {
                    Toggle(lang.t("layer_true_north"), isOn: $layers.showTrueNorthNeedle)
                    Toggle(lang.t("layer_level_bubble"), isOn: $layers.showLevelBubble)
                }
                .tint(Color.yanCyan)
            }
            .listStyle(InsetGroupedListStyle())
            .navigationBarTitle(lang.t("layers_settings"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.light)
        .onAppear {
            layers.showDailyGodMarkers = false
        }
    }
}
