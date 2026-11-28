import SwiftUI

// MARK: - 现代测绘工作台首页
// 首页只负责组织工作流和导航，测绘、罗盘、分析的业务逻辑仍由各自页面承载。
public struct CommandCenterView: View {
    @ObservedObject private var lang = LocalizationManager.shared
    @ObservedObject private var motion = CompassMotionManager.shared
    @ObservedObject private var workflow = SpatialWorkflowStore.shared
    @ObservedObject private var training = CompassTrainingStore.shared
    @ObservedObject private var iap = StoreKitIAPManager.shared

    private var isEn: Bool { lang.effectiveLanguage == .en }

    private enum NextStage {
        case survey
        case bearing
        case calculation
        case report
    }

    private struct WorkTool: Identifiable {
        let id: String
        let title: String
        let detail: String
        let icon: String
        let tint: Color
        let action: () -> Void
    }

    public init() {}

    private var nextStage: NextStage {
        if !workflow.hasSurvey { return .survey }
        if !workflow.hasBearing { return .bearing }
        if !workflow.hasCalculation { return .calculation }
        return .report
    }

    private var nextActionTitle: String {
        switch nextStage {
        case .survey: return isEn ? "Start spatial survey" : "开始空间测绘"
        case .bearing: return isEn ? "Capture precise bearing" : "开始精确采样"
        case .calculation: return isEn ? "Open professional analysis" : "进入专业分析"
        case .report: return isEn ? "Generate project report" : "生成项目报告"
        }
    }

    private var nextActionIcon: String {
        switch nextStage {
        case .survey: return "ruler"
        case .bearing: return "safari.fill"
        case .calculation: return "square.grid.3x3.fill"
        case .report: return "doc.text.fill"
        }
    }

    private var nextActionDetail: String {
        switch nextStage {
        case .survey: return isEn ? "Create a spatial base for this project" : "先建立本项目的空间底图"
        case .bearing: return isEn ? "Add a verified facing direction" : "补充经过校准的坐向数据"
        case .calculation: return isEn ? "Use the survey and bearing to calculate" : "基于测绘与方位生成专业计算"
        case .report: return isEn ? "Review, copy, or export the full result" : "查看、复制或导出完整项目结果"
        }
    }

    private var workTools: [WorkTool] {
        [
            WorkTool(id: "ar", title: isEn ? "AR survey" : "AR 测绘",
                     detail: isEn ? "Measure in space" : "空间实测",
                     icon: "camera.viewfinder", tint: .semJi) { go(to: 1) },
            WorkTool(id: "compass", title: isEn ? "Compass" : "罗盘测量",
                     detail: isEn ? "Find true north" : "校准真北",
                     icon: "safari.fill", tint: .vermilion) { go(to: 2) },
            WorkTool(id: "analysis", title: isEn ? "Analysis" : "专业分析",
                     detail: isEn ? "Explore methods" : "进入计算",
                     icon: "square.grid.3x3.fill", tint: .goldText) { go(to: 3, feature: .xuanKong) },
            WorkTool(id: "report", title: isEn ? "Report" : "综合报告",
                     detail: isEn ? "Review project" : "汇总项目",
                     icon: "doc.text.fill", tint: .goldText) { openReport() }
        ]
    }

    public var body: some View {
        ZStack {
            Color.screenInk.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    projectSummary
                    workflowTrack
                    nextAction
                    recentWork
                    quickTools
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 100)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(isEn ? "TianJi Workspace" : "天机测绘工作台")
                    .adaptiveFont(size: 27, weight: .bold, design: .rounded)
                    .foregroundColor(.paperText)
                Text(isEn ? "Survey clearly. Decide with evidence." : "把现场数据整理成可复核的判断")
                    .adaptiveFont(size: 12)
                    .foregroundColor(.paperSub)
            }

            Spacer(minLength: 8)

            HStack(spacing: 6) {
                Image(systemName: iap.hasUnlockedVIP ? "crown.fill" : "location.north.fill")
                    .adaptiveFont(size: 13, weight: .bold)
                Text(iap.hasUnlockedVIP ? (isEn ? "PRO" : "专业版") : (isEn ? "FIELD" : "现场"))
                    .adaptiveFont(size: 10, weight: .bold)
            }
            .foregroundColor(.goldText)
            .padding(.horizontal, 10)
            .frame(minHeight: 30)
            .background(Color.surfaceElevated)
            .cornerRadius(DS.radiusS)
            .overlay(RoundedRectangle(cornerRadius: DS.radiusS).stroke(Color.strokeGold, lineWidth: 1))
        }
    }

    private var projectSummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(isEn ? "ACTIVE PROJECT" : "当前项目")
                        .adaptiveFont(size: 10, weight: .bold)
                        .foregroundColor(.goldText)
                    Text(isEn ? "Site survey record" : "现场测绘记录")
                        .adaptiveFont(size: 20, weight: .bold)
                        .foregroundColor(.paperText)
                    Text(isEn ? "A working record for the next observation" : "用于持续记录本次现场观察与判断")
                        .adaptiveFont(size: 12)
                        .foregroundColor(.paperSub)
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 3) {
                    Text("\(workflow.completedStages)/3")
                        .adaptiveFont(size: 24, weight: .bold, design: .rounded)
                        .foregroundColor(.goldText)
                    Text(isEn ? "stages" : "已完成阶段")
                        .adaptiveFont(size: 10)
                        .foregroundColor(.paperSub)
                }
            }

            HStack(spacing: 8) {
                summaryMetric(value: currentFacing, label: isEn ? "Facing" : "当前坐向", icon: "location.north.fill")
                summaryMetric(value: "\(training.streakDays)", label: isEn ? "Practice days" : "连续练习", icon: "flame.fill")
            }
        }
        .padding(16)
        .background(Color.surfaceCard)
        .cornerRadius(DS.radiusM)
        .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(Color.strokeSoft, lineWidth: 1))
    }

    private var currentFacing: String {
        if let bearing = workflow.bearing?.bearingDegrees {
            return String(format: "%.1f°", bearing)
        }
        return motion.headingState.facingMountain.localizedName
    }

    private func summaryMetric(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .adaptiveFont(size: 13)
                .foregroundColor(.goldText)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .adaptiveFont(size: 13, weight: .bold, design: .rounded)
                    .foregroundColor(.paperText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(label)
                    .adaptiveFont(size: 10)
                    .foregroundColor(.paperSub)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .frame(minHeight: 48)
        .background(Color.surfaceElevated)
        .cornerRadius(DS.radiusS)
    }

    private var workflowTrack: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(title: isEn ? "FIELD WORKFLOW" : "现场工作流", detail: isEn ? "Four steps, one record" : "四步完成一份项目记录")

            HStack(spacing: 0) {
                workflowStep(index: 0, title: isEn ? "Survey" : "测绘", done: workflow.hasSurvey)
                workflowConnector(done: workflow.hasSurvey)
                workflowStep(index: 1, title: isEn ? "Bearing" : "方位", done: workflow.hasBearing)
                workflowConnector(done: workflow.hasBearing)
                workflowStep(index: 2, title: isEn ? "Compute" : "计算", done: workflow.hasCalculation)
                workflowConnector(done: workflow.hasCalculation)
                workflowStep(index: 3, title: isEn ? "Report" : "报告", done: workflow.hasSurvey && workflow.hasBearing && workflow.hasCalculation)
            }
            .padding(.vertical, 6)
        }
    }

    private func workflowStep(index: Int, title: String, done: Bool) -> some View {
        let active = (index == 0 && nextStage == .survey) ||
            (index == 1 && nextStage == .bearing) ||
            (index == 2 && nextStage == .calculation) ||
            (index == 3 && nextStage == .report)

        return Button(action: { routeForStep(index) }) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(done ? Color.semJi.opacity(0.18) : (active ? Color.goldText.opacity(0.18) : Color.surfaceElevated))
                        .frame(width: 34, height: 34)
                    Image(systemName: done ? "checkmark" : stepIcon(index))
                        .adaptiveFont(size: 13, weight: .bold)
                        .foregroundColor(done ? .semJi : (active ? .goldText : .paperSub))
                }
                Text(title)
                    .adaptiveFont(size: 10, weight: active ? .bold : .medium)
                    .foregroundColor(active ? .paperText : .paperSub)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func workflowConnector(done: Bool) -> some View {
        Rectangle()
            .fill(done ? Color.semJi.opacity(0.7) : Color.strokeSoft)
            .frame(height: 1)
            .frame(maxWidth: 22)
            .padding(.bottom, 20)
    }

    private func stepIcon(_ index: Int) -> String {
        ["ruler", "safari.fill", "square.grid.3x3.fill", "doc.text.fill"][index]
    }

    private var nextAction: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                Image(systemName: nextActionIcon)
                    .adaptiveFont(size: 18, weight: .bold)
                    .foregroundColor(.goldText)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isEn ? "NEXT ACTION" : "下一步")
                        .adaptiveFont(size: 10, weight: .bold)
                        .foregroundColor(.goldText)
                    Text(nextActionTitle)
                        .adaptiveFont(size: 18, weight: .bold)
                        .foregroundColor(.paperText)
                }
                Spacer(minLength: 8)
            }
            Text(nextActionDetail)
                .adaptiveFont(size: 12)
                .foregroundColor(.paperSub)

            DSPrimaryActionButton(title: nextActionTitle, icon: "arrow.right") {
                performNextAction()
            }
        }
        .padding(16)
        .background(Color.surfaceElevated)
        .cornerRadius(DS.radiusM)
        .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(Color.strokeGold.opacity(0.8), lineWidth: 1))
    }

    private var recentWork: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(title: isEn ? "RECENT WORK" : "最近工作", detail: isEn ? "Saved signals from this project" : "本项目已保存的现场信号")

            VStack(spacing: 0) {
                workRow(icon: "ruler", title: isEn ? "Spatial survey" : "空间测绘", value: surveyValue, done: workflow.hasSurvey) { go(to: 0) }
                Divider().overlay(Color.strokeSoft)
                workRow(icon: "location.north.fill", title: isEn ? "Bearing sample" : "方位采样", value: bearingValue, done: workflow.hasBearing) { go(to: 2) }
                Divider().overlay(Color.strokeSoft)
                workRow(icon: "square.grid.3x3.fill", title: isEn ? "Professional calculation" : "专业计算", value: calculationValue, done: workflow.hasCalculation) { go(to: 3, feature: .xuanKong) }
            }
            .padding(.horizontal, 14)
            .background(Color.surfaceCard)
            .cornerRadius(DS.radiusM)
            .overlay(RoundedRectangle(cornerRadius: DS.radiusM).stroke(Color.strokeSoft, lineWidth: 1))
        }
    }

    private var surveyValue: String {
        guard let survey = workflow.survey else { return isEn ? "Not started" : "尚未开始" }
        if let area = survey.areaSqMeters {
            return isEn ? String(format: "%.1f m² · %d rooms", area, survey.roomCount) : String(format: "%.1f m² · %d 个房间", area, survey.roomCount)
        }
        return isEn ? "Captured" : "已完成采集"
    }

    private var bearingValue: String {
        guard let bearing = workflow.bearing else { return isEn ? "Not started" : "尚未开始" }
        let level = bearing.isLevel ? (isEn ? "level" : "水平") : (isEn ? "tilted" : "需调平")
        return String(format: "%.1f° · %@", bearing.bearingDegrees, level)
    }

    private var calculationValue: String {
        guard let calculation = workflow.calculation else { return isEn ? "Not started" : "尚未开始" }
        return isEn ? "\(calculation.moduleName) · Period \(calculation.period)" : "\(calculation.moduleName) · \(calculation.period) 运"
    }

    private func workRow(icon: String, title: String, value: String, done: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .adaptiveFont(size: 15)
                    .foregroundColor(done ? .semJi : .paperSub)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .adaptiveFont(size: 13, weight: .semibold)
                        .foregroundColor(.paperText)
                    Text(value)
                        .adaptiveFont(size: 11)
                        .foregroundColor(.paperSub)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: done ? "checkmark.circle.fill" : "chevron.right")
                    .adaptiveFont(size: 13, weight: .semibold)
                    .foregroundColor(done ? .semJi : .paperSub)
            }
            .frame(minHeight: 58)
        }
        .buttonStyle(.plain)
    }

    private var quickTools: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(title: isEn ? "QUICK TOOLS" : "快速工具", detail: isEn ? "Open a focused instrument" : "直接进入专项工具")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(workTools) { tool in
                    Button(action: tool.action) {
                        HStack(spacing: 9) {
                            Image(systemName: tool.icon)
                                .adaptiveFont(size: 18)
                                .foregroundColor(tool.tint)
                                .frame(width: 25)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tool.title)
                                    .adaptiveFont(size: 13, weight: .semibold)
                                    .foregroundColor(.paperText)
                                Text(tool.detail)
                                    .adaptiveFont(size: 10)
                                    .foregroundColor(.paperSub)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 62)
                        .background(Color.surfaceCard)
                        .cornerRadius(DS.radiusS)
                        .overlay(RoundedRectangle(cornerRadius: DS.radiusS).stroke(tool.tint.opacity(0.24), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func sectionHeading(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .adaptiveFont(size: 11, weight: .bold)
                .foregroundColor(.paperText)
            Spacer(minLength: 8)
            Text(detail)
                .adaptiveFont(size: 10)
                .foregroundColor(.paperSub)
                .lineLimit(1)
        }
    }

    private func go(to tab: Int, feature: AnalysisFeature? = nil) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        AppNavigationRouter.shared.requestRoute(tab: tab, feature: feature)
    }

    private func openReport() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        NotificationCenter.default.post(name: .didRequestWorkflowReport, object: nil)
    }

    private func performNextAction() {
        switch nextStage {
        case .survey: go(to: 0)
        case .bearing: go(to: 2)
        case .calculation: go(to: 3, feature: .xuanKong)
        case .report: openReport()
        }
    }

    private func routeForStep(_ index: Int) {
        switch index {
        case 0: go(to: 0)
        case 1: go(to: 2)
        case 2: go(to: 3, feature: .xuanKong)
        case 3: openReport()
        default: break
        }
    }

}
