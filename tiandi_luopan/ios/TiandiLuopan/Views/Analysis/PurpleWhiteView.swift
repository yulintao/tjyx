import SwiftUI
import UIKit
import Combine

// MARK: - 紫白飞星流年流月客星动态气运与太岁三煞视图 (PRD 第12章)

public struct PurpleWhiteView: View {
    /// Whether the purple-white chart is currently visible.  The parent
    /// analysis page keeps its subviews alive while switching tabs, so this
    /// flag prevents hidden charts from reacting to every compass sample.
    public var isActive: Bool = true
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @StateObject private var viewModel = PurpleWhiteViewModel()

    private static let chartRefreshTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    // 两套口径（见 AdaptiveLayout）：isSplitLayout = Duo 内屏 / iPad 横屏左右分栏；
    // isLargeLayout 为宽屏（含 iPad），只放大宫格与内容尺寸。
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
                // 首帧用当前方位补算一次，之后读 viewModel 的节流结果。
                let chart = viewModel.chart
                    ?? PurpleWhiteEngine.shared.calculateChart(date: viewModel.effectiveDate, heading: heading)
                chartContent(chart: chart)
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
        .onChange(of: isActive) { active in
            if active {
                viewModel.refresh(force: true, heading: heading, isActive: isActive)
            }
        }
        .onChange(of: lang.effectiveLanguage) { _ in
            viewModel.refresh(force: true, heading: heading, isActive: isActive)
        }
        .onChange(of: motion.currentSolarTermName) { _ in
            if !viewModel.isUsingCustomDate {
                viewModel.refresh(heading: heading, isActive: isActive)
            }
        }
        .onReceive(Self.chartRefreshTimer) { _ in
            if !viewModel.isUsingCustomDate {
                viewModel.refresh(heading: heading, isActive: isActive)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            viewModel.refresh(force: true, heading: heading, isActive: isActive)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            viewModel.refresh(force: true, heading: heading, isActive: isActive)
        }
    }

    // MARK: - 页面主体

    private func chartContent(chart: PurpleWhiteChart) -> some View {
        let activePalaceId = viewModel.activePalaceId(chart: chart)
        // iPhone Duo 展开态双栏：左栏 = 太岁三煞警戒与九宫飞星盘（主交互），
        // 右栏 = 选中宫位流年流月客星详解（分析解释）；折叠态保持原单列纵排。
        return FoldableTwoPane(compactSpacing: 12) {
            VStack(spacing: 12) {
                headerBar(chart: chart)

                // P0.3 流年/流月时间穿越切换栏
                monthControlBar()
                    .padding(.horizontal, 16)

                // P0.2 开放九宫飞星盘面与太岁三煞预警预览（先建立凶吉感知，深度断语再做 VIP 转化）
                HStack(spacing: 8) {
                    PurpleWhiteTagPill(title: lang.t("tai_sui_label"), value: chart.taiSuiDescription, color: Color.red)
                    PurpleWhiteTagPill(title: lang.t("sui_po_label"), value: chart.suiPoDescription, color: Color.orange)
                    PurpleWhiteTagPill(title: lang.t("san_sha_label"), value: chart.sanShaDescription, color: Color.purple)
                }
                .padding(.horizontal, 16)

                // 3x3 九宫飞星网格 (流年客星与二五交加报警)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                    ForEach(chart.palaceItems) { item in
                        PurpleWhitePalaceCellView(
                            item: item,
                            isFacing: item.palaceId == chart.currentFacingPalace,
                            isSelected: item.palaceId == activePalaceId,
                            isRoomy: isRoomyLayout
                        )
                        .onTapGesture {
                            viewModel.selectedPalaceId = item.palaceId
                        }
                    }
                }
                // 分栏时铺满左栏（两栏已按有效宽度分配），单列宽屏仍 580、手机全宽
                .frame(maxWidth: isSplitLayout ? .infinity : (isLargeLayout ? 580 : .infinity))
                .padding(.horizontal, isLargeLayout ? 0 : 16)
            }
        } analysis: {
            // 选中宫位流年/流月客星详解与宜忌建议（展开态右栏 / 折叠态底部）
            VStack(spacing: 12) {
                if let activeItem = chart.palaceItems.first(where: { $0.palaceId == activePalaceId }) ?? chart.palaceItems.first {
                    PurpleWhitePalaceDetailCard(
                        item: activeItem,
                        isFacing: activeItem.palaceId == chart.currentFacingPalace
                    )
                    .padding(.horizontal, 16)
                }
                if !iap.hasUnlockedVIP {
                    PurpleWhiteVIPPreviewCard(onUnlock: { viewModel.showPaywall = true })
                        .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - 标题与年份摘要

    private func headerBar(chart: PurpleWhiteChart) -> some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "calendar.badge.clock")
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                Text(lang.t("purplewhite_header_title"))
                    .adaptiveFont(size: 14, weight: .bold)
                    .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
            }
            Spacer()
            Text(dateLabel(chart: chart))
                .adaptiveFont(size: 11, weight: .bold)
                .foregroundColor(.white.opacity(0.8))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 16)
    }

    private func dateLabel(chart: PurpleWhiteChart) -> String {
        if lang.effectiveLanguage == .en {
            return "\(chart.year) / \(chart.month)"
        }
        return "\(chart.year)\(lang.t("year_suffix")) · \(chart.month)\(lang.t("month_suffix"))"
    }

    // MARK: - P0.3 流年/流月时间穿越切换栏

    private func monthControlBar() -> some View {
        let prevLabel: String
        let nextLabel: String
        let nowLabel: String
        switch lang.effectiveLanguage {
        case .en:
            prevLabel = "-1 Month"; nextLabel = "+1 Month"; nowLabel = "Current"
        case .zhHant:
            prevLabel = "上一節氣月"; nextLabel = "下一節氣月"; nowLabel = "回到當月"
        case .ja:
            prevLabel = "前節気月"; nextLabel = "次節気月"; nowLabel = "今月へ"
        case .ko:
            prevLabel = "이전 절기월"; nextLabel = "다음 절기월"; nowLabel = "이번달"
        case .vi:
            prevLabel = "Tháng trước"; nextLabel = "Tháng sau"; nowLabel = "Tháng này"
        case .th:
            prevLabel = "เดือนก่อน"; nextLabel = "เดือนถัดไป"; nowLabel = "เดือนนี้"
        case .id:
            prevLabel = "-1 Bulan"; nextLabel = "+1 Bulan"; nowLabel = "Bulan Ini"
        case .auto, .zhHans:
            prevLabel = "上一节气月"; nextLabel = "下一节气月"; nowLabel = "回到当月"
        }

        return HStack(spacing: 8) {
            Button(action: { viewModel.shiftMonth(byDays: -30, heading: heading) }) {
                Text(prevLabel)
                    .adaptiveFont(size: 10, weight: .semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(.white)
                    .cornerRadius(6)
            }

            DatePicker("", selection: $viewModel.selectedDate, displayedComponents: [.date])
                .labelsHidden()
                .colorScheme(.dark)
                .scaleEffect(0.88)
                .onChange(of: viewModel.selectedDate) { date in
                    viewModel.setCustomDate(date, heading: heading)
                }

            Button(action: { viewModel.shiftMonth(byDays: 30, heading: heading) }) {
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
}
