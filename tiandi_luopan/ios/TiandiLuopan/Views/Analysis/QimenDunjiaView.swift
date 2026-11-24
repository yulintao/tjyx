import SwiftUI
import UIKit
import Combine

// MARK: - 三式绝学 · 时家奇门遁甲全息排盘与出行导航视图 (PRD 第11章)

public struct QimenDunjiaView: View {
    public var isActive: Bool = true
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var showPaywall: Bool = false
    @State private var selectedDate: Date = Date()
    @State private var isUsingCustomDate: Bool = false
    @State private var cachedChart: QimenChart?
    @State private var selectedPalaceId: Int? = nil
    @State private var selectedScenario: QimenScenarioType = .contract
    @State private var lastChartHeading: Double?
    @State private var lastChartTimeKey: QimenChartTimeKey?

    // Qimen uses the current hour. A low-frequency publisher catches an hour
    // boundary while the phone is stationary; refreshChart's time key keeps
    // the timer from rebuilding the chart during the other 59 ticks.
    private static let chartRefreshTimer = Timer.publish(
        every: 60,
        on: .main,
        in: .common
    ).autoconnect()

    // 两套口径（见 AdaptiveLayout）：isSplitLayout = Duo 内屏 / iPad 横屏左右分栏；
    // isLargeLayout 为宽屏（含 iPad），只放大九宫与内容尺寸。
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.adaptiveLayoutForm) private var layoutForm
    private var isSplitLayout: Bool {
        AdaptiveLayout.isTwoPane(horizontal: horizontalSizeClass,
                                      vertical: verticalSizeClass, form: layoutForm)
    }
    private var isLargeLayout: Bool {
        AdaptiveLayout.isWide(sizeClass: horizontalSizeClass)
    }
    /// 分栏后左栏只有 55~60% 宽，控件尺寸不能沿用「整屏宽屏」的放大档位。
    private var isRoomyLayout: Bool {
        isLargeLayout && !isSplitLayout
    }
    
    public init(isActive: Bool = true) {
        self.isActive = isActive
    }
    
    public var body: some View {
        return Group {
            if isActive {
                let effectiveDate = isUsingCustomDate ? selectedDate : Date()
                // Motion publishes tilt and magnetic-field samples
                // independently of the heading. Reuse the chart across
                // those updates; Qimen only needs a new result when the
                // heading or language changes.
                let chart = cachedChart ?? QimenEngine.shared.calculateChart(date: effectiveDate, heading: motion.headingState.facingAngle)

                // iPhone Duo 展开态双栏：左栏 = 奇门九宫方阵（主交互），
                // 右栏 = 选中宫门星神摘要与出行动身方位导航（分析解释）；折叠态保持原单列纵排。
                FoldableTwoPane(compactSpacing: 12) {
                VStack(spacing: 12) {
            // 局数标题栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundColor(Color.goldText)
                    Text(lang.t("qimen_header_title"))
                        .adaptiveFont(size: 14, weight: .bold)
                        .foregroundColor(Color.goldText)
                }
                Spacer()
                Text(chart.title)
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, 16)

            // P0.3 时辰穿越控制栏（每 2 小时换一局，支持任意时刻历法排盘校验）
            qimenTimeControlBar()
                .padding(.horizontal, 16)
            
            // 3x3 奇门九宫方阵（天地人神四盘确定性排盘矩阵，点击任意宫位查看参数详情）
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(chart.cells) { cell in
                    // 默认选中中宫(4)会被右栏 isTaiJiCenter 判定隐藏 → 首屏「点了没反应」。
                    // 改默认选中一个非中宫宫位，保证右栏详情始终有内容。
                    let activeId = selectedPalaceId ?? 0
                    qimenCellView(cell: cell, isSelected: cell.palaceId == activeId)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.15)) {
                                selectedPalaceId = cell.palaceId
                            }
                        }
                        .accessibilityLabel("\(cell.localizedPalaceName)宫，点击查看四盘参数")
                }
            }
            // 分栏时铺满左栏（两栏已按有效宽度分配），单列宽屏仍 580、手机全宽
            .frame(maxWidth: isSplitLayout ? .infinity : (isLargeLayout ? 580 : .infinity))
            .padding(.horizontal, isLargeLayout ? 0 : 16)
            }
            } analysis: {
            // 选中宫位四盘参数明细与可验证天文历法依据（移除预测导向卡片，保留可验证天文历法依据）
            VStack(spacing: 12) {
                let solar = SolarTimeCalculator.shared.calculate(
                    date: effectiveDate,
                    longitude: motion.hasLocationFix ? motion.longitude : 120.0
                )
                let isEn = (lang.effectiveLanguage == .en)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "function")
                            .foregroundColor(.yanCyan)
                        Text(isEn ? "ChaiBu Calendrical Parameters" : "时家奇门 · 拆补法排盘参数校验")
                            .adaptiveFont(size: 12, weight: .bold)
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(chart.dunType) · \(chart.juNumber)")
                            .adaptiveFont(size: 10.5, weight: .bold, design: .monospaced)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.yanGold.opacity(0.2))
                            .foregroundColor(.yanGold)
                            .cornerRadius(4)
                    }
                    Text("\(isEn ? "Solar Term" : "节气")：\(solar.solarTermName) · \(isEn ? "Four Pillars" : "干支四柱")：\(solar.baziGanzhi)")
                        .adaptiveFont(size: 10.5, design: .monospaced)
                        .foregroundColor(.white.opacity(0.82))
                    Text(isEn
                         ? "Deterministic 4-layer matrix (Earth Palace / Heaven Star / Human Gate / Spirit) derived from astronomical solar longitude and stem-branch cycle."
                         : "依据天文太阳黄经定节气与干支时柱，按传统拆补法定阴阳遁局数，生成天地人神四盘对应矩阵，可供独立手工复核。")
                        .adaptiveFont(size: 10)
                        .foregroundColor(.white.opacity(0.65))
                }
                .padding(10)
                .background(Color.surfaceCard)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.yanCyan.opacity(0.25), lineWidth: 1)
                )
                .padding(.horizontal, 16)

                if let activeCell = chart.cells.first(where: { $0.palaceId == (selectedPalaceId ?? 0) }), !activeCell.isTaiJiCenter {
                    let doorObj = QimenDoor(name: activeCell.doorName, palace: activeCell.palaceId, isAuspicious: activeCell.isDoorAuspicious, luckType: activeCell.doorLuck, lore: "")
                    VStack(alignment: .leading, spacing: 9) {
                        HStack(spacing: 6) {
                            qimenLayerPill(label: isEn ? "Palace" : "地宫", value: activeCell.localizedPalaceName, tint: .yanCyan)
                            qimenLayerPill(label: isEn ? "Gate" : "八门", value: activeCell.localizedDoorName, tint: activeCell.isDoorAuspicious ? .semJi : (activeCell.isDoorInauspicious ? .semXiong : .white))
                            qimenLayerPill(label: isEn ? "Star" : "九星", value: activeCell.localizedStarName, tint: .yanGold)
                            qimenLayerPill(label: isEn ? "Spirit" : "八神", value: activeCell.localizedGodName, tint: .semWarn)
                        }
                        Text(doorObj.classicalSourceNote)
                            .adaptiveFont(size: 10.5)
                            .foregroundColor(.white.opacity(0.75))
                            .lineSpacing(2)
                    }
                    .padding(11)
                    .background(Color.surfaceElevated)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.yanCyan.opacity(0.28), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                }
            }
            }
            } else {
                Color.clear
            }
        }
        .sheet(isPresented: $showPaywall) {
            VIPPaywallSheet(defaultProductId: .vipYearly)
        }
        .onAppear {
            refreshChart(force: true)
        }
        .onChange(of: motion.headingState.facingAngle) { _ in
            refreshChart()
        }
        .onChange(of: lang.effectiveLanguage) { _ in
            refreshChart(force: true)
        }
        .onChange(of: motion.currentSolarTermName) { _ in
            if !isUsingCustomDate { refreshChart() }
        }
        .onChange(of: isActive) { active in
            if active { refreshChart(force: true) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            refreshChart(force: true)
        }
        .onReceive(Self.chartRefreshTimer) { _ in
            refreshChart()
        }
    }

    private func qimenLayerPill(label: String, value: String, tint: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .adaptiveFont(size: 9, weight: .medium)
                .foregroundColor(.white.opacity(0.55))
            Text(value)
                .adaptiveFont(size: 11, weight: .bold)
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(tint.opacity(0.1))
        .cornerRadius(7)
    }

    private func qimenTimeControlBar() -> some View {
        let isEn = (lang.effectiveLanguage == .en)
        let prevLabel: String
        let nextLabel: String
        let nowLabel: String
        switch lang.effectiveLanguage {
        case .en:
            prevLabel = "-2h"; nextLabel = "+2h"; nowLabel = "Now"
        case .zhHant:
            prevLabel = "上一時辰"; nextLabel = "下一時辰"; nowLabel = "回到此刻"
        case .ja:
            prevLabel = "-2時間"; nextLabel = "+2時間"; nowLabel = "現在へ"
        case .ko:
            prevLabel = "-2시간"; nextLabel = "+2시간"; nowLabel = "현재"
        case .vi:
            prevLabel = "-2 giờ"; nextLabel = "+2 giờ"; nowLabel = "Hiện tại"
        case .th:
            prevLabel = "-2 ชม."; nextLabel = "+2 ชม."; nowLabel = "ตอนนี้"
        case .id:
            prevLabel = "-2 Jam"; nextLabel = "+2 Jam"; nowLabel = "Sekarang"
        case .auto, .zhHans:
            prevLabel = "上一时辰"; nextLabel = "下一时辰"; nowLabel = "回到此刻"
        }

        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.yanGold)
                DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .colorScheme(.dark)
                    .onChange(of: selectedDate) { _ in
                        isUsingCustomDate = true
                        refreshChart(force: true)
                    }
                Spacer(minLength: 4)
                if isUsingCustomDate {
                    Button(action: {
                        isUsingCustomDate = false
                        selectedDate = Date()
                        refreshChart(force: true)
                    }) {
                        Text(nowLabel)
                            .adaptiveFont(size: 10.5, weight: .bold)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Color.yanCyan.opacity(0.2))
                            .foregroundColor(Color.yanCyan)
                            .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 6) {
                qimenStepButton(title: isEn ? "-1d" : "前一日", hours: -24)
                qimenStepButton(title: prevLabel, hours: -2)
                qimenStepButton(title: nextLabel, hours: 2)
                qimenStepButton(title: isEn ? "+1d" : "后一日", hours: 24)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.09), lineWidth: 1)
        )
    }

    private func qimenStepButton(title: String, hours: Int) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            let base = isUsingCustomDate ? selectedDate : Date()
            selectedDate = Calendar.current.date(byAdding: .hour, value: hours, to: base) ?? base
            isUsingCustomDate = true
            refreshChart(force: true)
        }) {
            Text(title)
                .adaptiveFont(size: DS.minBodyFont, weight: .semibold)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: DS.touchMin)
                .padding(.horizontal, DS.padS)
                .background(Color.white.opacity(0.08))
                .foregroundColor(.white.opacity(0.9))
                .cornerRadius(DS.radiusS)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func refreshChart(force: Bool = false) {
        guard isActive else { return }
        let heading = motion.headingState.facingAngle
        let now = isUsingCustomDate ? selectedDate : Date()
        let timeKey = QimenEngine.shared.chartTimeKey(for: now)
        if !force, let lastHeading = lastChartHeading,
           let lastTimeKey = lastChartTimeKey,
           lastTimeKey == timeKey {
            let rawDelta = abs(heading - lastHeading)
            let delta = min(rawDelta, 360.0 - rawDelta)
            // The chart's actionable turn instruction is displayed in whole
            // degrees. Rebuilding it for sub-degree sensor noise only adds
            // work and causes unnecessary SwiftUI row updates.
            if delta < 1.0 { return }
        }
        lastChartHeading = heading
        lastChartTimeKey = timeKey
        cachedChart = QimenEngine.shared.calculateChart(date: now, heading: heading)
    }
    
    private func qimenCellView(cell: QimenPalaceCell, isSelected: Bool = false) -> some View {
        let isJi = cell.isDoorAuspicious
        let isXiong = cell.isDoorInauspicious
        let borderColor = isSelected ? Color.yanCyan : (isJi ? Color.semJi.opacity(0.5) : (isXiong ? Color.semXiong.opacity(0.4) : Color.white.opacity(0.12)))
        let bgColor = isJi ? Color.semJi.opacity(0.08) : (isXiong ? Color.semXiong.opacity(0.06) : Color.surfaceElevated)
        
        return VStack {
            // 顶行: 八神 / 九星
            HStack {
                Text(cell.localizedGodName)
                    .adaptiveFont(size: 9, weight: .bold)
                    .foregroundColor(Color.semWarn)
                Spacer()
                Text(cell.localizedStarName)
                    .adaptiveFont(size: 9)
                    .foregroundColor(Color.yanCyan)
            }
            
            Spacer(minLength: 2)
            
            // 中行: 八门 (大字显影)
            Text(cell.localizedDoorName)
                .adaptiveFont(size: 15, weight: .bold, design: .serif)
                .foregroundColor(isJi ? Color.semJi : (isXiong ? Color.semXiong : Color.goldText))
            
            Spacer(minLength: 2)
            
            // 底行: 宫名 / 天地三奇六仪
            HStack {
                Text(cell.localizedPalaceName)
                    .adaptiveFont(size: 8)
                    .foregroundColor(.white.opacity(0.6))
                Spacer()
                Text("\(cell.localizedTianStem)/\(cell.localizedDiStem)")
                    .adaptiveFont(size: 9, weight: .bold, design: .monospaced)
                    .foregroundColor(Color.goldText)
            }
        }
        .padding(isRoomyLayout ? 10 : 6)
        .aspectRatio(1.0, contentMode: .fit)
        .background(bgColor)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
    }
    // MARK: - P3.3 奇门场景化一事一断选择器与指南卡
    private func qimenScenarioSelectorBar(chart: QimenChart) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(QimenScenarioType.allCases) { item in
                    let isSelected = selectedScenario == item
                    Button(action: {
                        selectedScenario = item
                        let rec = QimenEngine.shared.evaluateScenario(item, chart: chart, heading: motion.headingState.facingAngle)
                        selectedPalaceId = rec.recommendedPalaceId
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: item.iconName)
                                .adaptiveFont(size: 10)
                            Text(item.localizedTitle)
                                .adaptiveFont(size: 10, weight: .bold)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(isSelected ? Color.goldText : Color.white.opacity(0.08))
                        .foregroundColor(isSelected ? .black : .white.opacity(0.85))
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
    }

    private func qimenScenarioGuideCard(rec: QimenScenarioRecommendation) -> some View {
        let badgeLabel: String = {
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
        }()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: rec.scenario.iconName)
                    .adaptiveFont(size: 12)
                    .foregroundColor(Color.goldText)
                Text("\(rec.scenario.localizedTitle) · \(rec.directionTitle)")
                    .adaptiveFont(size: 12, weight: .bold)
                    .foregroundColor(Color.goldText)
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
                .foregroundColor(Color.semJi)
            Text(rec.actionGuide)
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.88))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(Color.surfaceCard)
        .cornerRadius(9)
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(Color.goldText.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - 奇门遁甲 VIP 展开态预览占位卡 (消除展开态双栏右侧留白)
    private func qimenVIPPreviewCard() -> some View {
        let lang = LocalizationManager.shared
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .adaptiveFont(size: 16)
                    .foregroundColor(Color.goldText)
                Text(lang.t("privilege_qimen_title"))
                    .adaptiveFont(size: 14, weight: .bold)
                    .foregroundColor(Color.goldText)
                Spacer()
                Text(lang.t("vip_badge_title"))
                    .adaptiveFont(size: 10, weight: .bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.goldText.opacity(0.2))
                    .foregroundColor(Color.goldText)
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

            Button(action: { showPaywall = true }) {
                HStack {
                    Spacer()
                    Image(systemName: "crown.fill")
                    Text(lang.t("unlock_vip_now"))
                    Spacer()
                }
                .adaptiveFont(size: 12, weight: .bold)
                .padding(.vertical, 8)
                .background(Color.goldDeep)
                .foregroundColor(.black)
                .cornerRadius(8)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.04))
        .cornerRadius(12)
    }
}
