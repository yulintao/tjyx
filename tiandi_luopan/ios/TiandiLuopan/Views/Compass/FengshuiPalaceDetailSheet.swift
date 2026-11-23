import SwiftUI

// MARK: - 居家风水八方详勘与空间布局全鉴弹窗 (Fengshui Palace Detail Sheet)

public struct FengshuiPalaceDetailSheet: View {
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    
    private var palaces: [(gua: String, dir: String, elem: String, member: String, body: String, bestRoom: String, taboo: String, desc: String)] {
        let l = LocalizationManager.shared
        return [
            (l.t("gua_qian"), l.t("dir_nw"), l.t("elem_metal"), l.t("member_father"), l.t("body_head"), l.t("best_room_qian"), l.t("taboo_qian"), l.t("desc_qian")),
            (l.t("gua_kan"), l.t("dir_n"), l.t("elem_water"), l.t("member_middle_son"), l.t("body_kidney"), l.t("best_room_kan"), l.t("taboo_kan"), l.t("desc_kan")),
            (l.t("gua_gen"), l.t("dir_ne"), l.t("elem_earth"), l.t("member_youngest_son"), l.t("body_spleen"), l.t("best_room_gen"), l.t("taboo_gen"), l.t("desc_gen")),
            (l.t("gua_zhen"), l.t("dir_e"), l.t("elem_wood"), l.t("member_eldest_son"), l.t("body_liver"), l.t("best_room_zhen"), l.t("taboo_zhen"), l.t("desc_zhen")),
            (l.t("gua_xun"), l.t("dir_se"), l.t("elem_wood"), l.t("member_eldest_daughter"), l.t("body_nerve"), l.t("best_room_xun"), l.t("taboo_xun"), l.t("desc_xun")),
            (l.t("gua_li"), l.t("dir_s"), l.t("elem_fire"), l.t("member_middle_daughter"), l.t("body_heart"), l.t("best_room_li"), l.t("taboo_li"), l.t("desc_li")),
            (l.t("gua_kun"), l.t("dir_sw"), l.t("elem_earth"), l.t("member_mother"), l.t("body_belly"), l.t("best_room_kun"), l.t("taboo_kun"), l.t("desc_kun")),
            (l.t("gua_dui"), l.t("dir_w"), l.t("elem_metal"), l.t("member_youngest_daughter"), l.t("body_mouth"), l.t("best_room_dui"), l.t("taboo_dui"), l.t("desc_dui"))
        ]
    }
    
    public var body: some View {
        let activePalaceName = motion.headingState.facingMountain.localizedPalace
        let isEn = (lang.effectiveLanguage == .en)
        return NavigationView {
            ScrollViewReader { proxy in
                VStack(spacing: 0) {
                    // 顶部八宫一键定位条（当前朝向宫位高亮）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(0..<palaces.count, id: \.self) { idx in
                                let p = palaces[idx]
                                let isCurrent = (p.gua == activePalaceName)
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        proxy.scrollTo(idx, anchor: .top)
                                    }
                                }) {
                                    HStack(spacing: 3) {
                                        if isCurrent {
                                            Circle().fill(Color.yanGold).frame(width: 5, height: 5)
                                        }
                                        Text("\(p.gua) · \(p.dir)")
                                            .adaptiveFont(size: 11, weight: isCurrent ? .bold : .medium)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isCurrent ? Color.yanGold.opacity(0.24) : Color.white.opacity(0.08))
                                    .foregroundColor(isCurrent ? .yanGold : .white.opacity(0.85))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(isCurrent ? Color.yanGold.opacity(0.65) : Color.clear, lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                    .background(Color(red: 0.086, green: 0.075, blue: 0.059))

                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(0..<palaces.count, id: \.self) { idx in
                                let p = palaces[idx]
                                let isCurrent = (p.gua == activePalaceName)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        HStack(spacing: 6) {
                                            Text("【\(p.gua)\(lang.t("gua_suffix")) · \(p.dir)】")
                                                .adaptiveFont(size: 16, weight: .bold, design: .serif)
                                                .foregroundColor(Color.yanGold)
                                            Text(p.elem)
                                                .adaptiveFont(size: 10, weight: .bold)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.12))
                                                .foregroundColor(.white)
                                                .cornerRadius(4)
                                            if isCurrent {
                                                Text(isEn ? "Facing" : "当前朝向")
                                                    .adaptiveFont(size: 9.5, weight: .bold)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.yanCyan.opacity(0.22))
                                                    .foregroundColor(.yanCyan)
                                                    .cornerRadius(4)
                                            }
                                        }
                                        Spacer()
                                        Text("\(lang.t("family_member_corresp"))\(p.member)")
                                            .adaptiveFont(size: 11)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    
                                    Text(p.desc)
                                        .adaptiveFont(size: 12)
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineSpacing(3)
                                    
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(lang.t("suitable_spaces"))
                                                .adaptiveFont(size: 11, weight: .bold)
                                                .foregroundColor(.semJi)
                                            Text(p.bestRoom)
                                                .adaptiveFont(size: 11)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(lang.t("forbidden_layouts"))
                                                .adaptiveFont(size: 11, weight: .bold)
                                                .foregroundColor(.semXiong)
                                            Text(p.taboo)
                                                .adaptiveFont(size: 11)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(9)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(7)
                                }
                                .id(idx)
                                .padding(12)
                                .background(Color.surfaceCard)
                                .cornerRadius(11)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 11)
                                        .stroke(isCurrent ? Color.yanGold.opacity(0.65) : Color.white.opacity(0.07), lineWidth: isCurrent ? 1.5 : 1)
                                )
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Color(red: 0.086, green: 0.075, blue: 0.059).ignoresSafeArea())
            .navigationBarTitle(lang.t("palace_sheet_title"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }
}
