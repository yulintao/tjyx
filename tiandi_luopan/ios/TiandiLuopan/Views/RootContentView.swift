import SwiftUI
import UIKit
import GridStack

// MARK: - iOS 14.0 颜色向下兼容扩展
// 新中式雅致色板：暖墨底 + 纸色文字 + 古金 / 朱红点缀。
// 既有符号名（yanCyan / yanGold / yanBrown）保留，避免散落各视图的引用编译断裂。
extension Color {
    /// 信息青（去霓虹的 muted 黛青）
    public static let yanCyan = Color(red: 0.32, green: 0.62, blue: 0.61)
    /// 木褐（暖棕，用于次要底色 / 木纹点缀）
    public static let yanBrown = Color(red: 0.55, green: 0.42, blue: 0.27)
    /// 古金（主强调色，低饱和哑光金）
    public static let yanGold = Color(red: 0.80, green: 0.63, blue: 0.31)
}

// MARK: - 统一设计语言 Design Tokens
// 目标：把散落在各视图的 6 种金、系统色、魔数圆角收敛到一组语义常量。
// 所有新代码优先使用这里的语义色，旧视图逐步迁移；不改变 yanGold 等既有符号，避免破坏现有编译。
extension Color {
    // 金色三阶：古金主色 / 深金（选中底、边框）/ 文字金（高对比）
    public static let goldPrimary = Color(red: 0.80, green: 0.63, blue: 0.31)
    public static let goldDeep    = Color(red: 0.63, green: 0.49, blue: 0.23)
    public static let goldText    = Color(red: 0.91, green: 0.78, blue: 0.52)

    // 朱红：强调 / 警示主点缀（替代高饱和霓虹红）
    public static let vermilion   = Color(red: 0.71, green: 0.27, blue: 0.23)

    // 纸色文字：主文字 / 次级文字
    public static let paperText   = Color(red: 0.95, green: 0.91, blue: 0.83)
    public static let paperSub    = Color(red: 0.66, green: 0.61, blue: 0.50)

    // 语义色：吉 / 凶 / 警示 / 信息，与暖墨主题统一，替代裸 .semJi/.semXiong/.semWarn/.purple
    public static let semJi     = Color(red: 0.35, green: 0.67, blue: 0.50)  // 吉 · 温润青玉
    public static let semXiong  = Color(red: 0.85, green: 0.35, blue: 0.31)  // 凶 · 朱砂红
    public static let semWarn   = Color(red: 0.88, green: 0.63, blue: 0.29)  // 留意 · 琥珀
    public static let semInfo   = Color.yanCyan

    // 表面与描边：暖墨卡片底、柔和分隔线
    public static let surfaceCard   = Color(red: 0.141, green: 0.122, blue: 0.090)
    public static let surfaceElevated = Color(red: 0.169, green: 0.145, blue: 0.106)
    public static let strokeSoft    = Color(red: 0.95, green: 0.91, blue: 0.83).opacity(0.10)
    public static let strokeGold    = Color.goldPrimary.opacity(0.26)

    /// 屏幕底色：暖墨（全 App 页面 / 弹层统一背景，替代散落的黑、冷石板与同值字面量）
    public static let screenInk     = Color(red: 0.086, green: 0.075, blue: 0.059)
}

// 布局常量：统一间距 / 圆角 / 触摸目标
public enum DS {
    public static let padS: CGFloat = 8
    public static let padM: CGFloat = 12
    public static let padL: CGFloat = 16
    public static let radiusS: CGFloat = 10
    public static let radiusM: CGFloat = 14
    public static let radiusL: CGFloat = 18
    public static let touchMin: CGFloat = 44   // 苹果人机指南最小触摸目标
    public static let minBodyFont: CGFloat = 11

    // 统一字号层级：页标题 / 小节标题 / 正文 / 次要说明 / 注释，避免各页散落 10~16 的随意取值
    public enum TypeScale {
        public static let title: CGFloat = 22
        public static let headline: CGFloat = 17
        public static let body: CGFloat = 14
        public static let sub: CGFloat = 12
        public static let caption: CGFloat = 11
    }
}

// MARK: - 可复用按钮样式（统一按压反馈与触摸目标）
struct DSPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .adaptiveFont(size: 14, weight: .bold)
            .foregroundColor(Color(red: 0.12, green: 0.10, blue: 0.04))
            .frame(maxWidth: .infinity, minHeight: DS.touchMin)
            .padding(.horizontal, DS.padM)
            .background(
                LinearGradient(
                    colors: [Color.goldText, Color.goldPrimary, Color.goldDeep],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .cornerRadius(DS.radiusM)
            .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(Color.goldText.opacity(0.5), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.88 : 1)
            .animation(.easeInOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct DSSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .adaptiveFont(size: 13, weight: .semibold)
            .foregroundColor(.primary)
            .frame(minHeight: DS.touchMin)
            .padding(.horizontal, DS.padM)
            .background(Color.white.opacity(configuration.isPressed ? 0.16 : 0.08))
            .cornerRadius(DS.radiusM)
            .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(Color.strokeSoft, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

// MARK: - 统一信息卡片修饰器
struct DSInfoCard: ViewModifier {
    var accent: Color = .strokeGold
    func body(content: Content) -> some View {
        content
            .padding(DS.padM)
            .background(Color.surfaceCard)
            .cornerRadius(DS.radiusM)
            .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(accent, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func dsInfoCard(accent: Color = .strokeGold) -> some View {
        modifier(DSInfoCard(accent: accent))
    }
}

// MARK: - 结论式界面组件族
// 目标：让各页从「工具箱全铺开」转为「结论在上、详情折叠」。

/// 分节标题：统一章节引导
struct DSSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).adaptiveFont(size: 16, weight: .bold).foregroundColor(.goldText)
            if let subtitle = subtitle {
                Text(subtitle).adaptiveFont(size: 11).foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, DS.padS)
    }
}

/// 页面页头：统一主标题 + 副标题 + 可选右侧操作（图标 / 按钮），各标签首屏共用。
struct DSScreenHeader<Accessory: View>: View {
    let title: String
    let subtitle: String?
    @ViewBuilder let accessory: () -> Accessory

    init(title: String, subtitle: String? = nil,
         @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }) {
        self.title = title
        self.subtitle = subtitle
        self.accessory = accessory
    }

    var body: some View {
        HStack(alignment: .center, spacing: DS.padM) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .adaptiveFont(size: DS.TypeScale.headline, weight: .bold)
                    .foregroundColor(.goldText)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .adaptiveFont(size: DS.TypeScale.sub)
                        .foregroundColor(.paperSub)
                }
            }
            Spacer(minLength: DS.padS)
            accessory()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, DS.padL)
        .padding(.vertical, DS.padS)
    }
}

/// 统计胶囊：一格一个关键读数
struct DSStatPill: View {
    let label: String
    let value: String
    var tint: Color = .goldText
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).adaptiveFont(size: 11).foregroundColor(.secondary)
            Text(value).adaptiveFont(size: 14, weight: .semibold).foregroundColor(tint)
                .lineLimit(2).minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DS.padM)
        .background(
            HStack(spacing: 0) {
                tint.frame(width: 3)
                Color.surfaceElevated
            }
        )
        .cornerRadius(DS.radiusS)
        .overlay(RoundedRectangle(cornerRadius: DS.radiusS).stroke(Color.strokeSoft, lineWidth: 1))
    }
}

/// 状态徽章：吉/凶/来源等短标签
struct DSStatusBadge: View {
    let text: String
    var tint: Color = .semInfo
    var body: some View {
        Text(text)
            .adaptiveFont(size: 11, weight: .semibold)
            .foregroundColor(tint)
            .padding(.horizontal, DS.padS)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14))
            .cornerRadius(DS.radiusS)
            .overlay(RoundedRectangle(cornerRadius: DS.radiusS).stroke(tint.opacity(0.4), lineWidth: 1))
    }
}

/// 空状态：图标 + 引导 + 可选操作
struct DSEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        VStack(spacing: DS.padM) {
            Image(systemName: icon).font(.system(size: 34)).foregroundColor(.semWarn.opacity(0.85))
            Text(title).adaptiveFont(size: 15, weight: .semibold).foregroundColor(.primary)
            Text(message).adaptiveFont(size: 12).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle).adaptiveFont(size: 13, weight: .semibold)
                }
                .buttonStyle(DSSecondaryButtonStyle())
                .padding(.top, DS.padS)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DS.padL)
        .dsInfoCard()
    }
}

/// 可折叠分区：默认收起，点击展开详情
struct DSCollapsibleSection<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    @State private var expanded: Bool

    init(title: String, subtitle: String? = nil, defaultExpanded: Bool = false,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        _expanded = State(initialValue: defaultExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: DS.padS) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).adaptiveFont(size: 14, weight: .semibold).foregroundColor(.primary)
                        if let subtitle = subtitle {
                            Text(subtitle).adaptiveFont(size: 11).foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .adaptiveFont(size: 12).foregroundColor(.secondary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .frame(minHeight: DS.touchMin)
                .padding(.horizontal, DS.padM)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityHint(expanded ? "收起详情" : "展开详情")

            if expanded {
                Divider().background(Color.strokeSoft)
                content
                    .padding(DS.padM)
                    .transition(.opacity)
            }
        }
        .background(Color.surfaceCard)
        .cornerRadius(DS.radiusM)
        .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(Color.strokeSoft, lineWidth: 1))
    }
}

// MARK: - 透明折叠容器（内容保留各自卡片底色，不额外套框）
struct DSFoldableSection<Content: View>: View {
    let title: String
    let subtitle: String?
    @State private var expanded: Bool
    let content: Content

    init(title: String, subtitle: String? = nil, defaultExpanded: Bool = false,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
        _expanded = State(initialValue: defaultExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.padS) {
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack(spacing: DS.padS) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).adaptiveFont(size: 12, weight: .semibold).foregroundColor(.paperSub)
                        if let subtitle = subtitle {
                            Text(subtitle).adaptiveFont(size: 10).foregroundColor(.paperSub.opacity(0.7))
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .adaptiveFont(size: 11).foregroundColor(.paperSub)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(title)
            .accessibilityHint(expanded ? "收起详情" : "展开详情")

            if expanded {
                content.transition(.opacity)
            }
        }
    }
}

// MARK: - 此刻 · 此地 · 此向 测量摘要看板
// 一屏给出：时间/节气、当前坐向、传统历法研究参考、分金空亡与折叠依据。
// 数据全部来自本机既有的共享引擎（罗盘朝向 / 择日 / 紫白），不新增依赖。
// 文案按「传统文化研究参考」定位，避免承诺性措辞（App Store 4.2/4.3 合规）。
public struct DSConclusionDashboard: View {
    @ObservedObject private var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    private let now: Date

    public init(now: Date = Date()) { self.now = now }

    private var state: CompassHeadingState { motion.headingState }
    private var kongwang: KongWangLevel { state.kongWangLevel }
    private var daily: ZeRiAnalysis { ZeRiEngine.shared.analyzeGeneralDay(date: now) }
    private var compassGods: ZeRiEngine.DailyCompassGodDirections {
        ZeRiEngine.shared.dailyCompassDirections(for: now)
    }
    private var sitFace: String {
        "\(state.sittingMountain.localizedName)\(lang.t("mountain_suffix"))\(state.facingMountain.localizedName)\(lang.t("facing_suffix"))"
    }
    private var kwBadge: (String, Color) {
        switch kongwang {
        case .pure: return (kongwang.localizedTitle, .semJi)
        case .jianXiang: return (kongwang.localizedTitle, .semWarn)
        case .smallVoid: return (kongwang.localizedTitle, .semWarn)
        case .largeVoid: return (kongwang.localizedTitle, .semXiong)
        }
    }
    private var timeText: String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short
        return f.string(from: now)
    }
    private var yiText: String { daily.yiActivities.prefix(4).joined(separator: "、") }
    private var jiText: String { daily.jiActivities.prefix(3).joined(separator: "、") }

    public var body: some View {
        // 单层卡片：标题 + 信息行，不再嵌套翻转卡/Pill/阴影。
        VStack(alignment: .leading, spacing: DS.padS) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.effectiveLanguage == .en ? "NOW · HERE · THIS DIRECTION" : "此 刻 · 此 地 · 此 向")
                        .adaptiveFont(size: DS.TypeScale.caption, weight: .semibold).foregroundColor(.goldText)
                    Text(sitFace)
                        .adaptiveFont(size: DS.TypeScale.title, weight: .bold, design: .rounded)
                        .foregroundColor(.paperText)
                }
                Spacer()
                DSStatusBadge(text: kwBadge.0, tint: kwBadge.1)
            }

            Divider().background(Color.strokeSoft)

            DSInfoRow(label: lang.effectiveLanguage == .en ? "Time" : "时间", value: timeText)
            DSInfoRow(label: lang.effectiveLanguage == .en ? "Calendar" : "历法参考",
                      value: yiText.isEmpty ? "—" : yiText, valueColor: .semJi)
            DSInfoRow(label: lang.effectiveLanguage == .en ? "Direction" : "方位参考",
                      value: "\(compassGods.wealthDirection) / \(compassGods.joyDirection)")
            DSInfoRow(label: lang.effectiveLanguage == .en ? "Fenjin / void" : "分金 / 空亡",
                      value: state.fenJinDesc.isEmpty ? kwBadge.0 : state.fenJinDesc, valueColor: .semInfo)

            // 依据默认隐藏，点开才显示（消除首屏信息过载）
            DSFoldableSection(title: lang.effectiveLanguage == .en ? "Basis" : "依据说明", defaultExpanded: false) {
                Text(daily.detailsText).adaptiveFont(size: DS.TypeScale.caption).foregroundColor(.paperSub)
                    .fixedSize(horizontal: false, vertical: true)
                Text(lang.effectiveLanguage == .en
                     ? "For traditional culture research reference only · Not for decision-making"
                     : "传统文化研究参考 · 不构成决策依据")
                    .adaptiveFont(size: 10).foregroundColor(.paperSub.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DS.padM)
        .background(Color.surfaceCard)
        .cornerRadius(DS.radiusM)
        .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(Color.strokeGold, lineWidth: 1))
    }
}

// MARK: - 通用方位结论条：分析页共用的「当前坐向 + 空亡 + 吉方」一行式结论
public struct DSOrientationConclusionBar: View {
    @ObservedObject private var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    public let moduleName: String

    public init(moduleName: String) { self.moduleName = moduleName }

    public var body: some View {
        let state = motion.headingState
        let kw = state.kongWangLevel
        return HStack(spacing: DS.padM) {
            Image(systemName: "location.north.line.fill").foregroundColor(.goldText)
                .adaptiveFont(size: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(moduleName).adaptiveFont(size: 10).foregroundColor(.secondary)
                Text("\(state.sittingMountain.localizedName)山\(state.facingMountain.localizedName)向 · \(state.fenJinDesc)")
                    .adaptiveFont(size: 13, weight: .semibold).foregroundColor(.primary)
                    .lineLimit(1).minimumScaleFactor(0.8)
            }
            Spacer(minLength: 4)
            DSStatusBadge(text: kw.localizedTitle,
                          tint: kw == .pure ? .semJi : (kw == .largeVoid ? .semXiong : .semWarn))
        }
        .padding(.horizontal, DS.padM)
        .padding(.vertical, DS.padS)
        .background(
            LinearGradient(colors: [Color.surfaceCard, Color.surfaceElevated],
                           startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(DS.radiusM)
        .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(Color.strokeGold, lineWidth: 1))
        .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3)
    }
}

// MARK: - iPad 与多设备全景屏幕字体自适应扩展 (Adaptive Typography)
extension Font {
    /// 当前前台窗口的 trait collection：字号（Dynamic Type）与尺寸类都取自同一个快照，
    /// 避免同一次 body 求值里两次扫 connectedScenes、且两者读数不一致。
    private static var currentTraits: UITraitCollection? {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }),
           let window = windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first {
            return window.traitCollection
        }
        return nil
    }

    /// Dynamic Type 额外放大系数（1.0 ... 1.3）。
    /// 取窗口 trait 的 `preferredContentSizeCategory`，用 body 文本样式的 17pt 基准换算出系统要求的放大比例；
    /// 上限 1.3 是刻意的：本工程大量容器是固定尺寸（24 山标签 30/36pt、十二长生表 90/110pt 列、
    /// 顶部 34pt 圆钮），跟随系统到无障碍最大字号（body 约 2.35x）会重新把这些容器撑破。
    /// 固定尺寸容器通过 `Font.dynamicTypeScale` 同步放大，保持"字 / 框"比例不变。
    public static var dynamicTypeScale: CGFloat {
        dynamicTypeScale(for: currentTraits ?? UITraitCollection.current)
    }

    private static func dynamicTypeScale(for traits: UITraitCollection) -> CGFloat {
        guard traits.preferredContentSizeCategory != .unspecified else { return 1.0 }
        let metrics = UIFontMetrics(forTextStyle: .body)
        let scaled = metrics.scaledValue(for: 17, compatibleWith: traits)
        let factor = scaled / 17
        guard factor.isFinite else { return 1.0 }
        return min(max(factor, 1.0), 1.3)
    }

    /// 全景自适应计算最优字体字号：
    /// 在 iPhone 上保持设计原始字号，在 iPad Pro / iPad Air / iPad mini 大屏上自动按 1.35x 比例智能放大，
    /// 确保罗盘刻度、度数、八方吉凶、户型体检、九宫飞星、系统设置等所有界面的文本层次均清晰可辨。
    public static func adaptive(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) -> Font {
        // 按“可用空间”而非设备 idiom 决定字体放大：水平尺寸类为 regular 时使用大屏
        // 比例（iPad 全形态、iPhone Duo 展开态内屏），紧凑宽度（常规 iPhone 与
        // iPhone Duo 外屏）保持原字号。苹果 iPhone Duo 适配要求禁用
        // userInterfaceIdiom 做布局决策，改用 size class / 可用空间。
        let traits = currentTraits ?? UITraitCollection.current
        let isLarge = traits.horizontalSizeClass == .regular
        let scale: CGFloat = isLarge ? 1.35 : 1.0
        // 系统字号（Dynamic Type）叠加在大屏比例之上，再按 dynamicTypeScale 的上限收敛。
        let scaledSize = (size * scale * dynamicTypeScale(for: traits)).rounded()
        return Font.system(size: scaledSize, weight: weight, design: design)
    }

    public static func adaptive(size: CGFloat, design: Font.Design) -> Font {
        adaptive(size: size, weight: .regular, design: design)
    }
}

// MARK: - 环境驱动的自适应字号（Environment-driven Adaptive Typography）
//
// 为什么不再用 `Font.adaptive(...)`：
// 它是在 body 求值时**扫 connectedScenes** 取「第一个前台场景 key window」的 trait。
// 单窗口下没问题；但 iPad Stage Manager / 分屏开两个窗口且宽度不同时，
// 字号会以先到的场景为准（另一个窗口的字号与自己的宽度不匹配），而且 500+ 处文本
// 每次求值都要重建 UIFontMetrics。
//
// 现在改为 ViewModifier：水平尺寸类与系统字号都来自**当前视图所在场景**的
// `Environment`，每个窗口各取各的；缩放系数按「尺寸类 × 字号档」缓存，求值零成本。
// 全部调用点已是 `.adaptiveFont(size:weight:design:)`。
public enum AdaptiveFontMetrics {
    /// 宽屏（regular 宽度：iPad 全形态 / Duo 内屏）的大屏放大比例。
    public static let regularWidthScale: CGFloat = 1.35
    /// Dynamic Type 放大比例：直接跟随系统「文字大小」（default 1.0，辅助功能最大约 2.35x）。
    /// 不再人为封顶——各固定尺寸容器（24 山标签、顶部度数、VIP 卡等）已用
    /// `minimumScaleFactor` / 随 dynamicTypeScale 同步放大的 frame 自行兜底，避免溢出。

    private static var cache: [String: CGFloat] = [:]
    private static let cacheLock = NSLock()

    public static func contentSizeCategory(for dynamicType: DynamicTypeSize) -> UIContentSizeCategory {
        switch dynamicType {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        default: return .large
        }
    }

    /// 系统字号要求的放大比例（1.0 ... 1.3），带缓存。
    public static func dynamicTypeScale(for dynamicType: DynamicTypeSize) -> CGFloat {
        let category = contentSizeCategory(for: dynamicType)
        let key = category.rawValue
        cacheLock.lock()
        if let cached = cache[key] {
            cacheLock.unlock()
            return cached
        }
        cacheLock.unlock()

        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let factor = UIFontMetrics(forTextStyle: .body).scaledValue(for: 17, compatibleWith: traits) / 17
        let scale = factor.isFinite ? max(factor, 1.0) : 1.0

        cacheLock.lock()
        cache[key] = scale
        cacheLock.unlock()
        return scale
    }

    /// 宽屏比例（只由尺寸类决定）。
    public static func layoutScale(sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass == .regular ? regularWidthScale : 1.0
    }

    /// 最终字号 = 设计字号 × 宽屏比例 × 系统字号比例。
    public static func scaledSize(_ size: CGFloat,
                                  sizeClass: UserInterfaceSizeClass?,
                                  dynamicType: DynamicTypeSize) -> CGFloat {
        (size * layoutScale(sizeClass: sizeClass) * dynamicTypeScale(for: dynamicType)).rounded()
    }
}

/// 分栏两栏内的字号系数。默认是 1.0（单列态）。
/// 展开态左右栏各自只有整屏的一部分，若仍套用 regular 的 1.35x 宽屏放大，
/// 泰语/越南语/印尼语长词会被逐字折断、HStack 里的标题与徽章互相穿插。
/// 由 FoldableTwoPane 注入 1/regularWidthScale 抵消放大，符合「内屏用多出的
/// 空间显示更多内容，而不是简单放大字号和卡片」。
private struct PaneTypographyScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

public extension EnvironmentValues {
    var paneTypographyScale: CGFloat {
        get { self[PaneTypographyScaleKey.self] }
        set { self[PaneTypographyScaleKey.self] = newValue }
    }
}

/// 分栏容器内抵消 regular 宽屏字号放大的系数（对外只读）。
public enum AdaptivePaneTypography {
    public static let scaleInSplitPane: CGFloat = 1.0 / AdaptiveFontMetrics.regularWidthScale
}

public struct AdaptiveFontModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.paneTypographyScale) private var paneTypographyScale

    private let size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    public init(size: CGFloat, weight: Font.Weight = .regular, design: Font.Design = .default) {
        self.size = size
        self.weight = weight
        self.design = design
    }

    public func body(content: Content) -> some View {
        let scaled = AdaptiveFontMetrics.scaledSize(size,
                                                    sizeClass: horizontalSizeClass,
                                                    dynamicType: dynamicTypeSize)
        let paneScaled = (scaled * paneTypographyScale).rounded()
        return content.font(.system(size: paneScaled, weight: weight, design: design))
    }
}

public extension View {
    /// 替代旧的 `.font(.adaptive(size:...))`：
    /// 尺寸类与系统字号取自当前视图所在场景，支持多窗口各取各的。
    func adaptiveFont(size: CGFloat,
                      weight: Font.Weight = .regular,
                      design: Font.Design = .default) -> some View {
        modifier(AdaptiveFontModifier(size: size, weight: weight, design: design))
    }
}


// MARK: - 布局形态判定 (Adaptive Layout Form)
//
// 适配依据（Apple Tech Talks / iPhone Duo 适配方案）：
//   · 布局只依赖**当前 Window / Scene 的有效几何**：Size Class、Safe Area、窗口尺寸。
//     不按机型常量、不按铰链角度、不缓存首次几何值。
//   · 外屏（合上）整体接近传统 iPhone 的 compact 体验 → 与普通 iPhone 完全一致的单列。
//   · 内屏（展开）通常是 regular / regular 的更大空间 → 用多出的横向空间做左右双栏，
//     而不是把单列的元素等比放大。
//   · 「是否分栏」表达的是「当前空间是否足以并排两块内容」，不是「设备是否展开」；
//     开合只是几何变化的输入，不参与基础布局判断。
//
// 产品口径：
//   · iPhone Duo 展开内屏 → 左右双栏；合上外屏 / 常规 iPhone → 上下单列（普通 iPhone 口径）。
//   · iPad 界面横屏 → 与 Duo 内屏一致的左右双栏；iPad 竖屏 / 分屏窄窗 → 上下单列。
//   · `userInterfaceIdiom` 只用于区分设备族（iPad 与 iPhone Duo），不决定任何尺寸；
//     iPad 的接口方向沿用既有产品口径，Duo 一律用 Size Class 判定。
public enum AdaptiveLayout {
    /// 左栏画板保持可读的最小宽度（pt）。低于此值时 24 山/64 卦/节气环的文字会互相压叠。
    public static let minimumMainPaneWidth: CGFloat = 420
    /// 右栏解释文本保持可读的最小宽度（pt）。低于此值时印尼语/泰语长词会被逐字折断，
    /// HStack 里的标题与徽章会挤成一团。
    public static let minimumAnalysisPaneWidth: CGFloat = 360
    /// 并排两栏所需的最小有效宽度 = 两栏各自可读下限 + 1pt 分隔线。
    /// 这不是机型尺寸常量，而是「当前空间是否足以并排两块内容」的可读性表达
    ///（Apple Tech Talks：应表达空间是否足以展示双列，而非设备型号/开合布尔）。
    public static var twoPaneReadableWidth: CGFloat {
        minimumMainPaneWidth + minimumAnalysisPaneWidth + 1
    }
    /// iPad 沿用既有的 900pt 口径（排除分屏 / 侧拉窄窗），取两者较大值。
    private static var twoPaneMinimumWidth: CGFloat {
        max(900, twoPaneReadableWidth)
    }

    /// 左右双栏：展开态且「有效宽度足以让两栏各自可读」时才成立。
    public static func isTwoPane(horizontal: UserInterfaceSizeClass?,
                                vertical: UserInterfaceSizeClass?,
                                form: AdaptiveLayoutForm) -> Bool {
        // 合上外屏 / 常规 iPhone / 分屏窄窗：水平 compact 一律单列。
        // 此时各页 isWide(sizeClass:) 同为 false，画布、控件、字号全部走普通 iPhone 口径，
        // 不会变成「手机放大版」——这正是「合上时与普通 iPhone 一样」的保证。
        guard horizontal == .regular else { return false }
        // 展开形态成立，但可用宽度不足以并排两块可读内容时仍回退单列。
        // 竖持的展开内屏、部分折叠、Split View 窄窗都会走这里，避免文字重叠。
        guard form.size.width >= twoPaneMinimumWidth else { return false }
        if form.isPhoneIdiom {
            // iPhone Duo：展开内屏是 regular/regular；合上外屏或普通大屏 iPhone 横屏
            // 的垂直尺寸类是 compact，必须回退单列。不依赖 interfaceOrientation。
            return vertical == .regular
        }
        // iPad：保留「界面横屏才分栏」的产品口径；竖屏 / 分屏窄窗不分栏。
        return form.isLandscape
    }

    /// 便捷重载：垂直尺寸类取布局快照中由根视图实时注入的值。
    public static func isTwoPane(sizeClass: UserInterfaceSizeClass?, form: AdaptiveLayoutForm) -> Bool {
        isTwoPane(horizontal: sizeClass, vertical: form.verticalSizeClass, form: form)
    }

    /// 宽屏（iPad 全形态 + Duo 内屏）：只决定“更大”，不决定“是否分栏”。
    public static func isWide(sizeClass: UserInterfaceSizeClass?) -> Bool {
        sizeClass == .regular
    }

    /// 左栏占比随有效宽度自适应：窄展开屏把更多空间留给画布，宽屏收敛让右栏解释够宽。
    /// 各页不再各自硬编码 0.55/0.56/0.58/0.60，画布才能按左栏实际占比铺满。
    /// 同时硬性保证右栏不小于 minimumAnalysisPaneWidth，避免长词被逐字折断。
    public static func mainColumnRatio(forWidth width: CGFloat) -> CGFloat {
        guard width > 0 else { return 0.6 }
        let t = min(max((width - 900) / 500, 0), 1)
        let curved = 0.62 - 0.07 * t
        let analysisFloor = (minimumAnalysisPaneWidth + 1) / width
        return min(max(curved, 0.5), max(0.5, 1 - analysisFloor))
    }

    /// 当前有效宽度下左栏的真实可用宽度（扣掉 1pt 分隔线）。
    /// 各页画布用它替代「整屏宽 × 猜测比例 - 32」与 720/900/1320 等固定上限，
    /// 保证画板按左栏占比自适应并铺满；开合、旋转、Split View 时随几何连续变化。
    public static func mainPaneWidth(totalWidth: CGFloat) -> CGFloat {
        max(0, totalWidth * mainColumnRatio(forWidth: totalWidth) - 1)
    }
}

// MARK: - 布局环境值 (Adaptive Layout Form)
//
// 取代全局可变单例：全部由 SwiftUI Environment 同步注入。
// 好处：旋转时不滞后一帧、非活动 Tab 不会被全局对象强制重绘、
// 方向与设备族随窗口一起刷新（不再在 body 里查 UIDevice 全局状态）。
public struct AdaptiveLayoutForm: Equatable {
    /// 根视图可用窗口尺寸（来自 GeometryReader）
    public let size: CGSize
    /// 真实界面方向；`interfaceOrientation == .unknown` 时回退宽高比
    public let isLandscape: Bool
    /// 设备族：仅用于区分 iPhone Duo 内屏与 iPad，不参与尺寸决策
    public let isPhoneIdiom: Bool
    /// 当前视图所在 Window / Scene 的垂直尺寸类（由 SwiftUI Environment 注入）。
    /// Duo 合上外屏与普通 iPhone 横屏都是 compact，展开内屏为 regular。
    public let verticalSizeClass: UserInterfaceSizeClass?

    public init(size: CGSize = .zero,
                isLandscape: Bool = false,
                isPhoneIdiom: Bool = false,
                verticalSizeClass: UserInterfaceSizeClass? = nil) {
        self.size = size
        self.isLandscape = isLandscape
        self.isPhoneIdiom = isPhoneIdiom
        self.verticalSizeClass = verticalSizeClass
    }

    /// 从当前 UIWindowScene 读取方向、设备族与窗口尺寸。
    /// - Parameter size: GeometryReader 给出的根视图尺寸（优先使用）。
    /// - Parameter verticalSizeClass: 当前视图所在 Scene 的垂直尺寸类（SwiftUI Environment）。
    public static func current(size: CGSize = .zero,
                               verticalSizeClass: UserInterfaceSizeClass? = nil) -> AdaptiveLayoutForm {
        var windowSize = size
        var isLandscape = false
        var isPhoneIdiom = false

        if let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive
                            || $0.activationState == .foregroundInactive }),
           let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first {
            if windowSize == .zero { windowSize = window.bounds.size }
            // iPhone Duo / 可缩放窗口下，窗口的形状由当前 bounds 宽高比决定，
            // scene.interfaceOrientation 在折叠/展开瞬间会滞后甚至上报旧值；
            // 按 Apple「Prepare for iPhone Duo」指南：布局只看当前空间的宽高比，
            // interfaceOrientation 仅作 windowSize 尚未就绪时的兜底。
            isLandscape = windowSize.width > windowSize.height
            if windowSize == .zero {
                isLandscape = scene.interfaceOrientation.isLandscape
            }
            isPhoneIdiom = window.traitCollection.userInterfaceIdiom == .phone
        } else {
            isLandscape = windowSize.width > windowSize.height
        }

        // CI 截图兜底：Xcode 27 的 Device Hub 常不响应 AppleScript 旋转，
        // 此时用启动参数强制按「横屏分栏」渲染，以便仍能验证双栏布局。
        // 正常启动不带该参数，App Store 包行为完全不受影响。
        let forcedLandscape = CommandLine.arguments.contains("-forceLandscapeLayout")
        if forcedLandscape {
            // 设备像素仍是竖屏，但布局要按横屏可用空间计算（两栏高度、宽度上限等），
            // 交换宽高后 -forceLandscapeLayout 的截图与真旋转结果一致。
            windowSize = CGSize(width: windowSize.height, height: windowSize.width)
        }
        return AdaptiveLayoutForm(size: windowSize,
                                  isLandscape: forcedLandscape || isLandscape,
                                  isPhoneIdiom: isPhoneIdiom,
                                  verticalSizeClass: verticalSizeClass)
    }
}

private struct AdaptiveLayoutFormKey: EnvironmentKey {
    static let defaultValue = AdaptiveLayoutForm()
}

public extension EnvironmentValues {
    var adaptiveLayoutForm: AdaptiveLayoutForm {
        get { self[AdaptiveLayoutFormKey.self] }
        set { self[AdaptiveLayoutFormKey.self] = newValue }
    }
}

// MARK: - 展开态双栏容器 (Foldable Two-Pane Adaptive Layout)
//
// 分栏形态（iPhone Duo 展开内屏 / iPad 横屏，判据见 AdaptiveLayout.isTwoPane）：
//   左栏 = 主交互区（罗盘盘面 / AR 取景 / 户型画布 / 九宫排盘），宽度 ≈ 全宽 55~60%，
//          盘面/画布按左栏可用尺寸自适应（不再按整屏尺寸计算）。
//   右栏 = 分析解释区（分金歌诀 / 形煞研判 / 体检报告 / 格局评析），中间细分隔线。
// 单列形态（常规 iPhone、Duo 折叠外屏、iPad 竖屏 / 分屏窄窗）：
//   保持上下单列，分析区紧随主区之后，画布/内容按宽屏尺寸放大
//   （尺寸口径由各页 isLargeLayout 控制）。
public struct FoldableTwoPane<Main: View, Analysis: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// 布局环境值：界面方向 / 窗口尺寸 / 设备族，随旋转同步刷新。
    @Environment(\.adaptiveLayoutForm) private var layoutForm

    /// 展开态左栏（主交互区）占整宽比例。`nil` 时按当前有效宽度自动计算。
    private let requestedMainColumnRatio: CGFloat?
    /// 折叠态纵向排布间距（须与调用方原布局 VStack spacing 一致）。
    private let compactSpacing: CGFloat
    /// 展开态右栏底色（与各 Tab 深色底一致）。
    private let analysisBackground: Color
    /// 展开态右栏内容的纵向对齐（默认顶部，符合阅读习惯；不影响折叠态）。
    private let analysisAlignment: Alignment
    /// 外层为 ScrollView 的长报告页：两栏各自独立滚动（见 independentScrollPanes）。
    private let independentScroll: Bool

    private let main: Main
    private let analysis: Analysis

    public init(mainColumnRatio: CGFloat? = nil,
                compactSpacing: CGFloat = 8,
                analysisBackground: Color = Color.screenInk,
                analysisAlignment: Alignment = .top,
                independentScroll: Bool = false,
                @ViewBuilder main: () -> Main,
                @ViewBuilder analysis: () -> Analysis) {
        // 保留调用方显式比例（并夹到可读区间）；不传时由 AdaptiveLayout 按有效宽度自适应。
        self.requestedMainColumnRatio = mainColumnRatio.map { min(max($0, 0.5), 0.7) }
        self.compactSpacing = compactSpacing
        self.analysisBackground = analysisBackground
        self.analysisAlignment = analysisAlignment
        self.independentScroll = independentScroll
        self.main = main()
        self.analysis = analysis()
    }

    /// 当前这次渲染真正使用的左栏占比。
    private var mainColumnRatio: CGFloat {
        requestedMainColumnRatio
            ?? AdaptiveLayout.mainColumnRatio(forWidth: layoutForm.size.width)
    }

    private var isSplitHere: Bool {
        // 垂直尺寸类直接取本视图的 Environment，不用可能滞后一帧的快照，
        // 保证开合 / 分屏 / Split View 变化时同帧切换。
        AdaptiveLayout.isTwoPane(horizontal: horizontalSizeClass,
                                 vertical: verticalSizeClass,
                                 form: layoutForm)
    }

    public var body: some View {
        if isSplitHere {
            // 两栏各自只占整屏一部分：抵消 regular 的 1.35x 字号放大，
            // 避免国际化长词被逐字折断、标题与徽章互相穿插。所有页面共用一个系数。
            Group {
                if independentScroll {
                    independentScrollPanes
                } else {
                    standardPanes
                }
            }
            .environment(\.paneTypographyScale, AdaptivePaneTypography.scaleInSplitPane)
        } else {
            // 合上外屏 / 常规 iPhone / 窄窗：与普通 iPhone 完全一致的单列纵排。
            VStack(spacing: compactSpacing) {
                main
                analysis
            }
        }
    }

    /// 常规分栏：用于整屏/固定高度场景（罗盘、AR、户型），调用方自行给右栏滚动能力。
    private var standardPanes: some View {
        ProportionalTwoPaneLayout(mainRatio: mainColumnRatio) {
            main
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .safeAreaInset(edge: .bottom) {
                    // iOS 27 浮动 TabBar 不占用 safe area，会盖住两栏底部内容
                    Color.clear.frame(height: 72)
                }

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1)

            analysis
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: analysisAlignment)
                .background(analysisBackground)
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: 72)
                }
        }
    }

    /// 独立滚动分栏：两栏各自滚动，避免「右栏长解释把整页撑长、左栏画板跟着一起滚」。
    /// 高度来自布局环境值（根视图 GeometryReader 实时刷新，不缓存首次几何），
    /// 扣掉子 Tab 栏与上下留白，保证两栏落在可视区内并各自铺满。
    private var independentScrollPanes: some View {
        let paneHeight = max(320, layoutForm.size.height - 140)
        return ProportionalTwoPaneLayout(mainRatio: mainColumnRatio) {
            ScrollView {
                main
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
            .frame(height: paneHeight)

            Rectangle()
                .fill(Color.white.opacity(0.10))
                .frame(width: 1, height: paneHeight)

            ScrollView {
                analysis
                    .frame(maxWidth: .infinity)
                    // 浮动 TabBar 会盖住右栏末尾；留出可滚到底的余量
                    .padding(.bottom, 72)
            }
            .frame(maxWidth: .infinity)
            .frame(height: paneHeight)
            .background(analysisBackground)
        }
    }
}

// MARK: - 展开态双栏按比例布局 (iOS 16 Layout 协议)
//
// 不用 GeometryReader：外层 ScrollView 场景下 GeometryReader 会把容器高度
// 钉死在视口高度，导致较高的分析内容被裁切且无法滚动；自定义 Layout 以
// 两栏理想高度的最大值作为容器高度，整屏固定高度与 ScrollView 自然高度
// 两种场景均正确，并按 mainColumnRatio 精确分配左右栏宽度。
// 模块内共享：ARVisionView 折叠态是全屏取景 + HUD 悬浮布局（不适用
// FoldableTwoPane 的纵排折叠分支），其展开态直接复用本 Layout。
struct ProportionalTwoPaneLayout: Layout {
    let mainRatio: CGFloat

    private func paneWidths(total: CGFloat) -> (main: CGFloat, analysis: CGFloat) {
        let divider: CGFloat = 1
        let mainW = max(0, total * mainRatio - divider / 2)
        let analysisW = max(0, total - mainW - divider)
        return (mainW, analysisW)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else {
            // 调用方必须传"主栏 + 1pt 分隔线 + 分析栏"三元组；子视图数不对时
            // Debug 构建直接断言暴露，Release 静默返回零尺寸（不崩溃）。
            assertionFailure("ProportionalTwoPaneLayout 需要恰好 3 个子视图：主栏、分隔线、分析栏")
            return .zero
        }
        let width = proposal.width ?? subviews.reduce(0) { $0 + $1.sizeThatFits(.unspecified).width }
        let (mainW, analysisW) = paneWidths(total: width)
        let mainH = subviews[0].sizeThatFits(ProposedViewSize(width: mainW, height: proposal.height)).height
        let analysisH = subviews[2].sizeThatFits(ProposedViewSize(width: analysisW, height: proposal.height)).height
        return CGSize(width: width, height: max(mainH, analysisH))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else {
            assertionFailure("ProportionalTwoPaneLayout 需要恰好 3 个子视图：主栏、分隔线、分析栏")
            return
        }
        let (mainW, analysisW) = paneWidths(total: bounds.width)
        let paneHeight = proposal.height ?? bounds.height
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            proposal: ProposedViewSize(width: mainW, height: paneHeight)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + mainW, y: bounds.minY),
            proposal: ProposedViewSize(width: 1, height: paneHeight)
        )
        subviews[2].place(
            at: CGPoint(x: bounds.minX + mainW + 1, y: bounds.minY),
            proposal: ProposedViewSize(width: analysisW, height: paneHeight)
        )
    }
}


// MARK: - 天机演象 纯原生 SwiftUI 根视图 (Root Content View - PRD 5.0 标准五大场景)

public struct RootContentView: View {
    private let motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var route: HomeRoute?
    @State private var analysisSubTab: Int = 0
    @State private var analysisFeatureRequest: AnalysisFeatureRequest?
    @State private var showWorkflowReportSheet: Bool = false
    // 读取 size class 建立环境依赖：折叠/展开（或 iPad 分屏拖动）切换时本视图
    // 重渲染并级联子视图 body 重算，使 Font.adaptive 的静态查询同步刷新
    //（配合 body 尾部 onChange 一起生效）。
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// 垂直尺寸类：Duo 合上外屏 / 普通 iPhone 横屏为 compact，展开内屏为 regular。
    /// 与水平尺寸类一起作为「空间是否足以并排两栏」的唯一布局依据。
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    // 读取 Dynamic Type 环境值建立依赖：系统「文字大小」变化时根视图重算 body，
    // 级联刷新 Font.adaptive（它按窗口 trait 计算，不读环境值，需要这里触发）。
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// 注入给所有子视图的布局环境值（窗口尺寸 / 界面方向 / 设备族 / 垂直尺寸类）。
    @State private var layoutForm = AdaptiveLayoutForm.current()
    
    public init() {
        var initialRoute: HomeRoute? = nil
        if let tabArgIndex = CommandLine.arguments.firstIndex(of: "-selectedTab"),
           tabArgIndex + 1 < CommandLine.arguments.count,
           let tabValue = Int(CommandLine.arguments[tabArgIndex + 1]) {
            let clamped = Self.clampedTabIndex(tabValue)
            initialRoute = HomeRoute(rawValue: clamped)
        }
        _route = State(initialValue: initialRoute)

        // 自定义原生 TabBar 深色黑金质感外观（折叠/展开切换时 onChange 会重调以刷新字号）
        Self.applyTabBarAppearance(isLargeLayout: UITraitCollection.current.horizontalSizeClass == .regular)
    }

    private static func clampedTabIndex(_ raw: Int) -> Int {
        max(0, min(4, raw))
    }

    /// 同步刷新布局环境值：只在值真正变化时写 @State，避免无谓重绘。
    /// 开合、旋转、Split View、Safe Area 变化时几何会连续变化，这里每次都重算，
    /// 不缓存首次出现时的窗口尺寸 / 尺寸类。
    private func refreshLayoutForm(size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let next = AdaptiveLayoutForm.current(size: size,
                                              verticalSizeClass: verticalSizeClass)
        if next != layoutForm { layoutForm = next }
    }

    /// 尺寸类变化但窗口尺寸不变时（开合 / 分屏）也要重算快照。
    private func refreshLayoutFormKeepingSize() {
        let next = AdaptiveLayoutForm.current(size: layoutForm.size,
                                              verticalSizeClass: verticalSizeClass)
        if next != layoutForm { layoutForm = next }
    }

    /// 构建黑金深色 TabBar 外观：应用到 appearance proxy，并同步刷新
    /// 已挂载的 UITabBar 实例与条目字号（appearance proxy 不影响已创建的 bar）。
    private static func applyTabBarAppearance(isLargeLayout: Bool) {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        // 暖墨底色，与卡片表面同系
        appearance.backgroundColor = UIColor(red: 22/255.0, green: 19/255.0, blue: 15/255.0, alpha: 1.0)

        let itemAppearance = UITabBarItemAppearance()
        // Tab 标签是 UIKit 固定字号，不会自动跟随 Dynamic Type：用 UIFontMetrics 补齐，
        // 并给 maximumPointSize = 1.3x 上限，避免放大后撑出 49pt 的 TabBar 高度。
        // 统一古金 + 提升小屏 Tab 字号到 11.5pt（原 10pt 与正文说明同级，主次不清）
        let tabGold = UIColor(red: 205/255.0, green: 161/255.0, blue: 79/255.0, alpha: 1.0)
        let tabNormal = UIColor(red: 169/255.0, green: 156/255.0, blue: 128/255.0, alpha: 1.0)
        let baseTabFontSize: CGFloat = isLargeLayout ? 13 : 11.5
        let tabFont = UIFontMetrics(forTextStyle: .caption1)
            .scaledFont(for: UIFont.systemFont(ofSize: baseTabFontSize, weight: .semibold),
                        maximumPointSize: baseTabFontSize * 1.3)
        itemAppearance.normal.iconColor = tabNormal
        itemAppearance.normal.titleTextAttributes = [
            .foregroundColor: tabNormal,
            .font: tabFont
        ]

        itemAppearance.selected.iconColor = tabGold
        itemAppearance.selected.titleTextAttributes = [
            .foregroundColor: tabGold,
            .font: tabFont
        ]

        appearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }

        // 实时刷新已挂载的 TabBar（SwiftUI TabView 的宿主 UITabBarController 已创建）
        let selectedColor = tabGold
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                Self.refreshTabBars(in: window, appearance: appearance, normalFont: tabFont, selectedColor: selectedColor)
            }
        }
    }

    private static func refreshTabBars(in view: UIView,
                                       appearance: UITabBarAppearance,
                                       normalFont: UIFont,
                                       selectedColor: UIColor) {
        if let tabBar = view as? UITabBar {
            tabBar.standardAppearance = appearance
            if #available(iOS 15.0, *) {
                tabBar.scrollEdgeAppearance = appearance
            }
            tabBar.items?.forEach { item in
                item.setTitleTextAttributes(
                    [.foregroundColor: UIColor(red: 169/255.0, green: 156/255.0, blue: 128/255.0, alpha: 1.0), .font: normalFont],
                    for: .normal
                )
                item.setTitleTextAttributes(
                    [.foregroundColor: selectedColor, .font: normalFont],
                    for: .selected
                )
            }
        }
        view.subviews.forEach {
            Self.refreshTabBars(in: $0, appearance: appearance, normalFont: normalFont, selectedColor: selectedColor)
        }
    }
    
    public var body: some View {
        NavigationStack {
            HomeHubView(route: $route)
                .navigationDestination(item: $route) { target in
                    destinationView(for: target)
                }
        }
        .accentColor(Color.goldText)
        .preferredColorScheme(.dark)
        // 采集真实窗口尺寸并同步注入 Environment：iPad 旋转不改变 size class，
        // 各页靠 interfaceOrientation + 尺寸切换「横屏双栏 / 竖屏单列」。
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { refreshLayoutForm(size: geo.size) }
                    .onChange(of: geo.size) { newSize in
                        refreshLayoutForm(size: newSize)
                    }
            }
        )
        .environment(\.adaptiveLayoutForm, layoutForm)
        .onChange(of: verticalSizeClass) { _ in
            // 开合/分屏可能只改尺寸类不改窗口尺寸：此时几何探针的 onChange 不会触发，
            // 必须单独刷新快照，否则分栏判据会滞后一帧甚至停在旧形态。
            refreshLayoutFormKeepingSize()
        }
        .onChange(of: horizontalSizeClass) { newValue in
            refreshLayoutFormKeepingSize()
            // 折叠/展开（或 iPad 分屏拖动）切换：重建 TabBar 外观刷新 Tab 字号；
            // 本视图因依赖 size class 而重渲染，级联子视图 body 重算，
            // 使 Font.adaptive 的静态查询同步更新 1.0x ↔ 1.35x 字号比例。
            Self.applyTabBarAppearance(isLargeLayout: newValue == .regular)
        }
        .onChange(of: dynamicTypeSize) { _ in
            // 系统「文字大小」变化：本视图已因读取该环境值而重渲染，
            // 这里再把 UIKit 侧已挂载的 TabBar 字号刷新一遍（UITabBar 不跟随 Dynamic Type）。
            Self.applyTabBarAppearance(isLargeLayout: horizontalSizeClass == .regular)
        }
        .onAppear {
            Self.applyTabBarAppearance(isLargeLayout: horizontalSizeClass == .regular)
            updateResourceUsage()
            RetentionServiceManager.shared.registerSystemShortcutsAndSpotlight()
        }
        .sheet(isPresented: $showWorkflowReportSheet) {
            IntegratedWorkflowReportSheet()
        }
        .onChange(of: route) { _ in
            updateResourceUsage()
        }
        .onAppear {
            consumePendingAlmanacRoute()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didTapAlmanacWidget)) { _ in
            consumePendingAlmanacRoute()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRequestAppNavigation).receive(on: DispatchQueue.main)) { _ in
            consumePendingAlmanacRoute()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didRequestWorkflowReport).receive(on: DispatchQueue.main)) { _ in
            showWorkflowReportSheet = true
        }
        .onOpenURL { url in
            SceneDelegate.routeWidgetURL(url)
            consumePendingAlmanacRoute()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            updateResourceUsage()
            motion.resumeIfSensorsEnabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            motion.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    /// 消费深链与主屏快捷入口的待处理意图（幂等）。
    private func consumePendingAlmanacRoute() {
        if AppNavigationRouter.shared.consumeAlmanac() {
            route = .floorplan
        }
        if let tabRoute = AppNavigationRouter.shared.consumeTabRoute() {
            let idx = Self.clampedTabIndex(tabRoute.tab)
            route = HomeRoute(rawValue: idx) ?? .floorplan
            if let sub = tabRoute.subTab {
                analysisSubTab = sub
            }
            if route == .analysis, let feature = tabRoute.feature ?? tabRoute.subTab.flatMap(AnalysisFeature.fromLegacySubTab) {
                if feature == .xuanKong || feature == .baZhai || feature == .sanHe || feature == .qimen {
                    analysisFeatureRequest = AnalysisFeatureRequest(feature: feature)
                }
            }
        }
    }

    /// AR 测绘（Tab 1）与方位仪（Tab 2）保持常亮和双轴姿态流；设置页（Tab 4）关闭传感器。
    private func updateResourceUsage() {
        let activeSceneCount = UIApplication.shared.connectedScenes
            .filter { $0.activationState == .foregroundActive }
            .count
        let multipleActiveScenes = activeSceneCount > 1
        let active = route?.rawValue
        UIApplication.shared.isIdleTimerDisabled = multipleActiveScenes || active == 1 || active == 2
        motion.setDeviceMotionEnabled(multipleActiveScenes || active == 1 || active == 2)
        motion.setHeadingUpdatesEnabled(multipleActiveScenes || active != 4)
        motion.resumeIfSensorsEnabled()
    }

    /// 首页图标推入对应的功能页。
    @ViewBuilder
    private func destinationView(for target: HomeRoute) -> some View {
        switch target {
        case .floorplan:
            FloorplanView(isActive: true)
        case .ar:
            ARSurveyTabHostView(isActive: true)
        case .compass:
            CompassMainView(isActive: true)
        case .analysis:
            XuanKongGridView(isActive: true,
                             selectedSubTab: $analysisSubTab,
                             featureRequest: $analysisFeatureRequest)
        case .settings:
            SettingsView(isActive: true)
        }
    }
}

/// 首页功能入口路由：rawValue 与旧版五标签下标一一对应。
private enum HomeRoute: Int, CaseIterable, Hashable {
    case floorplan
    case ar
    case compass
    case analysis
    case settings

    var systemImage: String {
        switch self {
        case .floorplan: "house.fill"
        case .ar: "camera.viewfinder"
        case .compass: "safari.fill"
        case .analysis: "square.grid.3x3.fill"
        case .settings: "gearshape.fill"
        }
    }

    var titleKey: String {
        switch self {
        case .floorplan: "tab_floorplan"
        case .ar: "tab_ar"
        case .compass: "tab_compass"
        case .analysis: "tab_analysis"
        case .settings: "tab_settings"
        }
    }
}

/// 首页图标宫格：点按图标推入对应功能页（开源 GridStack 布局）。
private struct HomeHubView: View {
    @Binding var route: HomeRoute?
    @ObservedObject private var lang = LocalizationManager.shared

    private var brandTitle: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "TianJi Space"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.padL) {
            Text(brandTitle)
                .adaptiveFont(size: DS.TypeScale.title, weight: .bold)
                .foregroundColor(Color.paperText)
                .padding(.horizontal, DS.padL)
                .padding(.top, DS.padL)

            GridStack(minCellWidth: 84, spacing: DS.padM, numItems: HomeRoute.allCases.count) { index, cellWidth in
                let target = HomeRoute.allCases[index]
                Button {
                    route = target
                } label: {
                    hubTile(target: target)
                        .frame(width: cellWidth)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(lang.t(target.titleKey))
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color.screenInk)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hubTile(target: HomeRoute) -> some View {
        VStack(spacing: DS.padS) {
            ZStack {
                RoundedRectangle(cornerRadius: DS.radiusM)
                    .fill(Color.surfaceElevated)
                    .frame(width: 64, height: 64)
                Image(systemName: target.systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Color.goldText)
            }
            Text(lang.t(target.titleKey))
                .adaptiveFont(size: DS.TypeScale.sub, weight: .semibold)
                .foregroundColor(Color.paperText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - 相机独占租约（多窗口互斥）
//
// 问题：iPad Stage Manager / 分屏同时开两个窗口并都停在相机页面时，两路
// AVCaptureSession / ARSession / RoomCaptureSession 会争用系统独占的摄像头，
// 后开的一路表现为「起不来 / 反复重连 / 黑屏」，且系统不给任何可读错误。
//
// 方案：应用层租约。
//   · **同一窗口内允许接管**：相机页之间本来就是互斥关系（后开的会把前一个停掉，
//     见 ARSpatialSurveyModel 里 "existing camera based AR screen and this object are
//     never active together"），若同窗口也拒绝，会把「相机页 + 测绘全屏页」这种正常
//     用法挡在门外。
//   · **跨窗口则拒绝**：另一个窗口正用着相机时，本窗口不启动任何采集会话，
//     改为显示一张提示卡；对方释放后自动接管。
public final class CameraExclusivity: ObservableObject {
    public static let shared = CameraExclusivity()

    /// 当前占用者所在窗口场景（UI 侧只读镜像，用于判断提示卡什么时候该撤掉）。
    @Published public private(set) var holderSceneID: ObjectIdentifier?

    private weak var holder: AnyObject?
    private var holderScene: ObjectIdentifier?
    private let lock = NSLock()

    /// 申请相机使用权。同窗口的申请会接管；跨窗口返回 false。
    public func acquire(_ owner: AnyObject, sceneID: ObjectIdentifier?) -> Bool {
        lock.lock()
        if holder === owner, holderScene == sceneID { lock.unlock(); return true }
        if let current = holder, current !== owner,
           let currentScene = holderScene, let targetScene = sceneID,
           currentScene != targetScene {
            lock.unlock()
            return false
        }
        holder = owner
        holderScene = sceneID
        let scene = sceneID
        lock.unlock()

        if Thread.isMainThread {
            holderSceneID = scene
        } else {
            DispatchQueue.main.async { self.holderSceneID = scene }
        }
        return true
    }

    public func release(_ owner: AnyObject) {
        lock.lock()
        guard let current = holder, current === owner else {
            lock.unlock()
            return
        }
        holder = nil
        holderScene = nil
        lock.unlock()

        if Thread.isMainThread {
            holderSceneID = nil
        } else {
            DispatchQueue.main.async { self.holderSceneID = nil }
        }
    }

    public func owns(_ owner: AnyObject) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return holder === owner
    }

    /// 相机是否被**别的窗口**占着。
    public func isBusy(for sceneID: ObjectIdentifier?) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard let currentScene = holderScene, let target = sceneID else { return false }
        return currentScene != target
    }
}

/// 只用来当租约 owner 的占位对象：SwiftUI 的 @State 里保持稳定引用，
/// 视图销毁时自动 dealloc，租约的 weak 引用也随之失效。
public final class CameraLeaseToken {}

private struct CameraLeaseEnvironmentKey: EnvironmentKey {
    static let defaultValue: CameraLeaseToken? = nil
}

private struct CameraLeaseActiveKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var cameraLeaseActive: Bool {
        get { self[CameraLeaseActiveKey.self] }
        set { self[CameraLeaseActiveKey.self] = newValue }
    }
    var cameraLeaseToken: CameraLeaseToken? {
        get { self[CameraLeaseEnvironmentKey.self] }
        set { self[CameraLeaseEnvironmentKey.self] = newValue }
    }
}

/// 读出当前视图所在的 UIWindowScene（SwiftUI 没有直接给出场景标识的环境值）。
private struct WindowSceneIDProbe: UIViewRepresentable {
    @Binding var sceneID: ObjectIdentifier?

    final class ProbeView: UIView {
        var sceneDidChange: ((UIWindowScene) -> Void)?
        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let scene = window?.windowScene { sceneDidChange?(scene) }
        }
    }

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView(frame: .zero)
        view.sceneDidChange = { scene in
            DispatchQueue.main.async { self.sceneID = ObjectIdentifier(scene) }
        }
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ uiView: ProbeView, context: Context) {
        guard let windowScene = uiView.window?.windowScene else { return }
        let identifier = ObjectIdentifier(windowScene)
        guard identifier != sceneID else { return }
        DispatchQueue.main.async { self.sceneID = identifier }
    }
}

/// 相机页闸门：拿不到跨窗口租约时，用提示卡替代内容，
/// 从根上不构造采集会话（而不是构造了再失败重连）。
public struct CameraExclusiveGate<Content: View>: View {
    private enum Phase {
        case pending
        case granted
        case denied
    }

    @ObservedObject private var exclusivity = CameraExclusivity.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var phase: Phase = .pending
    @State private var sceneID: ObjectIdentifier?
    @State private var token = CameraLeaseToken()
    @State private var isVisible = false
    @State private var isAcquiring = false
    @State private var hasConstructedContent = false

    private let content: () -> Content

    public init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    public var body: some View {
        ZStack {
            if hasConstructedContent {
                content()
                    .environment(\.cameraLeaseToken, token)
                    .environment(\.cameraLeaseActive, isVisible && phase == .granted && exclusivity.owns(token))
                    .opacity(phase == .granted ? 1 : 0)
                    .allowsHitTesting(phase == .granted)
            }
            switch phase {
            case .granted:
                EmptyView()
            case .denied:
                deniedCard
            case .pending:
                // 等窗口场景标识的一帧：用与相机页一致的深色底，避免闪白。
                Color.screenInk.ignoresSafeArea()
            }
        }
        .background(
            WindowSceneIDProbe(sceneID: $sceneID)
                .frame(width: 0, height: 0)
        )
        .onAppear {
            isVisible = true
            tryAcquire(onReturn: true)
        }
        .onDisappear {
            isVisible = false
            CameraExclusivity.shared.release(token)
            // Keep the covered content's state alive until its nested cover
            // closes. onAppear always revalidates ownership before returning.
        }
        .onReceive(exclusivity.$holderSceneID) { _ in
            tryAcquire()
        }
        .onChange(of: sceneID) { _ in
            tryAcquire()
        }
    }

    private var deniedCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "video.slash")
                .font(.system(size: 34, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.55))
            Text(lang.t("ar_camera_busy"))
                .adaptiveFont(size: 13)
                .multilineTextAlignment(.center)
                .foregroundColor(Color.white.opacity(0.8))
                .padding(.horizontal, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.screenInk.ignoresSafeArea())
    }

    private func tryAcquire(onReturn: Bool = false) {
        guard isVisible, !isAcquiring else { return }
        guard onReturn || phase != .granted else { return }
        guard let windowSceneID = sceneID else { return }
        isAcquiring = true
        defer { isAcquiring = false }
        if CameraExclusivity.shared.acquire(token, sceneID: windowSceneID) {
            hasConstructedContent = true
            phase = .granted
        } else {
            phase = .denied
        }
    }
}

// MARK: - 空间测绘 → 方位测量 → 专业计算 → 分析报告 完整工作流导览条与综合报告

public extension Notification.Name {
    static let didRequestWorkflowReport = Notification.Name("com.yanxiang.compass.didRequestWorkflowReport")
}

/// Tab 2 宿主视图：默认优先展示真实 ARKit / LiDAR 空间测绘工具（点对点测距、多边形面积周长、RoomPlan 3D 建模），
/// 支持一键切换至实景方位与建筑外部几何特征观测模式，且在非活动 Tab 时释放相机资源。
private struct ARSurveyTabHostView: View {
    let isActive: Bool
    @State private var showExteriorSiteObserver: Bool = false
    @ObservedObject private var lang = LocalizationManager.shared

    var body: some View {
        ZStack {
            Color.screenInk.ignoresSafeArea()
            if isActive {
                if showExteriorSiteObserver {
                    ZStack(alignment: .topTrailing) {
                        ARVisionView(isActive: true)
                        Button(action: { showExteriorSiteObserver = false }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arkit")
                                Text(lang.effectiveLanguage == .en ? "AR Measure" : "返回测绘")
                            }
                            .adaptiveFont(size: 10.5, weight: .bold)
                            .foregroundColor(.black)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(minHeight: DS.touchMin)
                            .background(Color.yanGold)
                            .cornerRadius(14)
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 54)
                        .padding(.trailing, 62)
                    }
                } else {
                    CameraExclusiveGate {
                        ARSpatialSurveyView(
                            isEmbedded: true,
                            onSwitchToExteriorView: { showExteriorSiteObserver = true }
                        )
                    }
                }
            }
        }
    }
}

/// 四步专业工作流状态条：挂载于户型测绘、AR 测绘、电子方位仪与专业计算顶部，一键串联全流程。
public struct WorkflowStepperBar: View {
    public let activeStep: Int // 0=测绘, 1=方位, 2=计算, 3=报告
    @ObservedObject private var workflow = SpatialWorkflowStore.shared
    @ObservedObject private var lang = LocalizationManager.shared

    public init(activeStep: Int) {
        self.activeStep = activeStep
    }

    private var stepTitles: [String] {
        switch lang.effectiveLanguage {
        case .en: return ["Survey", "Bearing", "Compute", "Report"]
        case .zhHant: return ["空間測繪", "方位測量", "專業計算", "綜合報告"]
        case .ja: return ["空間測量", "方位計測", "数理計算", "総合報告"]
        case .ko: return ["공간측량", "방위계측", "수리계산", "종합보고"]
        case .vi: return ["Đo đạc", "Phương vị", "Tính toán", "Báo cáo"]
        case .th: return ["สำรวจ", "วัดทิศ", "คำนวณ", "รายงาน"]
        case .id: return ["Survei", "Azimut", "Hitung", "Laporan"]
        case .auto, .zhHans: return ["空间测绘", "方位测量", "专业计算", "综合报告"]
        }
    }

    private func isStepDone(_ idx: Int) -> Bool {
        switch idx {
        case 0: return workflow.hasSurvey
        case 1: return workflow.hasBearing
        case 2: return workflow.hasCalculation
        case 3: return workflow.hasSurvey && workflow.hasBearing && workflow.hasCalculation
        default: return false
        }
    }

    private func handleTap(_ idx: Int) {
        switch idx {
        case 0: AppNavigationRouter.shared.requestRoute(tab: 0)
        case 1: AppNavigationRouter.shared.requestRoute(tab: 2)
        case 2: AppNavigationRouter.shared.requestRoute(tab: 3)
        case 3: NotificationCenter.default.post(name: .didRequestWorkflowReport, object: nil)
        default: break
        }
    }

    public var body: some View {
        let titles = stepTitles
        return HStack(spacing: 4) {
            ForEach(0..<4, id: \.self) { idx in
                let isActive = idx == activeStep
                let done = isStepDone(idx)
                Button(action: { handleTap(idx) }) {
                    HStack(spacing: 4) {
                        ZStack {
                            Circle()
                                .fill(done ? Color.semJi.opacity(0.24) : (isActive ? Color.yanGold.opacity(0.26) : Color.white.opacity(0.08)))
                                .frame(width: 15, height: 15)
                            if done {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundColor(.semJi)
                            } else if idx == 3 {
                                Image(systemName: "doc.text.fill")
                                    .font(.system(size: 7.5, weight: .bold))
                                    .foregroundColor(isActive ? Color.yanGold : .white.opacity(0.6))
                            } else {
                                Text("\(idx + 1)")
                                    .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                    .foregroundColor(isActive ? Color.yanGold : .white.opacity(0.62))
                            }
                        }
                        Text(titles[idx])
                            .adaptiveFont(size: 10, weight: isActive ? .bold : .semibold)
                            .foregroundColor(isActive ? Color.yanGold : (done ? .white : .white.opacity(0.72)))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: DS.touchMin)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isActive ? Color.yanGold.opacity(0.18) : (done ? Color.semJi.opacity(0.08) : Color.clear))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isActive ? Color.yanGold.opacity(0.7) : (done ? Color.semJi.opacity(0.28) : Color.clear), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                if idx < 3 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundColor(done ? Color.semJi.opacity(0.55) : Color.white.opacity(0.22))
                }
            }
        }
        .padding(3)
        .background(Color.surfaceCard)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.strokeSoft, lineWidth: 1)
        )
    }
}

/// 综合测绘、方位仪读数与可验证数理计算分析报告弹窗（支持可读报告与结构化 JSON 切换、缺失步骤一键跳转、一键复制与系统分享导出）。
public struct IntegratedWorkflowReportSheet: View {
    private enum ReportFormat: Int, CaseIterable {
        case readable = 0
        case json = 1
    }

    @Environment(\.presentationMode) private var presentationMode
    @ObservedObject private var workflow = SpatialWorkflowStore.shared
    @ObservedObject private var lang = LocalizationManager.shared
    @State private var format: ReportFormat = .readable
    @State private var reportText: String = ""
    @State private var reportJSON: String = ""
    @State private var copiedToast: Bool = false
    @State private var showShareSheet: Bool = false

    public init() {}

    private var activeOutput: String {
        format == .readable ? reportText : reportJSON
    }

    private var completedStageCount: Int {
        (workflow.hasSurvey ? 1 : 0) + (workflow.hasBearing ? 1 : 0) + (workflow.hasCalculation ? 1 : 0)
    }

    public var body: some View {
        let isEn = (lang.effectiveLanguage == .en)
        return NavigationView {
            ZStack {
                Color.screenInk.ignoresSafeArea()
                VStack(spacing: 12) {
                    // 三阶段完整度状态摘要（未完成项支持点击直达对应工作台）
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(isEn ? "Workflow Readiness (\(completedStageCount)/3)" : "全流程数据就绪度（\(completedStageCount)/3）")
                                .adaptiveFont(size: 11, weight: .semibold)
                                .foregroundColor(.white.opacity(0.72))
                            Spacer()
                            if completedStageCount < 3 {
                                Text(isEn ? "Tap pending step to complete" : "轻点待补项可直达")
                                    .adaptiveFont(size: 10)
                                    .foregroundColor(.yanCyan.opacity(0.85))
                            }
                        }
                        HStack(spacing: 8) {
                            statusPill(title: isEn ? "Spatial Survey" : "空间测绘", ok: workflow.hasSurvey, targetTab: 0)
                            statusPill(title: isEn ? "Bearing" : "方位测量", ok: workflow.hasBearing, targetTab: 2)
                            statusPill(title: isEn ? "Calculation" : "专业计算", ok: workflow.hasCalculation, targetTab: 3)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    Picker("", selection: $format) {
                        Text(isEn ? "Readable Report" : "综合分析报告").tag(ReportFormat.readable)
                        Text(isEn ? "Auditable JSON" : "可审计 JSON").tag(ReportFormat.json)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .onChange(of: format) { _ in copiedToast = false }

                    ScrollView {
                        Text(activeOutput)
                            .adaptiveFont(size: 11.5, design: .monospaced)
                            .foregroundColor(.white.opacity(0.92))
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.yanGold.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 16)
                    }

                    if copiedToast {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                            Text(isEn ? "Copied to clipboard" : "已复制当前报告内容至剪贴板")
                        }
                        .adaptiveFont(size: 11, weight: .semibold)
                        .foregroundColor(.semJi)
                    }

                    HStack(spacing: 10) {
                        Button(action: {
                            UIPasteboard.general.string = activeOutput
                            copiedToast = true
                        }) {
                            Label(isEn ? "Copy" : "复制内容", systemImage: "doc.on.doc")
                                .adaptiveFont(size: 12, weight: .bold)
                                .frame(maxWidth: .infinity, minHeight: DS.touchMin)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.yanCyan)
                                .cornerRadius(10)
                        }

                        Button(action: { showShareSheet = true }) {
                            Label(isEn ? "Export / Share" : "导出并分享", systemImage: "square.and.arrow.up")
                                .adaptiveFont(size: 12, weight: .bold)
                                .frame(maxWidth: .infinity, minHeight: DS.touchMin)
                                .background(Color.yanGold)
                                .foregroundColor(.black)
                                .cornerRadius(10)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
            }
            .navigationBarTitle(isEn ? "Integrated Analysis Report" : "测绘与计算综合报告", displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
        .onAppear {
            let now = Date()
            reportText = workflow.generateVerifiableReportText(date: now)
            reportJSON = workflow.generateVerifiableReportJSON(date: now)
        }
        .sheet(isPresented: $showShareSheet) {
            FloorplanReportShareSheet(items: [activeOutput])
        }
    }

    private func statusPill(title: String, ok: Bool, targetTab: Int) -> some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
            AppNavigationRouter.shared.requestRoute(tab: targetTab)
        }) {
            HStack(spacing: 4) {
                Image(systemName: ok ? "checkmark.seal.fill" : "arrow.up.right.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                Text(title)
                    .adaptiveFont(size: 10.5, weight: .semibold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: DS.touchMin)
            .padding(.vertical, 8)
            .padding(.horizontal, 6)
            .background(ok ? Color.semJi.opacity(0.16) : Color.semWarn.opacity(0.16))
            .foregroundColor(ok ? .semJi : .semWarn)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(ok ? Color.semJi.opacity(0.35) : Color.semWarn.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
