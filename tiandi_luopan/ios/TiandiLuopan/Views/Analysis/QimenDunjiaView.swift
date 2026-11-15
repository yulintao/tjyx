import SwiftUI
import UIKit
import Combine

// MARK: - 三式绝学 · 时家奇门遁甲全息排盘与出行导航视图 (PRD 第11章)

public struct QimenDunjiaView: View {
    public var isActive: Bool = true
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @StateObject private var viewModel = QimenViewModel()

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

    private var heading: Double { motion.headingState.facingAngle }

    public var body: some View {
        Group {
            if isActive {
                // 视图只读盘：首次进入或数据为空时用当前方位即时补算一次，
                // 之后一律走 viewModel 的节流结果。
                let chart = viewModel.chart
                    ?? QimenEngine.shared.calculateChart(date: viewModel.effectiveDate, heading: heading)
                let rec = QimenEngine.shared.evaluateScenario(
                    viewModel.selectedScenario,
                    chart: chart,
                    heading: heading
                )

                // iPhone Duo 展开态双栏：左栏 = 奇门九宫方阵（主交互），
                // 右栏 = 选中宫门星神摘要与出行动身方位导航（分析解释）；折叠态保持原单列纵排。
                FoldableTwoPane(compactSpacing: 12) {
                    VStack(spacing: 12) {
                        headerBar(chart: chart)

                        qimenTimeControlBar()
                            .padding(.horizontal, 16)

                        QimenScenarioSelectorBar(selected: viewModel.selectedScenario) { scenario in
                            viewModel.selectScenario(scenario, heading: heading)
                        }
                        .padding(.horizontal, 16)

                        // P0.2 开放 3x3 奇门九宫方阵预览 (天地人神四盘可点选查看八门九星)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                            let activeId = viewModel.selectedPalaceId ?? rec.recommendedPalaceId
                            ForEach(chart.cells) { cell in
                                QimenPalaceCellView(
                                    cell: cell,
                                    isSelected: cell.palaceId == activeId,
                                    isRoomy: isRoomyLayout
                                )
                                .onTapGesture {
                                    viewModel.selectedPalaceId = cell.palaceId
                                }
                            }
                        }
                        // 分栏时铺满左栏（两栏已按有效宽度分配），单列宽屏仍 580、手机全宽
                        .frame(maxWidth: isSplitLayout ? .infinity : (isLargeLayout ? 580 : .infinity))
                        .padding(.horizontal, isLargeLayout ? 0 : 16)
                    }
                } analysis: {
                    // 选中宫门星神摘要与出行动身方位导航（展开态右栏 / 折叠态底部）
                    VStack(spacing: 12) {
                        QimenScenarioGuideCard(rec: rec)
                            .padding(.horizontal, 16)

                        if let activeCell = chart.cells.first(where: { $0.palaceId == (viewModel.selectedPalaceId ?? rec.recommendedPalaceId) }), !activeCell.isTaiJiCenter {
                            selectedPalaceSummary(cell: activeCell)
                        }

                        if iap.hasUnlockedVIP {
                            travelNavigationCard(chart: chart)
                        } else {
                            QimenVIPPreviewCard(onUnlock: { viewModel.showPaywall = true })
                                .padding(.horizontal, 16)
                        }
                    }
                }
            } else {
                Color.clear
            }
        }
        .sheet(isPresented: $viewModel.showPaywall) {
            VIPPaywallSheet(defaultProductId: .proLifetime)
        }
        .onAppear {
            viewModel.refresh(force: true, heading: heading, isActive: isActive)
        }
        .onChange(of: motion.headingState.facingAngle) { _ in
            viewModel.refresh(heading: heading, isActive: isActive)
        }
        .onChange(of: lang.effectiveLanguage) { _ in
            viewModel.refresh(force: true, heading: heading, isActive: isActive)
        }
        .onChange(of: motion.currentSolarTermName) { _ in
            if !viewModel.isUsingCustomDate {
                viewModel.refresh(heading: heading, isActive: isActive)
            }
        }
        .onChange(of: isActive) { active in
            if active { viewModel.refresh(force: true, heading: heading, isActive: isActive) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            viewModel.refresh(force: true, heading: heading, isActive: isActive)
        }
        .onReceive(Self.chartRefreshTimer) { _ in
            viewModel.refresh(heading: heading, isActive: isActive)
        }
    }

    // MARK: - 标题栏

    private func headerBar(chart: QimenChart) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(lang.t("qimen_header_title"))
                    .adaptiveFont(size: 14, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            }
            Spacer()
            Text(chart.title)
                .adaptiveFont(size: 11, weight: .bold)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - P0.3 时辰穿越控制栏（每 2 小时换一局，支持提前推演谈判/出行时辰）

    private func qimenTimeControlBar() -> some View {
        let prevLabel: String
        let nextLabel: String
        let nowLabel: String
        switch lang.effectiveLanguage {
        case .en:
            prevLabel = "-2h"; nextLabel = "+2h"; nowLabel = "Now"
        case .zhHant:
            prevLabel = "上一時辰"; nextLabel = "下一時辰"; nowLabel = "回到此刻"
        case .ja:
            prevLabel = "-2時間(前刻)"; nextLabel = "+2時間(次刻)"; nowLabel = "現在へ"
        case .ko:
            prevLabel = "이전 시진(-2h)"; nextLabel = "다음 시진(+2h)"; nowLabel = "현재"
        case .vi:
            prevLabel = "-2 giờ"; nextLabel = "+2 giờ"; nowLabel = "Hiện tại"
        case .th:
            prevLabel = "-2 ชม."; nextLabel = "+2 ชม."; nowLabel = "ตอนนี้"
        case .id:
            prevLabel = "-2 Jam"; nextLabel = "+2 Jam"; nowLabel = "Sekarang"
        case .auto, .zhHans:
            prevLabel = "上一时辰"; nextLabel = "下一时辰"; nowLabel = "回到此刻"
        }

        return HStack(spacing: 8) {
            Button(action: { viewModel.shiftHour(by: -2, heading: heading) }) {
                Text(prevLabel)
                    .adaptiveFont(size: 10, weight: .semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }

            DatePicker("", selection: $viewModel.selectedDate, displayedComponents: [.date, .hourAndMinute])
                .labelsHidden()
                .colorScheme(.dark)
                .scaleEffect(0.88)
                .onChange(of: viewModel.selectedDate) { date in
                    viewModel.setCustomDate(date, heading: heading)
                }

            Button(action: { viewModel.shiftHour(by: 2, heading: heading) }) {
                Text(nextLabel)
                    .adaptiveFont(size: 10, weight: .semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }

            if viewModel.isUsingCustomDate {
                Button(action: { viewModel.resetToNow(heading: heading) }) {
                    Text(nowLabel)
                        .adaptiveFont(size: 10, weight: .bold)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(Color.yanCyan.opacity(0.2))
                        .foregroundColor(Color.yanCyan)
                        .cornerRadius(6)
                }
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: - 选中宫摘要

    private func selectedPalaceSummary(cell: QimenPalaceCell) -> some View {
        let doorObj = QimenDoor(
            name: cell.doorName,
            palace: cell.palaceId,
            isAuspicious: cell.isDoorAuspicious,
            luckType: cell.doorLuck,
            lore: ""
        )
        return HStack(spacing: 8) {
            Text("【\(cell.localizedPalaceName)】")
                .adaptiveFont(size: 11, weight: .bold)
                .foregroundColor(Color.yanCyan)
            Text("\(cell.localizedDoorName) [\(doorObj.localizedLuckType)] · \(cell.localizedGodName) · \(cell.localizedStarName)")
                .adaptiveFont(size: 11, weight: .semibold)
                .foregroundColor(cell.isDoorAuspicious ? .green : (cell.isDoorInauspicious ? .red : Color(red: 0.95, green: 0.85, blue: 0.45)))
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
        .padding(.horizontal, 16)
    }

    // MARK: - 出行动身方位导航卡

    private func travelNavigationCard(chart: QimenChart) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "location.north.circle.fill")
                    .foregroundColor(Color(red: 0.83, green: 0.68, blue: 0.21))
                Text(lang.t("qimen_travel_best"))
                    .adaptiveFont(size: 12, weight: .bold)
                    .foregroundColor(.white)
                Spacer()
                Text(lang.t("qimen_pattern_best"))
                    .adaptiveFont(size: 10)
                    .foregroundColor(.green)
            }

            Text("\(lang.t("qimen_best_nav"))【\(chart.bestNavDirection)】！\(chart.bestNavReason)")
                .adaptiveFont(size: 11)
                .foregroundColor(Color.green)
                .lineLimit(2)

            if !chart.tabooDirections.isEmpty {
                Text("\(lang.t("qimen_taboo_nav"))【\(chart.tabooDirections)】\(lang.t("qimen_taboo_suffix"))")
                    .adaptiveFont(size: 11)
                    .foregroundColor(Color.orange)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .background(Color(red: 0.12, green: 0.12, blue: 0.16))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(red: 0.83, green: 0.68, blue: 0.21).opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}
