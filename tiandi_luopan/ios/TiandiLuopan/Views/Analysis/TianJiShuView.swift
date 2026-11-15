import SwiftUI
import Photos
import UIKit
import Combine

// MARK: - 福宅天机宣纸勘测长卷预览与导出视图 (TianJiShu View - PRD 第14章)

public struct TianJiShuView: View {
    @ObservedObject var iap = StoreKitIAPManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = TianJiShuViewModel()

    /// 报告生成后不再变化的固定输入，渲染与导出共用同一份。
    private let context: TianJiShuReportContext

    public init(analysis: TianJiAnalysisSnapshot? = nil) {
        let motion = CompassMotionManager.shared
        let snapshot = analysis ?? TianJiAnalysisSnapshot(heading: motion.headingState.facingAngle)
        self.context = TianJiShuReportContext(
            analysis: snapshot,
            coordsDesc: motion.coordsDesc,
            solarTimeDesc: motion.solarTimeDesc,
            floorplanReport: snapshot.hasSpatialSnapshot
                ? snapshot.capturedFloorplanReport
                : FloorplanAuditStore.shared.latestReport,
            panoramaArchive: snapshot.hasSpatialSnapshot
                ? snapshot.capturedPanoramaArchive
                : ShaSurveyStore.shared.archive
        )
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(red: 0.1, green: 0.1, blue: 0.12).ignoresSafeArea()

                VStack(spacing: 12) {
                    if viewModel.isGenerating {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(red: 0.95, green: 0.85, blue: 0.45)))
                                .scaleEffect(1.5)
                            Text(lang.t("tianji_rendering"))
                                .adaptiveFont(size: 14)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    } else if let img = viewModel.scrollImage {
                        // P3.8 自定义师门落款、堂号印章与福主署名栏
                        customSignatureBar()
                            .padding(.horizontal, 16)

                        // 宣纸长卷全景预览 (支持纵向长距离滚动)
                        ScrollView {
                            ZStack {
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.6), radius: 10, x: 0, y: 5)
                            }
                            .padding(12)
                        }

                        exportBar
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }

                    // 保存成功轻提示
                    if viewModel.showSavedToast {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            Text(lang.t("save_success"))
                                .adaptiveFont(size: 12, weight: .bold)
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.85))
                        .cornerRadius(20)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .navigationBarTitle(lang.t("tianji_scroll"), displayMode: .inline)
            .navigationBarItems(trailing: Button(lang.t("done")) {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                viewModel.beginRendering(context: context, isPro: iap.hasUnlockedVIP)
            }
            .onChange(of: lang.effectiveLanguage) { _ in
                // The report image contains localized text independently of
                // the surrounding SwiftUI labels. Re-render it after a
                // language change so the page never mixes two locales.
                viewModel.beginRendering(context: context, isPro: iap.hasUnlockedVIP)
            }
            .onReceive(iap.$tianjiCreditsCount.dropFirst()) { _ in
                guard !viewModel.isExporting else { return }
                viewModel.beginRendering(context: context, isPro: iap.hasUnlockedVIP)
            }
            .onReceive(iap.$isVIPUser.dropFirst()) { _ in
                guard !viewModel.isExporting else { return }
                viewModel.beginRendering(context: context, isPro: iap.hasUnlockedVIP)
            }
            .onDisappear {
                viewModel.handleDisappear()
            }
            .sheet(isPresented: $viewModel.showShareSheet, onDismiss: {
                viewModel.handleShareSheetDismissed(context: context)
            }) {
                if let exportImage = viewModel.exportImage {
                    TianJiActivityViewController(activityItems: [exportImage]) { completed in
                        viewModel.handleShareCompletion(completed: completed)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showPaywall) {
                VIPPaywallSheet(defaultProductId: .tianjiSingle)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        // Stable overlay instead of a system alert: this page observes the
        // high-frequency compass stream, which tore down the alert.
        .overlay(
            Group {
                if viewModel.showSaveError {
                    FloorplanConfirmDialog(
                        title: lang.t("save_failed"),
                        message: viewModel.saveErrorMessage ?? lang.t("save_failed"),
                        confirmTitle: viewModel.showPhotoSettings ? lang.t("open_system_settings") : lang.t("done"),
                        cancelTitle: viewModel.showPhotoSettings ? lang.t("done") : nil,
                        confirmColor: Color(red: 0.83, green: 0.68, blue: 0.21),
                        onConfirm: {
                            viewModel.dismissError()
                            if viewModel.showPhotoSettings,
                               let url = URL(string: UIApplication.openSettingsURLString),
                               UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            }
                        },
                        onCancel: { viewModel.dismissError() }
                    )
                }
            }
        )
    }

    // MARK: - 底部导出栏

    private var exportBar: some View {
        VStack(spacing: 8) {
            if !iap.canUseTianji {
                VIPLockCardView(
                    title: lang.t("tianji_vip_card_title"),
                    featureDesc: lang.t("tianji_vip_card_desc"),
                    badge: "\(lang.t("tianji_vip_badge")) · \(iap.localizedPrice(for: .tianjiSingle))",
                    targetProductId: .tianjiSingle,
                    onUnlockTap: { viewModel.showPaywall = true }
                )
            }

            HStack(spacing: 12) {
                Button(action: { viewModel.saveToPhotos(context: context) }) {
                    HStack {
                        if viewModel.isExporting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Image(systemName: "square.and.arrow.down.fill")
                        }
                        Text(viewModel.isExporting ? lang.t("exporting") : lang.t("save_to_photos"))
                    }
                    .adaptiveFont(size: 13, weight: .bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.8, blue: 0.35), Color(red: 0.75, green: 0.55, blue: 0.2)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.black)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isExporting)

                Button(action: { viewModel.startShare(context: context) }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up.fill")
                        Text(lang.t("share_and_print"))
                    }
                    .adaptiveFont(size: 13, weight: .bold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.12))
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(viewModel.isExporting)
            }
        }
    }

    // MARK: - 落款定制栏

    private func customSignatureBar() -> some View {
        let barTitle: String
        let clientPh: String
        let masterPh: String
        let sealPh: String
        let applyTitle: String
        switch lang.effectiveLanguage {
        case .en:
            barTitle = "Custom Seal, Studio & Client Signature"
            clientPh = "Client Name (e.g. Mr. Chen)"
            masterPh = "Master / Studio Name"
            sealPh = "Seal Text (e.g. XUAN KONG SEAL)"
            applyTitle = "Apply & Re-render Scroll"
        case .zhHant:
            barTitle = "定制師門落款 · 堂號朱印 · 福主署名"
            clientPh = "委託福主尊稱（如：陳公諱明 雅鑒）"
            masterPh = "堪輿師/堂號落款（如：玄空堂 李師傅）"
            sealPh = "朱砂印文（空格換行，如：玄空堂 欽定印）"
            applyTitle = "鈐印並重新生成長卷"
        case .ja:
            barTitle = "鑑定師落款・屋号朱印・施主名のカスタマイズ"
            clientPh = "施主様のお名前"
            masterPh = "鑑定師・屋号"
            sealPh = "朱印テキスト（空白で改行）"
            applyTitle = "落款を反映して再生成"
        case .ko:
            barTitle = "감여사 낙관 · 당호 인장 · 복주 서명 맞춤 설정"
            clientPh = "의뢰 복주 성함"
            masterPh = "감여사 / 당호 낙관"
            sealPh = "인장 문구 (공백으로 줄바꿈)"
            applyTitle = "낙관 적용 및 장권 재생성"
        case .vi:
            barTitle = "Tùy Chỉnh Lạc Khoản · Ấn Chương · Tên Thân Chủ"
            clientPh = "Tên Thân Chủ"
            masterPh = "Tên Đại Sư / Đường Hiệu"
            sealPh = "Chữ Ấn Chương"
            applyTitle = "Áp Dụng & Tạo Lại Trường Quyển"
        case .th:
            barTitle = "ปรับแต่งชื่อซินแส · ตราประทับ · ชื่อเจ้าของบ้าน"
            clientPh = "ชื่อเจ้าของบ้าน"
            masterPh = "ชื่อซินแส / สำนัก"
            sealPh = "ข้อความในตราประทับ"
            applyTitle = "ประทับตราและสร้างม้วนคัมภีร์ใหม่"
        case .id:
            barTitle = "Kustomisasi Nama Klien, Master & Stempel"
            clientPh = "Nama Klien"
            masterPh = "Nama Master / Studio"
            sealPh = "Teks Stempel Merah"
            applyTitle = "Terapkan & Buat Ulang"
        case .auto, .zhHans:
            barTitle = "定制师门落款 · 堂号朱印 · 福主署名"
            clientPh = "委托福主尊称（如：陈先生 雅鉴）"
            masterPh = "堪舆师/堂号落款（如：玄空堂 李师傅）"
            sealPh = "朱砂印文（空格换行，如：玄空堂 钦定印）"
            applyTitle = "钤印并重新生成长卷"
        }

        return VStack(alignment: .leading, spacing: 8) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showCustomSignEditor.toggle()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "seal.fill")
                        .foregroundColor(Color(red: 0.95, green: 0.35, blue: 0.32))
                    Text(barTitle)
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(Color(red: 0.95, green: 0.85, blue: 0.45))
                    Spacer()
                    Image(systemName: viewModel.showCustomSignEditor ? "chevron.up" : "chevron.down")
                        .adaptiveFont(size: 10, weight: .bold)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .buttonStyle(PlainButtonStyle())

            if viewModel.showCustomSignEditor {
                VStack(spacing: 6) {
                    TextField(clientPh, text: $viewModel.customClientName)
                        .adaptiveFont(size: 11)
                        .padding(7)
                        .background(Color.white.opacity(0.08))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    HStack(spacing: 6) {
                        TextField(masterPh, text: $viewModel.customMasterName)
                            .adaptiveFont(size: 11)
                            .padding(7)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                        TextField(sealPh, text: $viewModel.customSealText)
                            .adaptiveFont(size: 11)
                            .padding(7)
                            .background(Color.white.opacity(0.08))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    Button(action: { viewModel.applySignature(context: context) }) {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                            Text(applyTitle)
                        }
                        .adaptiveFont(size: 11, weight: .bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(Color(red: 0.83, green: 0.68, blue: 0.21))
                        .foregroundColor(.black)
                        .cornerRadius(6)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
    }
}

// MARK: - iOS 原生分享面板适配层
public struct TianJiActivityViewController: UIViewControllerRepresentable {
    public var activityItems: [Any]
    public var applicationActivities: [UIActivity]? = nil
    public var onCompletion: ((Bool) -> Void)? = nil

    public func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        // UIActivityViewController is a popover on iPad. Supplying an anchor
        // prevents a presentation exception when the report is shared there.
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX,
                                        y: controller.view.bounds.midY,
                                        width: 1,
                                        height: 1)
            popover.permittedArrowDirections = []
        }
        controller.completionWithItemsHandler = { _, completed, _, _ in
            if Thread.isMainThread {
                onCompletion?(completed)
            } else {
                DispatchQueue.main.async { onCompletion?(completed) }
            }
        }
        return controller
    }

    public func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
