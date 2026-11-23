import SwiftUI

// MARK: - 测绘训练进度条 (Training Progress HUD)
// 游戏化只做「操作反馈」：真实测量动作 → 关卡完成 → 经验/徽章，不改变任何测量结果。

public struct DSTrainingProgressHUD: View {
    @ObservedObject private var training = CompassTrainingStore.shared
    @ObservedObject private var lang = LocalizationManager.shared

    public init() {}

    public var body: some View {
        let isEn = lang.effectiveLanguage == .en
        return VStack(alignment: .leading, spacing: DS.padS) {
            HStack(spacing: 8) {
                Image(systemName: "rosette")
                    .foregroundColor(.goldText)
                    .adaptiveFont(size: 14)
                Text(isEn ? "Survey Training" : "测绘训练")
                    .adaptiveFont(size: 12, weight: .bold)
                    .foregroundColor(.goldText)
                Spacer()
                Text("LV.\(training.level) · \(training.levelTitle(isEn: isEn))")
                    .adaptiveFont(size: 11, weight: .semibold)
                    .foregroundColor(.white.opacity(0.85))
                Text("\(training.xp) XP")
                    .adaptiveFont(size: 10, weight: .bold, design: .monospaced)
                    .foregroundColor(.yanCyan)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(LinearGradient(colors: [.goldDeep, .goldText], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * training.levelProgress))
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: training.levelProgress)
                }
            }
            .frame(height: 6)

            HStack(spacing: 6) {
                ForEach(TrainingDrill.allCases) { drill in
                    DrillChip(drill: drill, done: training.isDrillDone(drill), isEn: isEn)
                }
            }
        }
        .padding(DS.padM)
        .background(Color.surfaceCard)
        .cornerRadius(DS.radiusM)
        .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(Color.strokeGold, lineWidth: 1))
        .overlay(alignment: .topTrailing) {
            if training.showEarnedToast && !training.lastEarnedTitle.isEmpty {
                Text(training.lastEarnedTitle)
                    .adaptiveFont(size: 10, weight: .bold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.goldText)
                    .cornerRadius(8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .offset(x: -8, y: -22)
            }
        }
    }
}

private struct DrillChip: View {
    let drill: TrainingDrill
    let done: Bool
    let isEn: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: done ? "checkmark.circle.fill" : drill.icon)
                .adaptiveFont(size: 11)
            Text(drill.title(isEn))
                .adaptiveFont(size: 10, weight: .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundColor(done ? .semJi : .white.opacity(0.7))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity)
        .background(done ? Color.semJi.opacity(0.12) : Color.white.opacity(0.05))
        .cornerRadius(DS.radiusS)
        .overlay(
            RoundedRectangle(cornerRadius: DS.radiusS)
                .stroke(done ? Color.semJi.opacity(0.4) : Color.strokeSoft, lineWidth: 1)
        )
    }
}

// MARK: - 徽章墙 (Badge Shelf)
public struct DSTrainingBadgeShelf: View {
    @ObservedObject private var training = CompassTrainingStore.shared
    @ObservedObject private var lang = LocalizationManager.shared
    public var compact: Bool = false

    public init(compact: Bool = false) { self.compact = compact }

    public var body: some View {
        let isEn = lang.effectiveLanguage == .en
        let earned = TrainingBadge.allCases.filter { training.isBadgeEarned($0) }
        VStack(alignment: .leading, spacing: DS.padS) {
            HStack {
                Image(systemName: "trophy.fill").foregroundColor(.goldText).adaptiveFont(size: 13)
                Text(isEn ? "Badges" : "成就徽章")
                    .adaptiveFont(size: 12, weight: .bold).foregroundColor(.goldText)
                Spacer()
                Text("\(earned.count)/\(TrainingBadge.allCases.count)")
                    .adaptiveFont(size: 11, weight: .bold, design: .monospaced)
                    .foregroundColor(.yanCyan)
            }

            if compact {
                HStack(spacing: 10) {
                    ForEach(TrainingBadge.allCases) { badge in
                        BadgeDot(badge: badge, earned: training.isBadgeEarned(badge), isEn: isEn)
                    }
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140))], spacing: 10) {
                    ForEach(TrainingBadge.allCases) { badge in
                        BadgeCard(badge: badge, earned: training.isBadgeEarned(badge), isEn: isEn)
                    }
                }
            }
        }
        .padding(DS.padM)
        .background(Color.surfaceCard)
        .cornerRadius(DS.radiusM)
        .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(Color.strokeSoft, lineWidth: 1))
    }
}

private struct BadgeDot: View {
    let badge: TrainingBadge
    let earned: Bool
    let isEn: Bool
    var body: some View {
        Image(systemName: badge.icon)
            .adaptiveFont(size: 16)
            .foregroundColor(earned ? .goldText : .white.opacity(0.22))
            .frame(width: 34, height: 34)
            .background(earned ? Color.goldPrimary.opacity(0.15) : Color.white.opacity(0.04))
            .cornerRadius(DS.radiusS)
            .accessibilityLabel(badge.title(isEn))
    }
}

private struct BadgeCard: View {
    let badge: TrainingBadge
    let earned: Bool
    let isEn: Bool
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: badge.icon)
                .adaptiveFont(size: 18)
                .foregroundColor(earned ? .goldText : .white.opacity(0.25))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title(isEn))
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(earned ? .primary : .secondary)
                Text(badge.detail(isEn))
                    .adaptiveFont(size: 10)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(earned ? Color.goldPrimary.opacity(0.08) : Color.white.opacity(0.03))
        .cornerRadius(DS.radiusS)
        .overlay(RoundedRectangle(cornerRadius: DS.radiusS).stroke(earned ? Color.strokeGold : Color.strokeSoft, lineWidth: 1))
    }
}

// MARK: - 翻转卡片：点按翻到背面看测量依据
public struct DSFlipCard<Front: View, Back: View>: View {
    @State private var flipped = false
    let front: Front
    let back: Back

    init(@ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.front = front()
        self.back = back()
    }

    public var body: some View {
        ZStack {
            front.opacity(flipped ? 0 : 1)
            back.opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .animation(.easeInOut(duration: 0.45), value: flipped)
        .contentShape(Rectangle())
        .onTapGesture {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation { flipped.toggle() }
        }
    }
}
