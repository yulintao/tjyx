import SwiftUI
import Foundation
import Combine
import UIKit
import Photos

/// 长卷页的固定输入：报告生成后不再变化，渲染与导出都读同一份，避免和实时传感器或存储新记录混在一起。
struct TianJiShuReportContext {
    let analysis: TianJiAnalysisSnapshot
    let coordsDesc: String
    let solarTimeDesc: String
    let floorplanReport: [FloorplanAuditItem]
    let panoramaArchive: PanoramaFengShuiArchive?

    var heading: Double { analysis.heading }
    var reportDate: Date { analysis.reportDate }
}

/// 长卷页的渲染与导出状态机。
///
/// 视图不再持有「是否在生成/是否在导出/预留了哪张额度/渲染到第几代」。这些状态彼此耦合
/// （导出失败必须退额度、页面消失必须作废迟到的渲染结果），集中在一处才能保证不出现
/// 半途状态。
final class TianJiShuViewModel: ObservableObject {

    // MARK: 渲染结果
    @Published var scrollImage: UIImage?
    @Published var isGenerating: Bool = true
    @Published var exportImage: UIImage?

    // MARK: 导出进行态
    @Published var isExporting: Bool = false
    @Published var showShareSheet: Bool = false
    @Published var showSavedToast: Bool = false
    @Published var showSaveError: Bool = false
    @Published var saveErrorMessage: String?
    @Published var showPhotoSettings: Bool = false
    @Published var showPaywall: Bool = false
    private(set) var photoWriteInFlight: Bool = false

    // MARK: 落款定制
    @Published var showCustomSignEditor: Bool = false
    @Published var customClientName: String = UserDefaults.standard.string(forKey: "tianjishu_custom_client") ?? ""
    @Published var customMasterName: String = UserDefaults.standard.string(forKey: "tianjishu_custom_master") ?? ""
    @Published var customSealText: String = UserDefaults.standard.string(forKey: "tianjishu_custom_seal") ?? ""

    /// 当前预留的单次导出额度（VIP 用户恒为 nil）。
    private(set) var reservedTianjiCredit: String?
    /// 分享面板尚未回报结果时的额度租约。
    var shareCreditLease: TianjiExportCreditLease?
    /// 每次渲染递增；迟到的后台结果靠它作废。
    private var renderGeneration: Int = 0

    private var iap: StoreKitIAPManager { StoreKitIAPManager.shared }
    private var lang: LocalizationManager { LocalizationManager.shared }

    init() {}

    // MARK: - 渲染

    /// 重新生成预览图。`isPro` 决定是否带水印：只有 VIP/买断用户拿到干净版本，
    /// 单次额度用户必须真的导出才消费额度。
    func beginRendering(context: TianJiShuReportContext, isPro: Bool) {
        renderGeneration += 1
        let generation = renderGeneration
        let language = lang.effectiveLanguage
        // 冻结报告参数与档案，后台渲染期间前台的传感器/存储变化不会渗进来。
        let heading = context.heading
        let coordsDesc = context.coordsDesc
        let solarTimeDesc = context.solarTimeDesc
        let panoramaArchive = context.panoramaArchive
        let floorplanReport = context.floorplanReport
        let reportDate = context.reportDate
        let analysis = context.analysis

        isGenerating = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let image = TianJiShuEngine.shared.generateScrollImage(
                heading: heading,
                coordsDesc: coordsDesc,
                solarTimeDesc: solarTimeDesc,
                language: language,
                isPro: isPro,
                floorplanReport: floorplanReport,
                panoramaArchive: panoramaArchive,
                reportDate: reportDate,
                analysis: analysis
            )
            DispatchQueue.main.async {
                guard let self, self.renderGeneration == generation else { return }
                self.scrollImage = image
                self.isGenerating = false
            }
        }
    }

    /// 导出用的干净图（始终无水印），只在用户真的点保存/分享时才渲染。
    private func prepareExportImage(context: TianJiShuReportContext, completion: @escaping (UIImage?) -> Void) {
        let generation = renderGeneration
        let language = lang.effectiveLanguage
        let heading = context.heading
        let coordsDesc = context.coordsDesc
        let solarTimeDesc = context.solarTimeDesc
        let panoramaArchive = context.panoramaArchive
        let floorplanReport = context.floorplanReport
        let reportDate = context.reportDate
        let analysis = context.analysis

        DispatchQueue.global(qos: .userInitiated).async {
            let image = TianJiShuEngine.shared.generateScrollImage(
                heading: heading,
                coordsDesc: coordsDesc,
                solarTimeDesc: solarTimeDesc,
                language: language,
                isPro: true,
                floorplanReport: floorplanReport,
                panoramaArchive: panoramaArchive,
                reportDate: reportDate,
                analysis: analysis
            )
            DispatchQueue.main.async {
                guard self.renderGeneration == generation else {
                    completion(nil)
                    return
                }
                completion(image)
            }
        }
    }

    // MARK: - 额度预留 / 提交 / 退还

    /// 成功写相册后才真正消费额度；在此之前任何失败路径都必须退还。
    private func commitReservation(_ reservation: String?) {
        guard let token = reservation else { return }
        if reservedTianjiCredit == token { reservedTianjiCredit = nil }
        iap.commitTianjiCreditReservation(token)
    }

    private func releaseReservation(_ reservation: String?) {
        guard let token = reservation else { return }
        if reservedTianjiCredit == token { reservedTianjiCredit = nil }
        iap.refundTianjiCreditReservation(token)
    }

    // MARK: - 保存到相册

    func saveToPhotos(context: TianJiShuReportContext) {
        guard !isExporting else { return }
        guard iap.canUseTianji else {
            showPaywall = true
            return
        }
        let reservation = iap.hasUnlockedVIP ? nil : iap.reserveTianjiCredit()
        if !iap.hasUnlockedVIP && reservation == nil {
            showPaywall = true
            return
        }
        reservedTianjiCredit = reservation
        isExporting = true

        prepareExportImage(context: context) { [weak self] image in
            guard let self else { return }
            guard let image else {
                self.isExporting = false
                self.releaseReservation(reservation)
                self.saveErrorMessage = self.lang.t("save_failed")
                self.showSaveError = true
                return
            }

            self.photoWriteInFlight = true
            TianJiShuEngine.shared.saveToPhotoLibrary(image: image) { success, message in
                DispatchQueue.main.async {
                    self.photoWriteInFlight = false
                    self.isExporting = false
                    if success {
                        // 写入成功才落账，避免失败时白扣一次额度。
                        self.commitReservation(reservation)
                        RetentionServiceManager.shared.recordMilestone(reason: "save_tianjishu")
                        withAnimation { self.showSavedToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            withAnimation { self.showSavedToast = false }
                        }
                    } else {
                        self.releaseReservation(reservation)
                        self.saveErrorMessage = message ?? self.lang.t("save_failed")
                        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
                        self.showPhotoSettings = status == .denied || status == .restricted
                        self.showSaveError = true
                    }
                }
            }
        }
    }

    // MARK: - 分享与打印

    func startShare(context: TianJiShuReportContext) {
        guard !isExporting else { return }
        guard iap.canUseTianji else {
            showPaywall = true
            return
        }
        let reservation = iap.hasUnlockedVIP ? nil : iap.reserveTianjiCredit()
        if !iap.hasUnlockedVIP && reservation == nil {
            showPaywall = true
            return
        }
        reservedTianjiCredit = reservation
        isExporting = true

        prepareExportImage(context: context) { [weak self] image in
            guard let self else { return }
            guard let image else {
                self.isExporting = false
                self.releaseReservation(reservation)
                self.saveErrorMessage = self.lang.t("save_failed")
                self.showSaveError = true
                return
            }
            // 分享面板的成败由回调结算；没回调就由租约 deinit 兜底。
            self.shareCreditLease = TianJiExportCreditLease { [exportManager = self.iap] success in
                guard let reservation else { return }
                if success { exportManager.commitTianjiCreditReservation(reservation) }
                else { exportManager.refundTianjiCreditReservation(reservation) }
            }
            self.reservedTianjiCredit = nil
            self.exportImage = image
            // 分享期间只保留一张长图，预览图让出内存。
            self.scrollImage = nil
            self.showShareSheet = true
        }
    }

    /// 分享面板关闭：结算租约、回收临时图，必要时补渲染预览。
    func handleShareSheetDismissed(context: TianJiShuReportContext) {
        shareCreditLease = nil
        isExporting = false
        exportImage = nil
        if scrollImage == nil {
            beginRendering(context: context, isPro: iap.hasUnlockedVIP)
        }
    }

    func handleShareCompletion(completed: Bool) {
        shareCreditLease?.complete(success: completed)
        isExporting = false
    }

    // MARK: - 页面消失

    func handleDisappear() {
        // 作废迟到的渲染结果。
        renderGeneration += 1
        if !showShareSheet && !photoWriteInFlight {
            releaseReservation(reservedTianjiCredit)
            isExporting = false
        }
    }

    // MARK: - 落款

    func applySignature(context: TianJiShuReportContext) {
        UserDefaults.standard.set(customClientName, forKey: "tianjishu_custom_client")
        UserDefaults.standard.set(customMasterName, forKey: "tianjishu_custom_master")
        UserDefaults.standard.set(customSealText, forKey: "tianjishu_custom_seal")
        showCustomSignEditor = false
        beginRendering(context: context, isPro: iap.hasUnlockedVIP)
    }

    func dismissError() {
        showSaveError = false
    }
}
