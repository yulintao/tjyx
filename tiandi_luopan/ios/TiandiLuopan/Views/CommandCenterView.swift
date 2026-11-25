import SwiftUI

// MARK: - 总控首页 (Command Center)
// 设计目标：打开 App 第一屏即可触达全部功能，无需在多个 Tab 间来回切换查找。
// 所有入口复用既有 AppNavigationRouter 深链，不改动任何子功能实现。

public struct CommandCenterView: View {
    @ObservedObject private var lang = LocalizationManager.shared
    @ObservedObject private var motion = CompassMotionManager.shared
    @ObservedObject private var workflow = SpatialWorkflowStore.shared
    @ObservedObject private var training = CompassTrainingStore.shared
    @ObservedObject private var iap = StoreKitIAPManager.shared

    private var isEn: Bool { lang.effectiveLanguage == .en }

    // 浅色暖纸方案：复用全局语义令牌，不另起深色底。
    private let card = Color.surfaceCard
    private let platinum = Color.goldText
    private let mint = Color.semJi
    private let coral = Color.vermilion

    public init() {}

    // MARK: 数据模型
    private struct CommandItem: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let icon: String
        let tint: Color
        let action: () -> Void
    }

    private struct CommandGroup: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let items: [CommandItem]
    }

    private func go(_ tab: Int, feature: AnalysisFeature? = nil) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AppNavigationRouter.shared.requestRoute(tab: tab, feature: feature)
    }

    // MARK: 功能分组
    private var groups: [CommandGroup] {
        [
            CommandGroup(title: isEn ? "Survey & Space" : "测绘与空间", icon: "ruler",
                         items: [
                            .init(title: isEn ? "Floorplan" : "户型测绘", subtitle: isEn ? "Import · Identify · Edit" : "导入 · 识别 · 编辑",
                                  icon: "house.fill", tint: platinum) { go(0) },
                            .init(title: isEn ? "AR Survey" : "AR 测绘", subtitle: isEn ? "Distance · Area · 3D" : "测距 · 面积 · 建模",
                                  icon: "camera.viewfinder", tint: mint) { go(1) },
                            .init(title: isEn ? "Compass" : "罗盘测量", subtitle: isEn ? "True north · Level · Lock" : "真北 · 水平 · 锁定",
                                  icon: "safari.fill", tint: coral) { go(2) },
                            .init(title: isEn ? "Report" : "综合报告", subtitle: isEn ? "One-click summary" : "一键汇总导出",
                                  icon: "doc.text.fill", tint: platinum) { go(0) }
                         ]),
            CommandGroup(title: isEn ? "Calculations" : "数理计算", icon: "square.grid.3x3.fill",
                         items: [
                            .init(title: isEn ? "Xuan Kong" : "玄空飞星", subtitle: isEn ? "Nine stars" : "九宫飞星排盘",
                                  icon: "square.grid.3x3.fill", tint: platinum) { go(3, feature: .xuanKong) },
                            .init(title: isEn ? "Ba Zhai" : "八宅", subtitle: isEn ? "Eight mansions" : "大游年方位",
                                  icon: "house.fill", tint: mint) { go(3, feature: .baZhai) },
                            .init(title: isEn ? "San He" : "三合水法", subtitle: isEn ? "Water methods" : "水法参考",
                                  icon: "water.waves", tint: mint) { go(3, feature: .sanHe) },
                            .init(title: isEn ? "Purple White" : "紫白", subtitle: isEn ? "Flying stars" : "流年飞星",
                                  icon: "sparkles", tint: platinum) { go(3, feature: .purpleWhite) },
                            .init(title: isEn ? "Qi Men" : "奇门", subtitle: isEn ? "Calendar" : "时家奇门历法",
                                  icon: "safari", tint: coral) { go(3, feature: .qimen) },
                            .init(title: isEn ? "Owner" : "宅主资料", subtitle: isEn ? "Family profile" : "家庭成员与方位",
                                  icon: "person.2.fill", tint: platinum) { go(3, feature: .owner) },
                            .init(title: isEn ? "Dates" : "择日", subtitle: isEn ? "Calendar tools" : "历法参考",
                                  icon: "calendar.badge.clock", tint: mint) { go(3, feature: .dates) },
                            .init(title: isEn ? "TianJi Scroll" : "天机书", subtitle: isEn ? "Export long scroll" : "长卷导出",
                                  icon: "scroll.fill", tint: platinum) { go(3, feature: .xuanKong) }
                         ]),
            CommandGroup(title: isEn ? "Profile & Settings" : "档案与设置", icon: "gearshape.fill",
                         items: [
                            .init(title: isEn ? "Training Profile" : "训练档案", subtitle: "LV.\(training.level) · \(training.xp) XP",
                                  icon: "rosette", tint: platinum) { go(4) },
                            .init(title: isEn ? "Membership" : "会员中心", subtitle: iap.hasUnlockedVIP ? (isEn ? "Pro" : "专业版") : (isEn ? "Upgrade" : "开通专业版"),
                                  icon: "crown.fill", tint: platinum) { go(4) },
                            .init(title: isEn ? "Language" : "语言与校准", subtitle: lang.currentSetting.displayName,
                                  icon: "globe", tint: mint) { go(4) },
                            .init(title: isEn ? "About" : "关于与隐私", subtitle: isEn ? "Legal · Privacy" : "条款 · 隐私",
                                  icon: "info.circle.fill", tint: coral) { go(4) }
                         ])
        ]
    }

    public var body: some View {
        ZStack {
            Color.screenInk.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Hero 1：品牌 + 状态摘要
                    header
                    statusStrip

                    // 功能宫格：全部入口一屏可达
                    ForEach(groups) { group in
                        groupSection(group)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEn ? "TianJi Space" : "天机物设")
                    .adaptiveFont(size: 28, weight: .bold, design: .rounded)
                    .foregroundColor(platinum)
                Text(isEn ? "Spatial survey · Traditional research" : "空间测绘 · 传统文化研究参考")
                    .adaptiveFont(size: 12).foregroundColor(Color.paperSub)
            }
            Spacer()
            if iap.hasUnlockedVIP {
                Image(systemName: "crown.fill").foregroundColor(platinum).adaptiveFont(size: 20)
            }
        }
    }

    /// 状态摘要：当前方位 + 工作流进度 + 连续打卡
    private var statusStrip: some View {
        HStack(spacing: 10) {
            statusCell(icon: "safari.fill",
                       value: motion.headingState.sittingMountain.localizedName + motion.headingState.facingMountain.localizedName,
                       label: isEn ? "Facing" : "当前坐向", tint: platinum)
            statusCell(icon: "checkmark.circle.fill",
                       value: "\(workflow.completedStages)/4",
                       label: isEn ? "Workflow" : "流程进度", tint: mint)
            statusCell(icon: "flame.fill",
                       value: "\(training.streakDays)",
                       label: isEn ? "Streak" : "连续天数", tint: coral)
        }
    }

    private func statusCell(icon: String, value: String, label: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundColor(tint).adaptiveFont(size: 16)
            Text(value).adaptiveFont(size: 14, weight: .bold, design: .rounded)
                .foregroundColor(Color.paperText).lineLimit(1).minimumScaleFactor(0.75)
            Text(label).adaptiveFont(size: 10).foregroundColor(Color.paperSub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(0.25), lineWidth: 1))
    }

    private func groupSection(_ group: CommandGroup) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: group.icon).foregroundColor(platinum).adaptiveFont(size: 14)
                Text(group.title).adaptiveFont(size: 16, weight: .bold).foregroundColor(Color.paperText)
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(group.items) { item in
                    Button(action: item.action) {
                        HStack(spacing: 10) {
                            Image(systemName: item.icon)
                                .foregroundColor(item.tint)
                                .adaptiveFont(size: 20)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .adaptiveFont(size: 13, weight: .semibold)
                                    .foregroundColor(Color.paperText)
                                    .lineLimit(1)
                                Text(item.subtitle)
                                    .adaptiveFont(size: 10)
                                    .foregroundColor(Color.paperSub)
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: DS.touchMin + 8)
                        .background(card)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(item.tint.opacity(0.18), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
