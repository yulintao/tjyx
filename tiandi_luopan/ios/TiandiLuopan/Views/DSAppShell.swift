import SwiftUI

// MARK: - 统一页面骨架 (DSAppShell v2)
// 设计目标：所有主页面遵循同一套「Hero → 主操作 → 折叠详情」三段式，
// 杜绝信息平铺、卡片套卡片、核心被次要信息挤出首屏的问题。
//
// 结构契约：
//   1. Hero 区：唯一核心内容（盘面 / 画布 / AR 取景 / 排盘），首屏第一眼，不套卡片外框。
//   2. 主操作：单排底座，44pt 触摸，永远紧贴 Hero。
//   3. 详情：全部次要信息（参数 / 遥测 / 训练 / 明细）收进可折叠区，默认收起。

/// 页面骨架容器：统一背景、统一滚动、统一底部留白（防 TabBar 遮挡）。
public struct DSAppShell<Content: View>: View {
    private let content: Content
    private let background: Color

    public init(background: Color = .screenInk,
                @ViewBuilder content: () -> Content) {
        self.background = background
        self.content = content()
    }

    public var body: some View {
        ZStack {
            background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: DS.padL) { content }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, DS.padL)
                    // 浮动 TabBar 不占 safe area，留底部余量保证末尾内容可完整滚出
                    .padding(.bottom, 88)
            }
        }
    }
}

/// Hero 核心区：唯一主体内容。transparent 背景，避免卡片套卡片。
public struct DSHeroStage<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        content
            .frame(maxWidth: .infinity)
    }
}

/// 主操作底座：单排等分按钮，统一 44pt 与金色主按钮样式。
public struct DSActionDock<Content: View>: View {
    private let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        HStack(spacing: DS.padS) { content }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.padS)
    }
}

/// 统一的单层卡片：全 App 只有一种卡片语义（背景+细描边，不再叠加阴影）。
/// 用于详情区，不用于 Hero。
public struct DSSectionCard<Content: View>: View {
    private let content: Content
    private let accent: Color
    public init(accent: Color = .clear, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: DS.padM) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DS.padM)
            .background(Color.surfaceCard)
            .cornerRadius(DS.radiusM)
            .overlay(RoundedRectangle(cornerRadius: DS.radiusM)
                .stroke(accent == .clear ? Color.strokeSoft : accent.opacity(0.4), lineWidth: 1))
    }
}

/// 紧凑信息行：替代"每个数据一张卡"的做法，用分隔线组织同组数据。
public struct DSInfoRow: View {
    private let label: String
    private let value: String
    private let valueColor: Color
    public init(label: String, value: String, valueColor: Color = .paperText) {
        self.label = label; self.value = value; self.valueColor = valueColor
    }
    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).adaptiveFont(size: DS.TypeScale.sub).foregroundColor(.paperSub)
            Spacer(minLength: DS.padS)
            Text(value).adaptiveFont(size: DS.TypeScale.body, weight: .semibold)
                .foregroundColor(valueColor)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: DS.touchMin)
    }
}

/// 底部主按钮：全 App 统一主操作样式（金色实心、44pt）。
public struct DSPrimaryActionButton: View {
    private let title: String
    private let icon: String?
    private let action: () -> Void
    public init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.action = action
    }
    public var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            HStack(spacing: 6) {
                if let icon = icon { Image(systemName: icon) }
                Text(title).adaptiveFont(size: DS.TypeScale.body, weight: .bold)
            }
            .foregroundColor(Color(red: 0.12, green: 0.10, blue: 0.04))
            .frame(maxWidth: .infinity, minHeight: DS.touchMin)
            .background(LinearGradient(colors: [.goldText, .goldPrimary],
                                       startPoint: .leading, endPoint: .trailing))
            .cornerRadius(DS.radiusS)
        }
        .buttonStyle(.plain)
    }
}

/// 次按钮：描边样式，与主键形成明确层级。
public struct DSSecondaryActionButton: View {
    private let title: String
    private let icon: String?
    private let action: () -> Void
    public init(title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.action = action
    }
    public var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            HStack(spacing: 6) {
                if let icon = icon { Image(systemName: icon) }
                Text(title).adaptiveFont(size: DS.TypeScale.sub, weight: .semibold)
            }
            .foregroundColor(.goldText)
            .frame(maxWidth: .infinity, minHeight: DS.touchMin)
            .background(Color.surfaceElevated)
            .cornerRadius(DS.radiusS)
            .overlay(RoundedRectangle(cornerRadius: DS.radiusS)
                .stroke(Color.strokeGold, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
