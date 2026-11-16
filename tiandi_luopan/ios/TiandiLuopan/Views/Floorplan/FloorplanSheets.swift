import SwiftUI
import UIKit

// MARK: - 户型立极的弹窗族（报告分享 / 房间类型编辑 / 确认框 / 房间详勘）
// 从 FloorplanView.swift 抽出：四个类型都是自包含的，只依赖已公开的模型与调色板。

struct FloorplanReportShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX, y: controller.view.bounds.midY,
                                        width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct FloorplanRoomTypeEditor: View {
    let titleKey: String
    let room: FloorplanRoom?
    let onDelete: (() -> Void)?
    let onSelect: (FloorplanRoomType) -> Void
    @Environment(\.presentationMode) private var presentationMode
    @State private var showDeleteConfirmation = false

    init(titleKey: String = "floorplan_room_type", room: FloorplanRoom?, onDelete: (() -> Void)? = nil, onSelect: @escaping (FloorplanRoomType) -> Void) {
        self.titleKey = titleKey
        self.room = room
        self.onDelete = onDelete
        self.onSelect = onSelect
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(FloorplanRoomType.allCases) { type in
                        Button(action: {
                            onSelect(type)
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: type.iconName)
                                    .frame(width: 24)
                                    .foregroundColor(.yanCyan)
                                Text(type.localizedName)
                                    .foregroundColor(.primary)
                                Spacer()
                                if room?.type == type {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                } header: {
                    Text(LocalizationManager.shared.t(titleKey))
                }
                if onDelete != nil {
                    Section {
                        Button(action: { showDeleteConfirmation = true }) {
                            Label(LocalizationManager.shared.t("floorplan_delete_room"), systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            .navigationBarTitle(LocalizationManager.shared.t(titleKey), displayMode: .inline)
            .navigationBarItems(trailing: Button(LocalizationManager.shared.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay(
            Group {
                if showDeleteConfirmation, let onDelete = onDelete {
                    FloorplanConfirmDialog(
                        title: LocalizationManager.shared.t("floorplan_delete_room"),
                        message: LocalizationManager.shared.t("floorplan_delete_confirm"),
                        confirmTitle: LocalizationManager.shared.t("floorplan_delete_room"),
                        cancelTitle: LocalizationManager.shared.t("cancel"),
                        onConfirm: {
                            showDeleteConfirmation = false
                            onDelete()
                            presentationMode.wrappedValue.dismiss()
                        },
                        onCancel: { showDeleteConfirmation = false }
                    )
                }
            }
        )
    }
}

/// Self-contained confirmation dialog. It does not depend on UIKit alert
/// presentation, so it keeps working while the host view is re-rendered by
/// high-frequency sensor updates.
struct FloorplanConfirmDialog: View {
    let title: String
    let message: String
    let confirmTitle: String
    let cancelTitle: String?
    var confirmColor: Color = Color.red.opacity(0.85)
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onCancel() }
            VStack(spacing: 14) {
                Text(title)
                    .adaptiveFont(size: 16, weight: .bold)
                    .foregroundColor(.white)
                Text(message)
                    .adaptiveFont(size: 13)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    if let cancelTitle = cancelTitle {
                        Button(action: onCancel) {
                            Text(cancelTitle)
                                .adaptiveFont(size: 14, weight: .semibold)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.12))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    Button(action: onConfirm) {
                        Text(confirmTitle)
                            .adaptiveFont(size: 14, weight: .semibold)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(confirmColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(18)
            .frame(maxWidth: 300)
            .background(Color(red: 0.14, green: 0.14, blue: 0.18))
            .cornerRadius(14)
        }
    }
}

// MARK: - 房间风水体检详勘弹窗 (Room Audit Detail Sheet)
public struct RoomAuditDetailSheet: View {
    public let room: FloorplanRoom
    private let onEditType: ((FloorplanRoomType) -> Void)?
    private let onDelete: (() -> Void)?
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showTypeEditor = false
    @State private var showDeleteConfirmation = false
    
    public init(
        room: FloorplanRoom,
        onEditType: ((FloorplanRoomType) -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.room = room
        self.onEditType = onEditType
        self.onDelete = onDelete
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appInk.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // 1. 顶部房间名与方位徽章
                        HStack(spacing: 12) {
                            Image(systemName: room.type.iconName)
                                .adaptiveFont(size: 24)
                                .foregroundColor(Color.yanGoldDeep)
                                .frame(width: 44, height: 44)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(room.type.localizedName)
                                    .adaptiveFont(size: 16, weight: .bold)
                                    .foregroundColor(.white)
                                
                                Text(room.palaceName.isEmpty ? lang.t("floorplan_analyzing_center") : "\(lang.t("floorplan_palace_prefix"))\(room.palaceName)")
                                    .adaptiveFont(size: 12)
                                    .foregroundColor(Color.yanCyan)
                            }
                            
                            Spacer()
                            
                            Text(localizedLevel)
                                .adaptiveFont(size: 12, weight: .bold)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(badgeColor.opacity(0.2))
                                .foregroundColor(badgeColor)
                                .cornerRadius(6)
                        }
                        .padding(14)
                        .background(Color.appInkRaised)
                        .cornerRadius(12)

                        if let onEditType = onEditType {
                            Button(action: { showTypeEditor = true }) {
                                Label(lang.t("floorplan_room_type"), systemImage: "tag")
                                    .adaptiveFont(size: 12, weight: .semibold)
                                    .foregroundColor(.yanCyan)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(Color.yanCyan.opacity(0.10))
                            .cornerRadius(10)
                            .sheet(isPresented: $showTypeEditor) {
                                FloorplanRoomTypeEditor(room: room) { type in
                                    onEditType(type)
                                }
                            }
                        }

                        if onDelete != nil {
                            Button(action: { showDeleteConfirmation = true }) {
                                Label(lang.t("floorplan_delete_room"), systemImage: "trash")
                                    .adaptiveFont(size: 12, weight: .semibold)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(12)
                            .background(Color.red.opacity(0.10))
                            .cornerRadius(10)
                        }
                        
                        // 2. 气场格局诊断
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(Color.yanGoldSoft)
                                Text("\(lang.t("floorplan_diag_prefix"))\(room.inspectionTitle)")
                                    .adaptiveFont(size: 14, weight: .bold)
                                    .foregroundColor(.white)
                            }
                            
                            Text(room.inspectionAdvice)
                                .adaptiveFont(size: 13)
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(3)
                        }
                        .padding(14)
                        .background(Color.appInkRaised)
                        .cornerRadius(12)

                        if !room.inspectionLore.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(lang.t("floorplan_impact_scope"))
                                    .adaptiveFont(size: 13, weight: .bold)
                                    .foregroundColor(Color.yanGold)
                                Text(room.inspectionLore)
                                    .adaptiveFont(size: 12)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(3)
                            }
                            .padding(14)
                            .background(Color.appInkRaised)
                            .cornerRadius(12)
                        }
                        
                        // 3. 经典堪舆古籍与现代环境机理
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.t("floorplan_classic_origin"))
                                .adaptiveFont(size: 13, weight: .bold)
                                .foregroundColor(Color.yanGold)
                            
                            Text(lang.t("floorplan_yangzhai_quote"))
                                .adaptiveFont(size: 12, design: .serif)
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .background(Color.appInkRaised)
                        .cornerRadius(12)
                        
                        // 4. 生旺化煞秘笈
                        VStack(alignment: .leading, spacing: 8) {
                            Text(lang.t("floorplan_master_remedy"))
                                .adaptiveFont(size: 13, weight: .bold)
                                .foregroundColor(Color.green)
                            
                            Text(room.inspectionAdvice.isEmpty ? lang.t("floorplan_room_advice") : room.inspectionAdvice)
                                .adaptiveFont(size: 12)
                                .foregroundColor(.white.opacity(0.85))
                                .lineSpacing(2)
                        }
                        .padding(14)
                        .background(Color(red: 0.11, green: 0.12, blue: 0.11))
                        .cornerRadius(12)
                        
                        Spacer(minLength: 20)
                    }
                    .padding(16)
                }
            }
            .navigationBarTitle(lang.t("floorplan_detail_title"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .overlay(
            Group {
                if showDeleteConfirmation, let onDelete = onDelete {
                    FloorplanConfirmDialog(
                        title: lang.t("floorplan_delete_room"),
                        message: lang.t("floorplan_delete_confirm"),
                        confirmTitle: lang.t("floorplan_delete_room"),
                        cancelTitle: lang.t("cancel"),
                        onConfirm: {
                            showDeleteConfirmation = false
                            onDelete()
                            presentationMode.wrappedValue.dismiss()
                        },
                        onCancel: { showDeleteConfirmation = false }
                    )
                }
            }
        )
    }
    
    private var badgeColor: Color {
        if room.isGood { return .green }
        if room.isSevere { return .red }
        if room.isWarning { return .orange }
        return Color.yanCyan
    }
    
    private var localizedLevel: String {
        let lang = LocalizationManager.shared
        if room.isGood { return lang.t("floorplan_level_auspicious") }
        if room.isSevere { return lang.t("floorplan_level_severe") }
        if room.isWarning { return lang.t("floorplan_level_warning") }
        return lang.t("floorplan_level_neutral")
    }
}
