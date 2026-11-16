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
                            .background(Color.black.opacity(0.04))
                            .cornerRadius(12)
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
                        ForEach(0..<8, id: \.self) { idx in
                            let palaceRecords = grouped[idx]
                            if !palaceRecords.isEmpty {
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(lang.t("ar_panorama_palace"))
                                            .font(.caption.weight(.bold))
                                        Text(palaceRange(idx))
                                            .font(.caption.weight(.bold).monospaced())
                                        Spacer()
                                        Text("\(palaceRecords.count)")
                                            .font(.caption.weight(.bold))
                                    }
                                    .foregroundColor(.brown)
                                    ForEach(palaceRecords) { record in
                                        HStack(spacing: 8) {
                                            Image(systemName: "mappin.circle.fill")
                                                .foregroundColor(severityColor(for: record))
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(shaName(for: record))
                                                    .font(.subheadline.weight(.semibold))
                                                Text("\(String(format: "%.1f", record.bearingDegrees))° · \(lang.t("ar_panorama_elevation")) \(String(format: "%.0f", record.elevationDegrees))° · \(record.source == .ai ? lang.t("ar_panorama_ai") : lang.t("ar_panorama_manual"))")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                            Spacer()
                                            if let d = record.distanceMeters {
                                                Text(String(format: "%.1f m", d))
                                                    .font(.caption.monospaced())
                                                    .foregroundColor(.secondary)
                                            }
                                            if let sev = effectiveSeverity(for: record) {
                                                Text(sev.localizedTitle)
                                                    .font(.caption2.weight(.bold))
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(sev == .critical ? Color.red.opacity(0.15) : (sev == .warning ? Color.orange.opacity(0.15) : (sev == .minor ? Color.yellow.opacity(0.15) : Color.green.opacity(0.15))))
                                                    .cornerRadius(6)
                                            }
                                            Button(action: {
                                                shaStore.removeRecord(id: record.id)
                                            }) {
                                                Image(systemName: "trash")
                                                    .adaptiveFont(size: 12)
                                                    .foregroundColor(.red.opacity(0.75))
                                                    .padding(6)
                                                    .contentShape(Rectangle())
                                            }
                                            .buttonStyle(BorderlessButtonStyle())
                                        }
                                        .padding(8)
                                        .background(Color.black.opacity(0.04))
                                        .cornerRadius(8)
                                    }
                                }
                            }
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
