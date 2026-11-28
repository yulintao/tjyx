import SwiftUI
import AVFoundation

// MARK: - 空间解谜主题（靛蓝 + 朱砂）
private enum SP {
    static let bg = Color(red: 0.949, green: 0.941, blue: 0.969)
    static let navy = Color(red: 0.153, green: 0.192, blue: 0.373)
    static let navySoft = Color(red: 0.192, green: 0.239, blue: 0.451)
    static let vermilion = Color(red: 0.851, green: 0.310, blue: 0.239)
    static let clue = Color(red: 0.294, green: 0.373, blue: 0.659)
    static let success = Color(red: 0.290, green: 0.502, blue: 0.388)
    static let danger = Color(red: 0.765, green: 0.231, blue: 0.180)
    static let ink = Color(red: 0.137, green: 0.165, blue: 0.290)
    static let sub = Color(red: 0.396, green: 0.427, blue: 0.549)
    static let line = Color(red: 0.843, green: 0.835, blue: 0.894)
    static let card = Color.white
    static let paper = Color(red: 0.976, green: 0.976, blue: 0.990)
    static let softNavy = Color(red: 0.153, green: 0.192, blue: 0.373, opacity: 0.08)
}

// MARK: - 解谜数据
struct SPClue: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let kind: String
    var verified: Bool
}

struct SPHypothesis: Identifiable {
    let id = UUID()
    let title: String
    let basis: String
    let confidence: Double
}

final class SpacePuzzleStore: ObservableObject {
    @Published var selectedTab: SPTab = .cases
    @Published var caseID = "CASE-0218"
    @Published var caseTitle = "三室两厅 · 午后通行受阻"
    @Published var stage = 0
    @Published var clues: [SPClue] = [
        SPClue(title: "墙面裂纹", detail: "客厅东墙 · 距地 1.2 m", kind: "照片", verified: true),
        SPClue(title: "动线交叉", detail: "玄关 → 客厅 1.8 m 通道", kind: "测距", verified: true),
        SPClue(title: "午后遮挡", detail: "14:00 采光 3.0 h", kind: "时序", verified: false)
    ]
    @Published var hypotheses: [SPHypothesis] = [
        SPHypothesis(title: "家具与门洞冲突", basis: "测距 02 + 时序 03", confidence: 0.72),
        SPHypothesis(title: "通道有效宽度不足", basis: "照片 04 + 测距 01", confidence: 0.58)
    ]
    @Published var confidence: Double = 0.72
    @Published var scanSummary = "等待现场扫描"
    @Published var spatialStatus = "尚未建立平面"

    func ingestFrame(_ frame: ARCapturedFrame) {
        guard let evidence = frame.evidence else {
            addClue(title: "现场照片", detail: "照片已采集 · 深度数据不可用", kind: "照片")
            return
        }
        let depth = evidence.depthSampleMeters.map { String(format: "%.2f m", $0) } ?? "无深度"
        let detail = "竖直面 \(evidence.verticalPlaneCount) · 深度 \(depth)"
        addClue(title: "现场照片", detail: detail, kind: "照片")
    }

    func ingestSurvey(_ survey: HouseSpatialSurvey, quality: Int, planeCount: Int) {
        let area = survey.dimensions.usableFloorArea
        let height = survey.dimensions.ceilingHeight
        scanSummary = String(format: "面积 %.1f㎡ · 净高 %.2f m · 房间 %d · 质量 %d/100",
                             area, height, survey.rooms.count, quality)
        spatialStatus = "平面已生成 · \(planeCount) 个识别平面"
        addClue(title: "空间扫描", detail: scanSummary, kind: "扫描")
    }

    func addClue(title: String, detail: String, kind: String) {
        clues.append(SPClue(title: title, detail: detail, kind: kind, verified: false))
        confidence = min(0.98, confidence + 0.02)
    }

    func verifyFirstPending() {
        if let idx = clues.firstIndex(where: { !$0.verified }) {
            clues[idx].verified = true
            confidence = min(0.98, confidence + 0.06)
        }
    }

    func advance() {
        stage = min(3, stage + 1)
    }
}

enum SPTab: Int, CaseIterable {
    case cases, capture, reasoning, report, me

    var title: String {
        switch self {
        case .cases: return "案件"
        case .capture: return "采集"
        case .reasoning: return "推理"
        case .report: return "报告"
        case .me: return "我的"
        }
    }

    var icon: String {
        switch self {
        case .cases: return "rectangle.stack"
        case .capture: return "camera.viewfinder"
        case .reasoning: return "network"
        case .report: return "doc.text.magnifyingglass"
        case .me: return "gearshape"
        }
    }
}

// MARK: - 通用组件
struct SPCard<Content: View>: View {
    let content: Content
    let fill: Color
    init(fill: Color = SP.card, @ViewBuilder content: () -> Content) {
        self.fill = fill
        self.content = content()
    }
    var body: some View {
        content
            .padding(16)
            .background(fill)
            .cornerRadius(18)
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(fill == SP.card ? SP.line : Color.clear, lineWidth: 1))
            .shadow(color: Color.black.opacity(0.05), radius: 12, x: 0, y: 4)
    }
}

struct SPPrimaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(LinearGradient(gradient: Gradient(colors: [SP.navy, SP.navySoft]),
                                           startPoint: .leading, endPoint: .trailing))
                .cornerRadius(12)
                .shadow(color: SP.navy.opacity(0.18), radius: 8, x: 0, y: 4)
        }
    }
}

struct SPSecondaryButton: View {
    let title: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(SP.navy)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(Color.white)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(SP.line, lineWidth: 1))
        }
    }
}

struct SPBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12))
            .cornerRadius(9)
    }
}

struct SPMetricTile: View {
    let title: String
    let value: String
    var accent = false
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 9, weight: .medium)).foregroundColor(SP.sub)
            Text(value).font(.system(size: 14, weight: .bold)).foregroundColor(accent ? SP.vermilion : SP.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(SP.paper)
        .cornerRadius(10)
    }
}

struct SPHeader: View {
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle().fill(SP.vermilion).frame(width: 5, height: 5)
                Text("SPATIAL PUZZLE")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(SP.vermilion)
                    .kerning(1.1)
                Spacer()
            }
            HStack(spacing: 10) {
                Rectangle().fill(SP.vermilion).frame(width: 4, height: 30).cornerRadius(2)
                Text(title).font(.system(size: 23, weight: .bold)).foregroundColor(SP.ink)
                Spacer(minLength: 0)
            }
            Text(subtitle).font(.system(size: 12)).foregroundColor(SP.sub).padding(.leading, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SPHeroPanel: View {
    @ObservedObject var store: SpacePuzzleStore
    var body: some View {
        ZStack(alignment: .topLeading) {
            LinearGradient(gradient: Gradient(colors: [SP.navy, SP.navySoft]),
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            Circle().fill(Color.white.opacity(0.07)).frame(width: 180, height: 180)
                .offset(x: 220, y: -80)
            Circle().stroke(SP.vermilion.opacity(0.35), lineWidth: 1).frame(width: 120, height: 120)
                .offset(x: 260, y: 40)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SPBadge(text: store.caseID, color: SP.vermilion)
                    SPBadge(text: "进行中", color: .white)
                    Spacer()
                }
                Text(store.caseTitle)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("线索").font(.system(size: 9)).foregroundColor(Color.white.opacity(0.65))
                                Text("\(store.clues.count)/12").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("假设").font(.system(size: 9)).foregroundColor(Color.white.opacity(0.65))
                                Text("\(store.hypotheses.count)").font(.system(size: 15, weight: .bold)).foregroundColor(.white)
                            }
                        }
                        Text("现场数据已归档 · 可继续推理")
                            .font(.system(size: 10)).foregroundColor(Color.white.opacity(0.7))
                    }
                    Spacer()
                    ZStack {
                        Circle().stroke(Color.white.opacity(0.18), lineWidth: 6)
                        Circle().trim(from: 0, to: CGFloat(store.confidence))
                            .stroke(SP.vermilion,
                                    style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 0) {
                            Text("\(Int(store.confidence * 100))%")
                                .font(.system(size: 14, weight: .bold)).foregroundColor(.white)
                            Text("置信").font(.system(size: 8)).foregroundColor(Color.white.opacity(0.65))
                        }
                    }
                    .frame(width: 66, height: 66)
                }
            }
            .padding(18)
        }
        .cornerRadius(20)
        .shadow(color: SP.navy.opacity(0.22), radius: 16, x: 0, y: 8)
    }
}

struct SPStageBar: View {
    let stage: Int
    private let labels = ["接案", "采集", "推理", "交付"]
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                HStack(spacing: 6) {
                    ZStack {
                        Circle().fill(i < stage ? SP.navy : (i == stage ? SP.vermilion : SP.paper))
                            .frame(width: 20, height: 20)
                        if i < stage {
                            Image(systemName: "checkmark").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        } else {
                            Text("\(i + 1)").font(.system(size: 9, weight: .bold))
                                .foregroundColor(i == stage ? .white : SP.sub)
                        }
                    }
                    Text(labels[i])
                        .font(.system(size: 10, weight: i == stage ? .bold : .medium))
                        .foregroundColor(i == stage ? SP.vermilion : SP.sub)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(i == stage ? SP.vermilion.opacity(0.08) : Color.clear)
                .cornerRadius(12)
            }
        }
    }
}

struct SPCameraStage: View {
    let label: String
    var body: some View {
        ZStack {
            Color(red: 0.094, green: 0.129, blue: 0.149)
            VStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1)
                    Spacer(minLength: 0)
                }
            }
            .padding(.vertical, 12)
            HStack(spacing: 0) {
                ForEach(0..<5, id: \.self) { _ in
                    Rectangle().fill(Color.white.opacity(0.07)).frame(width: 1)
                    Spacer(minLength: 0)
                }
            }
            .padding(.horizontal, 12)

            RoundedRectangle(cornerRadius: 6)
                .stroke(SP.vermilion, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .frame(width: 190, height: 140)

            Circle().stroke(Color.white.opacity(0.75), lineWidth: 1.2).frame(width: 38, height: 38)
            Rectangle().fill(Color.white.opacity(0.35)).frame(width: 56, height: 1)
            Rectangle().fill(Color.white.opacity(0.35)).frame(width: 1, height: 56)

            VStack {
                HStack {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.55))
                        .cornerRadius(6)
                    Spacer()
                }
                Spacer()
            }
            .padding(16)
        }
        .frame(height: 220)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(SP.line, lineWidth: 1))
    }
}

struct SPMapCanvas: View {
    @State private var selectedPin: Int? = 1
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.933, green: 0.949, blue: 0.933)

                Path { path in
                    path.move(to: CGPoint(x: geo.size.width * 0.12, y: geo.size.height * 0.82))
                    path.addLine(to: CGPoint(x: geo.size.width * 0.86, y: geo.size.height * 0.16))
                }
                .stroke(SP.clue.opacity(0.25), lineWidth: 8)

                Path { path in
                    path.move(to: CGPoint(x: 10, y: geo.size.height * 0.62))
                    path.addLine(to: CGPoint(x: geo.size.width - 10, y: geo.size.height * 0.62))
                }
                .stroke(SP.vermilion.opacity(0.3), lineWidth: 5)

                RoundedRectangle(cornerRadius: 6)
                    .fill(SP.success.opacity(0.16))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(SP.success, lineWidth: 1))
                    .frame(width: geo.size.width * 0.36, height: geo.size.height * 0.28)
                    .position(x: geo.size.width * 0.28, y: geo.size.height * 0.28)

                RoundedRectangle(cornerRadius: 6)
                    .fill(SP.vermilion.opacity(0.14))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(SP.vermilion, lineWidth: 1))
                    .frame(width: geo.size.width * 0.32, height: geo.size.height * 0.26)
                    .position(x: geo.size.width * 0.72, y: geo.size.height * 0.62)

                ForEach(1...5, id: \.self) { i in
                    Button {
                        selectedPin = i
                    } label: {
                        ZStack {
                            if selectedPin == i {
                                Circle().stroke(SP.vermilion.opacity(0.45), lineWidth: 2)
                                    .frame(width: 36, height: 36)
                            }
                            Circle().fill(i == 1 ? SP.danger : (selectedPin == i ? SP.navy : SP.vermilion))
                                .frame(width: selectedPin == i ? 28 : 22, height: selectedPin == i ? 28 : 22)
                                .shadow(color: SP.navy.opacity(0.25), radius: 5, x: 0, y: 2)
                            Text("\(i)").font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .position(x: geo.size.width * (0.18 + CGFloat(i) * 0.15),
                              y: geo.size.height * (0.75 - CGFloat(i) * 0.11))
                }

                if let pin = selectedPin {
                    HStack(spacing: 6) {
                        Circle().fill(pin == 1 ? SP.danger : SP.vermilion).frame(width: 6, height: 6)
                        Text("线索点 0\(pin)").font(.system(size: 9, weight: .semibold)).foregroundColor(SP.ink)
                        Text(pin == 1 ? "路径冲突" : (pin == 2 ? "采光遮挡" : "已定位"))
                            .font(.system(size: 9)).foregroundColor(SP.sub)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.92))
                    .cornerRadius(10)
                    .position(x: geo.size.width * 0.5, y: geo.size.height - 24)
                }
            }
        }
        .frame(height: 220)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(SP.line, lineWidth: 1))
        .shadow(color: SP.ink.opacity(0.06), radius: 10, x: 0, y: 4)
    }
}

// MARK: - 根视图
public struct SpacePuzzleRootView: View {
    @StateObject private var store = SpacePuzzleStore()

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            ZStack {
                currentView
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            tabBar
        }
        .background(
            LinearGradient(gradient: Gradient(colors: [SP.bg, SP.paper]),
                           startPoint: .top, endPoint: .bottom)
                .edgesIgnoringSafeArea(.all)
        )
        .accentColor(SP.navy)
        .preferredColorScheme(.light)
    }

    @ViewBuilder
    private var currentView: some View {
        switch store.selectedTab {
        case .cases: CaseBoardView(store: store)
        case .capture: CaptureHubView(store: store)
        case .reasoning: ReasoningHubView(store: store)
        case .report: CaseReportView(store: store)
        case .me: MeHubView(store: store)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SPTab.allCases, id: \.self) { tab in
                Button {
                    store.selectedTab = tab
                } label: {
                    ZStack {
                        if store.selectedTab == tab {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(SP.softNavy)
                                .frame(height: 48)
                                .padding(.horizontal, 4)
                        }
                        VStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 18, weight: .semibold))
                            Text(tab.title)
                                .font(.system(size: 10, weight: store.selectedTab == tab ? .bold : .medium))
                        }
                        .foregroundColor(store.selectedTab == tab ? SP.vermilion : SP.sub)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .contentShape(Rectangle())
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background(Color.white)
        .overlay(Rectangle().fill(SP.line).frame(height: 1), alignment: .top)
        .shadow(color: SP.ink.opacity(0.06), radius: 12, x: 0, y: -3)
    }
}

// MARK: - 01 案件台
struct CaseBoardView: View {
    @ObservedObject var store: SpacePuzzleStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SPHeader(title: "空间案件台", subtitle: "把现场问题拆成可验证的线索")
                SPHeroPanel(store: store)
                SPCard { SPStageBar(stage: store.stage) }
                SPCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("案件列表").font(.system(size: 13, weight: .bold)).foregroundColor(SP.ink)
                            Spacer()
                            SPBadge(text: "3 个案件", color: SP.clue)
                        }
                        ForEach(0..<3, id: \.self) { i in
                            HStack(spacing: 10) {
                                ZStack {
                                    Circle().fill(i == 0 ? SP.vermilion.opacity(0.12) : SP.paper)
                                        .frame(width: 28, height: 28)
                                    Image(systemName: i == 0 ? "hammer" : (i == 1 ? "archivebox" : "clock"))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(i == 0 ? SP.vermilion : SP.sub)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("CASE-021\(8 - i)")
                                        .font(.system(size: 11, weight: .semibold)).foregroundColor(SP.ink)
                                    Text(i == 0 ? "进行中 · 三室两厅" : (i == 1 ? "已归档 · 复式" : "待复核 · 公寓"))
                                        .font(.system(size: 9)).foregroundColor(SP.sub)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(SP.sub)
                            }
                            .padding(.vertical, 4)
                            if i < 2 { Divider().foregroundColor(SP.line) }
                        }
                    }
                }
                HStack(spacing: 10) {
                    SPSecondaryButton(title: "新建案件") { store.advance() }
                    SPPrimaryButton(title: "继续案件") { store.selectedTab = .capture }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 02/03 采集中心
struct CaptureHubView: View {
    @ObservedObject var store: SpacePuzzleStore
    @State private var mode = 0
    @StateObject private var camera = CameraPreviewController()
    @StateObject private var spatial = ARSpatialSurveyModel()
    @State private var hasCameraPermission = false
    @State private var cameraTrigger = 0
    @State private var scanMessage = "对准现场并保持设备稳定"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SPHeader(title: mode == 0 ? "AR 线索采集" : "空间扫描测绘",
                         subtitle: mode == 0 ? "对准异常，拍照并测量" : "平面 \(spatial.planeCount) · 质量 \(spatial.scanQualityScore)/100")
                Picker("", selection: $mode) {
                    Text("线索采集").tag(0)
                    Text("空间扫描").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())

                if mode == 0 {
                    if hasCameraPermission {
                        CameraExclusiveGate {
                            CameraPreviewView(
                                controller: camera,
                                cameraPosition: .back,
                                isActive: true,
                                captureTrigger: cameraTrigger,
                                onFrameCaptured: { frame in
                                    if let frame = frame { store.ingestFrame(frame) }
                                }
                            )
                            .frame(height: 220)
                            .clipped()
                            .cornerRadius(14)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(SP.vermilion, style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                                    .frame(width: 190, height: 140)
                            )
                        }
                    } else {
                        SPCameraStage(label: "相机未授权 · 点击下方开启")
                        Button("开启相机") { checkCameraPermission() }
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(SP.vermilion)
                    }

                    SPCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("线索清单").font(.system(size: 13, weight: .bold)).foregroundColor(SP.ink)
                                Spacer()
                                SPBadge(text: "\(store.clues.count) 条", color: SP.vermilion)
                            }
                            HStack(spacing: 8) {
                                SPMetricTile(title: "照片", value: "\(store.clues.filter { $0.kind == "照片" }.count)", accent: true)
                                SPMetricTile(title: "测距", value: "\(store.clues.filter { $0.kind == "测距" }.count)")
                                SPMetricTile(title: "扫描", value: "\(store.clues.filter { $0.kind == "扫描" }.count)")
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        Button("拍照采集") { cameraTrigger += 1 }
                        Button("标尺") {
                            let span = spatial.distance.map { String(format: "%.2f m", $0) } ?? "等待测距"
                            store.addClue(title: "点对点跨度", detail: span, kind: "测距")
                        }
                        SPPrimaryButton(title: "标记异常") {
                            store.addClue(title: "异常标记", detail: "待复核", kind: "观察")
                            store.selectedTab = .reasoning
                        }
                    }
                    .buttonStyle(.borderless)
                } else {
                    CameraExclusiveGate {
                        ARSpatialPreviewView(model: spatial)
                            .frame(height: 260)
                            .clipped()
                            .cornerRadius(14)
                    }

                    SPCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("实测摘要").font(.system(size: 13, weight: .bold)).foregroundColor(SP.ink)
                                Spacer()
                                SPBadge(text: spatial.lidarAvailable ? "LiDAR" : "AR", color: SP.clue)
                            }
                            HStack(spacing: 8) {
                                SPMetricTile(title: "平面", value: "\(spatial.planeCount)")
                                SPMetricTile(title: "网格", value: "\(spatial.meshAnchorCount)")
                                SPMetricTile(title: "质量", value: "\(spatial.scanQualityScore)", accent: true)
                            }
                            Text(store.scanSummary).font(.system(size: 11)).foregroundColor(SP.sub)
                            Text("净高 \(spatial.estimatedRoomHeightMeters.map { String(format: "%.2f m", $0) } ?? "待识别")")
                                .font(.system(size: 10)).foregroundColor(SP.clue)
                            Text(scanMessage).font(.system(size: 10)).foregroundColor(SP.danger)
                        }
                    }

                    HStack(spacing: 8) {
                        Button("打点") { spatial.cornerPinActive.toggle() }
                        Button("测距") {
                            let span = spatial.distance.map { String(format: "%.2f m", $0) } ?? "等待测距"
                            store.addClue(title: "空间测距", detail: span, kind: "测距")
                        }
                        SPPrimaryButton(title: "生成平面") { generateSurvey() }
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .onAppear(perform: checkCameraPermission)
        .onDisappear { spatial.pause() }
    }

    private func checkCameraPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasCameraPermission = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { self.hasCameraPermission = granted }
            }
        default:
            hasCameraPermission = false
        }
    }

    private func generateSurvey() {
        guard spatial.hasHeadingReference else {
            scanMessage = "请先取得航向参考，再生成平面"
            return
        }
        guard let survey = spatial.buildSpatialSurvey() else {
            scanMessage = "扫描数据不足，请继续扫描墙面与地面"
            return
        }
        store.ingestSurvey(survey, quality: spatial.scanQualityScore, planeCount: spatial.planeCount)
        SpatialWorkflowStore.shared.recordSurvey(
            source: spatial.lidarAvailable ? "AR + LiDAR Scan" : "ARKit Spatial Scan",
            widthMeters: Double(survey.dimensions.totalWidth),
            depthMeters: Double(survey.dimensions.totalDepth),
            areaSqMeters: Double(survey.dimensions.usableFloorArea),
            ceilingHeightMeters: Double(survey.dimensions.ceilingHeight),
            roomCount: survey.rooms.count,
            scanQualityScore: spatial.scanQualityScore
        )
        scanMessage = store.spatialStatus
        store.selectedTab = .reasoning
    }
}

// MARK: - 04~08 推理中心
struct ReasoningHubView: View {
    @ObservedObject var store: SpacePuzzleStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var mode = 0
    private let modes = ["平面推理", "动线网格", "房间诊断", "时序记录", "推理板"]

    var body: some View {
        Group {
            if sizeClass == .regular {
                VStack(alignment: .leading, spacing: 14) {
                    SPHeader(title: modes[mode], subtitle: "连接线索，形成可验证假设")
                    HStack(alignment: .top, spacing: 16) {
                        modeList(isVertical: true)
                            .frame(width: 172)
                        ScrollView {
                            modeContent
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 24)
                        }
                    }
                }
                .padding(20)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SPHeader(title: modes[mode], subtitle: "连接线索，形成可验证假设")
                        modeList(isVertical: false)
                        modeContent
                    }
                    .padding(16)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var modeContent: some View {
        switch mode {
        case 0: FloorplanReasoningView(store: store)
        case 1: FlowGridView(store: store)
        case 2: RoomDiagnosisView(store: store)
        case 3: TimelineView(store: store)
        default: EvidenceBoardView(store: store)
        }
    }

    @ViewBuilder
    private func modeList(isVertical: Bool) -> some View {
        if isVertical {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(0..<modes.count, id: \.self) { i in
                    modeButton(i)
                }
                Spacer(minLength: 0)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<modes.count, id: \.self) { i in
                        modeButton(i)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private func modeButton(_ i: Int) -> some View {
        Button {
            mode = i
        } label: {
            HStack(spacing: 6) {
                if i == mode {
                    Circle().fill(SP.vermilion).frame(width: 5, height: 5)
                }
                Text(modes[i])
                    .font(.system(size: 11, weight: i == mode ? .bold : .medium))
                    .foregroundColor(i == mode ? .white : SP.ink)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(i == mode ? SP.navy : Color.white)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14)
                .stroke(i == mode ? SP.navy : SP.line, lineWidth: 1))
            .shadow(color: i == mode ? SP.navy.opacity(0.18) : Color.clear, radius: 6, x: 0, y: 3)
        }
    }
}

struct FloorplanReasoningView: View {
    @ObservedObject var store: SpacePuzzleStore
    var body: some View {
        VStack(spacing: 12) {
            SPMapCanvas()
            SPCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("线索点 \(store.clues.count) · 假设 \(store.hypotheses.count) 条")
                        .font(.system(size: 13, weight: .bold)).foregroundColor(SP.ink)
                    Text("点 01 与点 03 存在路径冲突").font(.system(size: 11)).foregroundColor(SP.sub)
                }
            }
            HStack(spacing: 8) {
                Button("导入图纸") { store.addClue(title: "图纸基准", detail: "已导入", kind: "图纸") }
                Button("自动识别") { store.addClue(title: "房间识别", detail: "4 个空间", kind: "识别") }
                SPPrimaryButton(title: "连线推理") { store.selectedTab = .reasoning }
            }
            .buttonStyle(.borderless)
        }
    }
}

struct FlowGridView: View {
    @ObservedObject var store: SpacePuzzleStore
    private let values = ["通", "阻", "静", "通", "中", "动", "行", "静", "通"]
    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { i in
                    Text(values[i])
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(i == 1 ? .white : (values[i] == "阻" ? SP.danger : SP.ink))
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(i == 1 ? SP.navy : Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(SP.line, lineWidth: 1))
                }
            }
            SPCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("瓶颈：玄关 → 客厅（午后拥堵）").font(.system(size: 13, weight: .bold)).foregroundColor(SP.ink)
                    Text("来源：3 条时序记录 + 2 个测距点").font(.system(size: 11)).foregroundColor(SP.sub)
                }
            }
            HStack(spacing: 8) {
                Button("查看动线") { store.verifyFirstPending() }
                SPPrimaryButton(title: "添加假设") {
                    store.hypotheses.append(SPHypothesis(title: "通道宽度不足", basis: "动线网格", confidence: 0.61))
                }
            }
            .buttonStyle(.borderless)
        }
    }
}

struct RoomDiagnosisView: View {
    @ObservedObject var store: SpacePuzzleStore
    private let values = ["光足", "风弱", "噪高", "交叉", "中心", "储物", "通行", "安静", "潮"]
    var body: some View {
        VStack(spacing: 12) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9, id: \.self) { i in
                    Text(values[i])
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(i == 0 ? .white : SP.ink)
                        .frame(maxWidth: .infinity, minHeight: 54)
                        .background(i == 0 ? SP.navy : Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(SP.line, lineWidth: 1))
                }
            }
            SPCard {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(["主卧 · 采光 2.1 h", "厨房 · 动线交叉", "卫浴 · 通风弱"], id: \.self) { item in
                        HStack {
                            Circle().fill(SP.vermilion).frame(width: 6, height: 6)
                            Text(item).font(.system(size: 11)).foregroundColor(SP.ink)
                            Spacer()
                        }
                    }
                }
            }
            HStack(spacing: 8) {
                Button("查看证据") { store.selectedTab = .report }
                SPPrimaryButton(title: "提出方案") { store.advance() }
            }
            .buttonStyle(.borderless)
        }
    }
}

struct TimelineView: View {
    @ObservedObject var store: SpacePuzzleStore
    var body: some View {
        VStack(spacing: 12) {
            SPCard {
                VStack(spacing: 0) {
                    HStack {
                        ForEach(["09:00", "14:00", "21:00"], id: \.self) { t in
                            Text(t).font(.system(size: 10, weight: .semibold)).foregroundColor(SP.sub)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    ZStack(alignment: .leading) {
                        Rectangle().fill(SP.line).frame(height: 2)
                        HStack {
                            ForEach(0..<3, id: \.self) { i in
                                Circle().fill(i == 2 ? SP.danger : SP.vermilion).frame(width: 12, height: 12)
                                if i < 2 { Spacer() }
                            }
                        }
                    }
                    .frame(height: 24)
                    HStack {
                        Text("采光 2.1h").font(.system(size: 9)).foregroundColor(SP.ink).frame(maxWidth: .infinity)
                        Text("客厅 3.0h").font(.system(size: 9)).foregroundColor(SP.ink).frame(maxWidth: .infinity)
                        Text("噪音 61dB").font(.system(size: 9)).foregroundColor(SP.danger).frame(maxWidth: .infinity)
                    }
                }
            }
            SPCard {
                VStack(alignment: .leading, spacing: 6) {
                    Text("21:00 主卧噪音 61 dB").font(.system(size: 13, weight: .bold)).foregroundColor(SP.ink)
                    Text("高于日间均值 9 dB · 来源待确认").font(.system(size: 11)).foregroundColor(SP.sub)
                }
            }
            HStack(spacing: 8) {
                Button("上一时段") { store.verifyFirstPending() }
                SPPrimaryButton(title: "回到当前") { store.selectedTab = .reasoning }
            }
            .buttonStyle(.borderless)
        }
    }
}

struct EvidenceBoardView: View {
    @ObservedObject var store: SpacePuzzleStore
    @State private var selectedClueID: UUID?
    var body: some View {
        let items = Array(store.clues.prefix(3))
        VStack(spacing: 12) {
            SPCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("推理板 · \(store.caseID)").font(.system(size: 13, weight: .bold)).foregroundColor(SP.ink)
                        Spacer()
                        SPBadge(text: "\(items.count) 条线索", color: SP.clue)
                    }

                    HStack(spacing: 4) {
                        ForEach(items) { clue in
                            Button {
                                selectedClueID = clue.id
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Rectangle().fill(clue.verified ? SP.vermilion : SP.clue).frame(height: 3)
                                    Text(clue.title).font(.system(size: 10, weight: .bold)).foregroundColor(SP.ink)
                                    Text(clue.kind).font(.system(size: 9)).foregroundColor(SP.sub)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectedClueID == clue.id ? SP.softNavy : Color.white)
                                .cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedClueID == clue.id ? SP.vermilion : SP.line,
                                            lineWidth: selectedClueID == clue.id ? 1.5 : 1))
                            }
                            .buttonStyle(.plain)

                            if clue.id != items.last?.id {
                                Rectangle().fill(SP.vermilion.opacity(0.35)).frame(height: 2)
                                    .frame(maxWidth: 18)
                            }
                        }
                    }

                    if let selected = items.first(where: { $0.id == selectedClueID }) {
                        HStack(spacing: 8) {
                            Image(systemName: selected.verified ? "checkmark.seal.fill" : "circle.dashed")
                                .foregroundColor(selected.verified ? SP.success : SP.vermilion)
                                .font(.system(size: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selected.detail).font(.system(size: 10)).foregroundColor(SP.ink)
                                Text(selected.verified ? "已验证" : "待验证")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundColor(selected.verified ? SP.success : SP.vermilion)
                            }
                            Spacer()
                        }
                        .padding(9)
                        .background(SP.paper)
                        .cornerRadius(10)
                    }

                    Text("当前假设：客厅午后通行受阻，源于家具与门洞冲突")
                        .font(.system(size: 10)).foregroundColor(SP.ink)
                    ProgressView(value: store.confidence).accentColor(SP.success)
                    Text("置信度 \(Int(store.confidence * 100))% · 待验证 \(store.clues.filter { !$0.verified }.count) 条")
                        .font(.system(size: 10, weight: .semibold)).foregroundColor(SP.success)
                }
            }
            HStack(spacing: 8) {
                Button("验证线索") { store.verifyFirstPending() }
                SPPrimaryButton(title: "生成报告") { store.selectedTab = .report }
            }
            .buttonStyle(.borderless)
        }
        .onAppear {
            if selectedClueID == nil { selectedClueID = items.first?.id }
        }
    }
}

// MARK: - 09 案件报告
struct CaseReportView: View {
    @ObservedObject var store: SpacePuzzleStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SPHeader(title: "案件报告", subtitle: "证据链 → 假设 → 处理建议")
                SPCard(fill: SP.paper) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            SPBadge(text: "CASE FILE", color: SP.vermilion)
                            Spacer()
                            SPBadge(text: store.caseID, color: SP.clue)
                        }
                        Text("空间案件报告")
                            .font(.system(size: 20, weight: .bold)).foregroundColor(SP.ink)
                        Text(store.caseTitle)
                            .font(.system(size: 11)).foregroundColor(SP.sub)
                        Divider().foregroundColor(SP.line)
                        HStack(spacing: 8) {
                            SPMetricTile(title: "证据", value: "\(store.clues.count)")
                            SPMetricTile(title: "假设", value: "\(store.hypotheses.count)")
                            SPMetricTile(title: "置信", value: "\(Int(store.confidence * 100))%", accent: true)
                        }
                        HStack {
                            Spacer()
                            Text("证").font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                .frame(width: 40, height: 40).background(SP.clue).cornerRadius(6)
                                .shadow(color: SP.clue.opacity(0.3), radius: 8, x: 0, y: 3)
                        }
                    }
                }
                SPCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("主要假设").font(.system(size: 13, weight: .bold)).foregroundColor(SP.ink)
                        ForEach(store.hypotheses) { h in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(h.title).font(.system(size: 11, weight: .semibold)).foregroundColor(SP.ink)
                                Text("\(h.basis) · \(Int(h.confidence * 100))%").font(.system(size: 9)).foregroundColor(SP.sub)
                                Divider()
                            }
                        }
                    }
                }
                HStack(spacing: 8) {
                    Button("保存图片") { store.advance() }
                    SPPrimaryButton(title: "分享报告") { store.advance() }
                }
                .buttonStyle(.borderless)
            }
            .padding(16)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 10/11 我的：设置与会员
struct MeHubView: View {
    @ObservedObject var store: SpacePuzzleStore
    @State private var mode = 0
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SPHeader(title: mode == 0 ? "设置" : "会员", subtitle: mode == 0 ? "案件数据仅存本机" : "解锁完整案件能力")
                Picker("", selection: $mode) {
                    Text("设置").tag(0)
                    Text("会员").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                if mode == 0 {
                    SPCard {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(["会员中心", "资料数据", "语言 · 简体中文", "关于与条款", "案件档案"], id: \.self) { item in
                                HStack {
                                    Text(item).font(.system(size: 12)).foregroundColor(SP.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 10)).foregroundColor(SP.sub)
                                }
                            }
                        }
                    }
                    SPCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("案件数据 3 个").font(.system(size: 13, weight: .bold)).foregroundColor(SP.ink)
                            Text("进行中 1 · 已归档 2").font(.system(size: 11)).foregroundColor(SP.sub)
                        }
                    }
                    SPPrimaryButton(title: "打开案件档案") { store.selectedTab = .cases }
                } else {
                    ZStack(alignment: .topLeading) {
                        LinearGradient(gradient: Gradient(colors: [SP.navy, SP.navySoft]),
                                       startPoint: .topLeading, endPoint: .bottomTrailing)
                        Circle().fill(Color.white.opacity(0.08)).frame(width: 150, height: 150)
                            .offset(x: 210, y: -60)
                        Circle().stroke(SP.vermilion.opacity(0.4), lineWidth: 1).frame(width: 100, height: 100)
                            .offset(x: 250, y: 30)
                        VStack(alignment: .leading, spacing: 10) {
                            SPBadge(text: "PRO", color: SP.vermilion)
                            Text("解锁完整案件能力")
                                .font(.system(size: 19, weight: .bold)).foregroundColor(.white)
                            Text("无限案件 · 自动识别 · 报告导出")
                                .font(.system(size: 11)).foregroundColor(Color.white.opacity(0.75))
                        }
                        .padding(18)
                    }
                    .cornerRadius(18)
                    .shadow(color: SP.navy.opacity(0.2), radius: 12, x: 0, y: 6)
                    SPCard {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(["年度专业版 · 推荐", "永久专业版", "单案解锁"], id: \.self) { item in
                                HStack {
                                    Text(item).font(.system(size: 11)).foregroundColor(SP.ink)
                                    Spacer()
                                    Text("价格见商店").font(.system(size: 9)).foregroundColor(SP.sub)
                                }
                                .padding(.vertical, 6)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        Button("恢复购买") { store.advance() }
                        SPPrimaryButton(title: "立即购买") { store.advance() }
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(16)
            .padding(.bottom, 24)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }
}
