import SwiftUI

// MARK: - 全景形煞分布报告（八宫聚合 + 距离判级 + 仰角/距离明细）
// 从 ARVisionView.swift 抽出：原本就是独立 struct，只是被埋在 2700 行的文件尾部。
// 顶部新增环形分布图：把每条形煞按（方位角、距离、判级）落到极坐标上，
// 一眼看出"西北方堆了三个煞、正南有一个极凶"，不用逐条读列表。

struct ShaPanoramaReportSheet: View {
    @ObservedObject private var shaStore = ShaSurveyStore.shared
    let heading: Double
    let shaList: [ExteriorShaItem]
    @ObservedObject var lang = LocalizationManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showClearConfirmAlert = false
    /// 当前展开的宫位（nil = 八宫矩阵只看分布，不展开明细）
    @State private var expandedPalace: Int?

    init(records: [ExteriorShaRecord]? = nil, heading: Double, shaList: [ExteriorShaItem]) {
        self.heading = heading
        self.shaList = shaList
    }

    private var records: [ExteriorShaRecord] {
        shaStore.records
    }

    private var grouped: [[ExteriorShaRecord]] {
        ShaPanoramaReport(headingDegrees: heading, records: records).palacesByIndex
    }

    private func effectiveSeverity(for record: ExteriorShaRecord) -> ShaSeverity? {
        guard let item = shaList.first(where: { $0.id == record.shaID }) else { return nil }
        return ExteriorShaSeverityResolver.effectiveSeverity(
            staticSeverity: item.severity,
            distanceMeters: record.distanceMeters
        )
    }

    private func shaName(for record: ExteriorShaRecord) -> String {
        shaList.first(where: { $0.id == record.shaID })?.localizedName ?? record.shaID
    }

    private func palaceRange(_ index: Int) -> String {
        String(format: "%d°–%d°", index * 45, (index + 1) * 45)
    }

    private func severityColor(for record: ExteriorShaRecord) -> Color {
        guard let sev = effectiveSeverity(for: record) else { return .gray }
        switch sev {
        case .critical: return .red
        case .warning: return .orange
        case .minor: return .yellow
        case .notice: return .green
        }
    }

    /// 把每条记录折算成极坐标点：角度相对基准朝向，半径按距离 3–25 m 归一。
    private var polarPoints: [ShaPanoramaPolarPoint] {
        records.map { record in
            let relative = ((record.bearingDegrees - heading).truncatingRemainder(dividingBy: 360) + 360)
                .truncatingRemainder(dividingBy: 360)
            let meters = record.distanceMeters ?? 8
            let fraction = 0.28 + 0.64 * min(max(meters, 1), 25) / 25
            return ShaPanoramaPolarPoint(relativeAngle: relative,
                                        radiusFraction: CGFloat(fraction),
                                        severity: effectiveSeverity(for: record))
        }
    }

    private func severityLegend() -> some View {
        HStack(spacing: 14) {
            ForEach(Array(ShaSeverity.allCasesForLegend.enumerated()), id: \.offset) { _, sev in
                HStack(spacing: 4) {
                    Circle()
                        .fill(ShaPanoramaPolarChart.color(for: sev))
                        .frame(width: 7, height: 7)
                    Text(sev.localizedTitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // 顶部统计：标注数 / 覆盖宫位 / 极凶数
                    HStack {
                        VStack {
                            Text("\(records.count)")
                                .adaptiveFont(size: 26, weight: .bold)
                            Text(lang.t("ar_panorama_records"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack {
                            Text("\(grouped.filter { !$0.isEmpty }.count)/8")
                                .adaptiveFont(size: 26, weight: .bold)
                            Text(lang.t("ar_panorama_palaces"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        VStack {
                            Text("\(records.filter { effectiveSeverity(for: $0) == .critical }.count)")
                                .adaptiveFont(size: 26, weight: .bold)
                                .foregroundColor(.red)
                            Text(lang.t("ar_panorama_critical"))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.black.opacity(0.06))
                    .cornerRadius(10)

                    Text("\(lang.t("ar_panorama_heading")): \(String(format: "%.1f", heading))°")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)

                    // 八宫环形分布图：方位角 = 相对基准朝向的夹角（正上方即基准朝向），
                    // 半径 = 距离远近，颜色/尺寸 = 判级。列表负责细节，图负责一眼看分布。
                    if !records.isEmpty {
                        ShaPanoramaPolarChart(points: polarPoints)
                            .frame(height: 232)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.appInkRaised)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.yanGold.opacity(0.14), lineWidth: 0.8)
                            )
                        severityLegend()
                    }

                    // 室内外统一档案：室内体检条目与外部标注合计
                    if let interior = ShaSurveyStore.shared.latestInterior {
                        HStack(spacing: 8) {
                            Image(systemName: "house.and.flag.fill")
                                .foregroundColor(.brown)
                            Text("\(lang.t("ar_panorama_interior")): \(interior.shaItems.count) · \(lang.t("ar_panorama_total")): \(records.count + interior.shaItems.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.brown.opacity(0.08))
                        .cornerRadius(8)
                    }

                    if records.isEmpty {
                        Text(lang.t("ar_panorama_none"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        // 八宫矩阵：八个方位一次铺满，空格位也留着。
                        // 长列表只说「有煞的地方」，留白矩阵还能说「哪些方位干净」——
                        // 这层信息以前是看不见的，也是这个页面区别于普通清单的地方。
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 8),
                                GridItem(.flexible(), spacing: 8)
                            ],
                            spacing: 8
                        ) {
                            ForEach(0..<8, id: \.self) { idx in
                                palaceCard(index: idx, records: grouped[idx])
                            }
                        }
                        .padding(.top, 2)

                        if let expanded = expandedPalace, !grouped[expanded].isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(spacing: 6) {
                                    Text("\(lang.t("ar_panorama_palace")) \(expanded + 1)")
                                        .font(.caption.weight(.bold))
                                        .foregroundColor(Color.yanGoldSoft)
                                    Text(palaceRange(expanded))
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.white.opacity(0.45))
                                    Spacer()
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            expandedPalace = nil
                                        }
                                    } label: {
                                        Image(systemName: "chevron.up")
                                            .font(.caption.weight(.bold))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                                ForEach(grouped[expanded]) { record in
                                    recordRow(record)
                                }
                            }
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.03))
                            )
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle(lang.t("ar_panorama_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if !records.isEmpty {
                        Button(role: .destructive, action: {
                            showClearConfirmAlert = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                Text(lang.t("ar_panorama_clear"))
                            }
                            .adaptiveFont(size: 13, weight: .medium)
                            .foregroundColor(.red)
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(lang.t("ar_panorama_close")) { dismiss() }
                }
            }
            .alert(isPresented: $showClearConfirmAlert) {
                Alert(
                    title: Text(lang.t("ar_panorama_clear_confirm_title")),
                    message: Text(lang.t("ar_panorama_clear_confirm_msg")),
                    primaryButton: .destructive(Text(lang.t("ar_panorama_clear_confirm_btn"))) {
                        shaStore.clearRecords()
                    },
                    secondaryButton: .cancel(Text(lang.t("cancel")))
                )
            }
        }
        // iPad 自适应：缺少该修饰符时 NavigationView 在 iPad 上会退化为
        // 分栏容器（左侧列表 + 右侧空占位 “未选择”），内容被压到半屏。
        // 统一用 Stack 样式，保证 iPhone / iPad 都是单列全宽页面。
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - 八宫环形分布图

/// 极坐标点：角度是相对基准朝向的顺时针夹角，半径 0…1 由距离决定。
    // MARK: - 宫位卡

    private func severityRank(_ severity: ShaSeverity?) -> Int {
        guard let severity = severity else { return -1 }
        switch severity {
        case .critical: return 3
        case .warning: return 2
        case .minor: return 1
        case .notice: return 0
        }
    }

    /// 该宫最高判级：左侧竖色条就是它，一眼看出「这一宫最重的是极凶还是提醒」
    private func peakSeverity(_ palaceRecords: [ExteriorShaRecord]) -> ShaSeverity? {
        palaceRecords
            .map { effectiveSeverity(for: $0) }
            .max { severityRank($0) < severityRank($1) }
    }

    private func palaceCard(index: Int, records palaceRecords: [ExteriorShaRecord]) -> some View {
        let peak = peakSeverity(palaceRecords)
        let isOpen = expandedPalace == index
        return Button {
            guard !palaceRecords.isEmpty else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                expandedPalace = isOpen ? nil : index
            }
        } label: {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(peak.map { ShaPanoramaPolarChart.color(for: $0) } ?? Color.white.opacity(0.12))
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text("\(lang.t("ar_panorama_palace")) \(index + 1)")
                            .font(.caption2.weight(.bold))
                            .foregroundColor(palaceRecords.isEmpty ? .white.opacity(0.32) : Color.yanGoldSoft)
                        Spacer(minLength: 0)
                        Text(palaceRecords.isEmpty ? "—" : "\(palaceRecords.count)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundColor(palaceRecords.isEmpty ? .white.opacity(0.22) : .white)
                        if !palaceRecords.isEmpty {
                            Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundColor(.white.opacity(0.35))
                        }
                    }
                    Text(palaceRange(index))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white.opacity(0.42))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.appInkRaised)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isOpen ? Color.yanGold.opacity(0.55) : Color.yanGold.opacity(0.14), lineWidth: 0.8)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func recordRow(_ record: ExteriorShaRecord) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(severityColor(for: record))
            VStack(alignment: .leading, spacing: 2) {
                Text(shaName(for: record))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.9))
                Text("\(String(format: "%.1f", record.bearingDegrees))° · \(lang.t("ar_panorama_elevation")) \(String(format: "%.0f", record.elevationDegrees))° · \(record.source == .ai ? lang.t("ar_panorama_ai") : lang.t("ar_panorama_manual"))")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }
            Spacer()
            if let distance = record.distanceMeters {
                Text(String(format: "%.1f m", distance))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white.opacity(0.55))
            }
            if let severity = effectiveSeverity(for: record) {
                Text(severity.localizedTitle)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(ShaPanoramaPolarChart.color(for: severity).opacity(0.18))
                    .foregroundColor(ShaPanoramaPolarChart.color(for: severity))
                    .cornerRadius(6)
            }
            Button(action: {
                shaStore.removeRecord(id: record.id)
            }) {
                Image(systemName: "trash")
                    .adaptiveFont(size: 12)
                    .foregroundColor(.red.opacity(0.7))
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(BorderlessButtonStyle())
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
    }

    // MARK: - 极坐标图

struct ShaPanoramaPolarPoint {
    let relativeAngle: Double
    let radiusFraction: CGFloat
    let severity: ShaSeverity?
}

/// 用 Canvas 画的八宫分布盘：
/// 正上方 = 采集时的基准朝向（罗盘 0°），顺时针每 45° 换一宫；
/// 越靠外越远，色与尺寸对应判级；极凶额外加一层淡红光晕，避免只看颜色分不出轻重。
struct ShaPanoramaPolarChart: View {
    let points: [ShaPanoramaPolarPoint]

    static func color(for severity: ShaSeverity?) -> Color {
        guard let severity else { return .gray }
        switch severity {
        case .critical: return .red
        case .warning: return .orange
        case .minor: return .yellow
        case .notice: return .green
        }
    }

    private static func dotDiameter(for severity: ShaSeverity?) -> CGFloat {
        switch severity {
        case .critical: return 9
        case .warning: return 7
        case .minor: return 5.5
        case .notice: return 4.5
        case .none: return 5
        }
    }

    var body: some View {
        Canvas { context, size in
            let side = min(size.width, size.height)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let outer = side / 2 - 14
            let inner = outer * 0.24

            // 底盘
            let disc = Path(ellipseIn: CGRect(x: center.x - outer, y: center.y - outer,
                                              width: outer * 2, height: outer * 2))
            context.fill(disc, with: .color(Color.appInkRaised.opacity(0.55)))
            context.stroke(disc, with: .color(Color.yanCyan.opacity(0.22)), lineWidth: 1)

            // 八宫扇区：隔宫交替，给一点"分区"的暗示
            for index in 0..<8 {
                let start = Angle(degrees: Double(index) * 45 - 90)
                let end = Angle(degrees: Double(index + 1) * 45 - 90)
                var wedge = Path()
                wedge.move(to: center)
                wedge.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
                wedge.closeSubpath()
                if index % 2 == 0 {
                    context.fill(wedge, with: .color(Color.yanCyan.opacity(0.05)))
                }
                var divider = Path()
                divider.move(to: center)
                divider.addLine(to: CGPoint(x: center.x + outer * cos(CGFloat(start.radians)),
                                            y: center.y + outer * sin(CGFloat(start.radians))))
                context.stroke(divider, with: .color(Color.yanCyan.opacity(0.14)), lineWidth: 0.5)
            }

            // 距离参考环：3 / 10 / 25 m 三档
            for fraction in [0.40, 0.62, 0.88] {
                let radius = outer * CGFloat(fraction)
                let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius,
                                                 width: radius * 2, height: radius * 2))
                context.stroke(ring, with: .color(Color.yanCyan.opacity(0.10)), lineWidth: 0.6)
            }

            // 中心立极点
            let core = Path(ellipseIn: CGRect(x: center.x - inner, y: center.y - inner,
                                              width: inner * 2, height: inner * 2))
            context.fill(core, with: .color(Color.yanGold.opacity(0.14)))
            context.stroke(core, with: .color(Color.yanGold.opacity(0.35)), lineWidth: 0.8)

            // 基准朝向标记（正上方的金色小三角）
            var marker = Path()
            marker.move(to: CGPoint(x: center.x, y: center.y - outer - 9))
            marker.addLine(to: CGPoint(x: center.x - 4.5, y: center.y - outer - 2))
            marker.addLine(to: CGPoint(x: center.x + 4.5, y: center.y - outer - 2))
            marker.closeSubpath()
            context.fill(marker, with: .color(Color.yanGold.opacity(0.75)))

            // 形煞点
            for point in points {
                let radius = outer * point.radiusFraction
                let radians = CGFloat(point.relativeAngle - 90) * .pi / 180
                let location = CGPoint(x: center.x + radius * cos(radians),
                                       y: center.y + radius * sin(radians))
                let diameter = Self.dotDiameter(for: point.severity)
                let rect = CGRect(x: location.x - diameter / 2, y: location.y - diameter / 2,
                                  width: diameter, height: diameter)
                if point.severity == .critical {
                    let halo = rect.insetBy(dx: -diameter / 2, dy: -diameter / 2)
                    context.fill(Path(ellipseIn: halo), with: .color(Color.red.opacity(0.18)))
                }
                context.fill(Path(ellipseIn: rect), with: .color(Self.color(for: point.severity)))
                context.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.55)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension ShaSeverity {
    /// 图例顺序固定：极凶 → 中凶 → 轻微 → 吉象。
    static var allCasesForLegend: [ShaSeverity] { [.critical, .warning, .minor, .notice] }
}
