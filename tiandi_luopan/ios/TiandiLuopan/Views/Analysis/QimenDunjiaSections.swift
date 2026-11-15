import SwiftUI

/// 九宫中的单格（八神/九星、八门、宫名与天地三奇六仪）。
/// 独立成视图后，九宫刷新只重建单元格，不再连带整页。
struct QimenPalaceCellView: View {
    let cell: QimenPalaceCell
    var isSelected: Bool = false
    var isRoomy: Bool = false

    var body: some View {
        let isJi = cell.isDoorAuspicious
        let isXiong = cell.isDoorInauspicious
        let borderColor = isSelected
            ? Color.yanCyan
            : (isJi ? Color.green.opacity(0.5) : (isXiong ? Color.red.opacity(0.4) : Color.white.opacity(0.12)))
        let bgColor = isJi
            ? Color.green.opacity(0.08)
            : (isXiong ? Color.red.opacity(0.06) : Color(red: 0.12, green: 0.13, blue: 0.18))

        VStack {
            HStack {
                Text(cell.localizedGodName)
                    .adaptiveFont(size: 9, weight: .bold)
                    .foregroundColor(Color.yellow)
                Spacer()
                Text(cell.localizedStarName)
                    .adaptiveFont(size: 9)
                    .foregroundColor(Color.yanCyan)
            }

            Spacer(minLength: 2)

            Text(cell.localizedDoorName)
                .adaptiveFont(size: 15, weight: .bold, design: .serif)
                .foregroundColor(isJi ? Color.green : (isXiong ? Color.red : Color(red: 0.95, green: 0.85, blue: 0.45)))

            Spacer(minLength: 2)

            HStack {
                Text(cell.localizedPalaceName)
                    .adaptiveFont(size: 8)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(cell.localizedTianStem)/\(cell.localizedDiStem)")
                    .adaptiveFont(size: 9, weight: .bold, design: .monospaced)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            }
        }
        .padding(isRoomy ? 10 : 6)
        .aspectRatio(1.0, contentMode: .fit)
        .background(bgColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
}

/// 一事一断的场景横滑选择条。
struct QimenScenarioSelectorBar: View {
    let selected: QimenScenarioType
    let onSelect: (QimenScenarioType) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(QimenScenarioType.allCases) { item in
                    let isSelected = selected == item
                    Button(action: { onSelect(item) }) {
                        HStack(spacing: 4) {
                            Image(systemName: item.iconName)
                                .adaptiveFont(size: 10)
                            Text(item.localizedTitle)
                                .adaptiveFont(size: 10, weight: .bold)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(isSelected ? Color(red: 0.95, green: 0.85, blue: 0.45) : Color.white.opacity(0.08))
                        .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }
}

/// 场景推荐卡：首选吉方、格局与行动指引。
struct QimenScenarioGuideCard: View {
    let rec: QimenScenarioRecommendation
    @ObservedObject private var lang = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: rec.scenario.iconName)
                    .adaptiveFont(size: 12)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text("\(rec.scenario.localizedTitle) · \(rec.directionTitle)")
                    .adaptiveFont(size: 12, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
                Text(badgeLabel)
                    .adaptiveFont(size: 9, weight: .bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yanCyan.opacity(0.18))
                    .foregroundColor(Color.yanCyan)
                    .cornerRadius(4)
            }
            Text(rec.keyPattern)
                .adaptiveFont(size: 10, weight: .semibold, design: .monospaced)
                .foregroundColor(Color.green)
            Text(rec.actionGuide)
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color(red: 0.11, green: 0.13, blue: 0.18))
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.35), lineWidth: 1)
        )
    }

    private var badgeLabel: String {
        switch lang.effectiveLanguage {
        case .en: return "Best Direction"
        case .zhHant: return "一事一斷 · 首選吉方"
        case .ja: return "目的別・最吉方位"
        case .ko: return "목적별 길방"
        case .vi: return "Phương vị ưu tiên"
        case .th: return "ทิศมงคลตามภารกิจ"
        case .id: return "Arah Prioritas"
        case .auto, .zhHans: return "一事一断 · 首选吉方"
        }
    }
}

/// 未解锁时的能力预览卡（展开态用来填满右栏）。
struct QimenVIPPreviewCard: View {
    let onUnlock: () -> Void
    @ObservedObject private var lang = LocalizationManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .adaptiveFont(size: 16)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(lang.t("privilege_qimen_title"))
                    .adaptiveFont(size: 14, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Spacer()
                Text(lang.t("vip_badge_title"))
                    .adaptiveFont(size: 10, weight: .bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.95, green: 0.85, blue: 0.45).opacity(0.2))
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    .cornerRadius(4)
            }

            Text(lang.t("privilege_qimen_desc"))
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(3)

            Divider().background(Color.white.opacity(0.1))

            Text("🧭 \(lang.t("privilege_qm_feature_title"))")
                .adaptiveFont(size: 12, weight: .semibold)
                .foregroundColor(Color.yanCyan)

            VStack(alignment: .leading, spacing: 6) {
                Text("• \(lang.t("privilege_qm_bullet_1"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
                Text("• \(lang.t("privilege_qm_bullet_2"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
                Text("• \(lang.t("privilege_qm_bullet_3"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.75))
            }

            Spacer(minLength: 8)

            Button(action: onUnlock) {
                HStack {
                    Spacer()
                    Image(systemName: "crown.fill")
                    Text(lang.t("unlock_vip_now"))
                    Spacer()
                }
                .adaptiveFont(size: 12, weight: .bold)
                .padding(.vertical, 8)
                .background(Color(red: 0.83, green: 0.68, blue: 0.21))
                .foregroundColor(.black)
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
}
