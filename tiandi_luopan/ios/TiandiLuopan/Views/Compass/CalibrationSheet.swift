import SwiftUI
import UIKit

// MARK: - 罗盘双针与地磁传感器校准弹窗 (Calibration Sheet)

public struct CalibrationSheet: View {
    /// Settings disables live sensors while idle. The settings-hosted sheet
    /// opts into a temporary sensor session; the compass-hosted sheet keeps
    /// the parent compass session unchanged.
    public let keepsMotionActive: Bool
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject private var lang = LocalizationManager.shared
    
    @State private var isCalibrating = false
    @State private var rotateDegree: Double = 0
    
    public init(keepsMotionActive: Bool = false) {
        self.keepsMotionActive = keepsMotionActive
    }
    
    public var body: some View {
        return ZStack {
            Color(red: 0.086, green: 0.075, blue: 0.059)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    // 1. 顶部标题栏
                    HStack {
                        Image(systemName: "safari.fill")
                            .foregroundColor(Color.goldDeep)
                        Text(lang.t("calib_sheet_title"))
                            .adaptiveFont(size: 16, weight: .bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .adaptiveFont(size: 20)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.top, 16)
                    
                    // 1.5 快速北向基准切换（真北 WMM 校正 / 磁北原始地磁）
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label(lang.t("heading_reference"), systemImage: "location.north.line.fill")
                                .adaptiveFont(size: 13, weight: .bold)
                                .foregroundColor(.yanCyan)
                            Spacer()
                            Text(motion.isLevel
                                 ? (lang.effectiveLanguage == .en ? "Level OK" : "双轴水平就绪")
                                 : String(format: "%.1f° / %.1f°", motion.pitch, motion.roll))
                                .adaptiveFont(size: 10.5, weight: .semibold, design: .monospaced)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background((motion.isLevel ? Color.semJi : Color.semWarn).opacity(0.18))
                                .foregroundColor(motion.isLevel ? .semJi : .semWarn)
                                .cornerRadius(6)
                        }

                        Picker(lang.t("heading_reference"), selection: $motion.northReference) {
                            Text(lang.effectiveLanguage == .en ? "True North (WMM)" : "真北（WMM 磁偏角校正）")
                                .tag(CompassNorthReference.trueNorth)
                            Text(lang.effectiveLanguage == .en ? "Magnetic North" : "磁北（地磁原向）")
                                .tag(CompassNorthReference.magneticNorth)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(14)
                    .background(Color.surfaceCard)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.yanCyan.opacity(0.25), lineWidth: 1)
                    )

                    // 2. 传感器实时健康度指标卡
                    VStack(spacing: 10) {
                        statusRow(
                            title: lang.t("calib_precision_title"),
                            value: motion.accuracyLevel >= 2 ? lang.t("calib_precision_high") : lang.t("calib_precision_need"),
                            isOk: motion.accuracyLevel >= 2
                        )
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        statusRow(
                            title: lang.t("calib_env_mag_title"),
                            value: motion.isDistorted ? "\(lang.t("calib_mag_distorted")) (\(String(format: "%.1f", motion.magneticStrengthUT)) μT)" : "\(lang.t("calib_mag_normal")) (\(String(format: "%.1f", motion.magneticStrengthUT)) μT)",
                            isOk: !motion.isDistorted
                        )
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        statusRow(
                            title: lang.t("calib_coords_title"),
                            value: motion.coordsDesc,
                            isOk: true,
                            customColor: Color.yanCyan
                        )
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        statusRow(
                            title: lang.t("calib_declination_title"),
                            value: declinationDisplay,
                            isOk: true,
                            customColor: Color.goldText
                        )
                    }
                    .padding(14)
                    .background(Color.surfaceCard)
                    .cornerRadius(12)
                    
                    // 3. 双针系统与易学考据说明卡
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Text("🧭")
                            Text(lang.t("calib_dual_needle_section"))
                                .adaptiveFont(size: 13, weight: .bold)
                                .foregroundColor(Color.goldText)
                        }
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .top, spacing: 4) {
                                Circle().fill(Color.semJi).frame(width: 6, height: 6).padding(.top, 4)
                                Text(lang.t("calib_magnetic_needle_desc"))
                                    .adaptiveFont(size: 12)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(2)
                            }
                            
                            HStack(alignment: .top, spacing: 4) {
                                Circle().fill(Color.goldText).frame(width: 6, height: 6).padding(.top, 4)
                                Text(lang.t("calib_true_needle_desc"))
                                    .adaptiveFont(size: 12)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(2)
                            }
                            
                            HStack(alignment: .top, spacing: 4) {
                                Circle().fill(Color.yanCyan).frame(width: 6, height: 6).padding(.top, 4)
                                Text(lang.t("calib_angle_desc"))
                                    .adaptiveFont(size: 12)
                                    .foregroundColor(.white.opacity(0.85))
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.surfaceElevated)
                    .cornerRadius(12)
                    
                    // 4. “8”字形翻转校准引导卡
                    VStack(spacing: 10) {
                        HStack {
                            Image(systemName: "infinity")
                                .adaptiveFont(size: 24, weight: .bold)
                                .foregroundColor(Color.goldDeep)
                                .rotationEffect(.degrees(rotateDegree))
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(lang.t("calib_eight_quick"))
                                    .adaptiveFont(size: 13, weight: .bold)
                                    .foregroundColor(.white)
                                Text(lang.t("calib_eight_desc"))
                                    .adaptiveFont(size: 11)
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineSpacing(2)
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.surfaceCard)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.goldDeep.opacity(0.3), lineWidth: 1)
                    )
                    
                    // 5. 操作按键
                    VStack(spacing: 10) {
                        Button(action: {
                            isCalibrating = true
                            withAnimation(Animation.linear(duration: 1.5).repeatCount(2, autoreverses: false)) {
                                rotateDegree += 360
                            }
                            motion.requestSensorCalibration()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                isCalibrating = false
                            }
                        }) {
                            HStack {
                                Image(systemName: isCalibrating ? "arrow.2.circlepath" : "arrow.triangle.2.circlepath")
                                Text(isCalibrating ? lang.t("calibrating_now") : lang.t("recalibrate_btn"))
                            }
                            .adaptiveFont(size: 14, weight: .bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    colors: [Color.goldText, Color(red: 0.75, green: 0.55, blue: 0.2)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.black)
                            .cornerRadius(10)
                        }
                        .disabled(isCalibrating)
                        
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Text(lang.t("i_know"))
                                .adaptiveFont(size: 13)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
        }
        .onAppear {
            guard keepsMotionActive else { return }
            motion.setCalibrationOverrideActive(true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            guard keepsMotionActive else { return }
            motion.setCalibrationOverrideActive(true)
        }
        .onDisappear {
            guard keepsMotionActive else { return }
            motion.setCalibrationOverrideActive(false)
        }
    }

    private var declinationDisplay: String {
        let decl = motion.currentDeclination
        let locationDenied = motion.locationAuthorizationStatus == .denied || motion.locationAuthorizationStatus == .restricted
        if motion.hasDeclination {
            return String(format: "%@%.2f°", decl >= 0 ? lang.t("calib_decl_east") : lang.t("calib_decl_west"), abs(decl))
        }
        if locationDenied {
            return lang.t("location_unavailable")
        }
        return lang.t("calib_decl_calculating")
    }
    
    private func statusRow(title: String, value: String, isOk: Bool, customColor: Color? = nil) -> some View {
        HStack {
            Text(title)
                .adaptiveFont(size: 13)
                .foregroundColor(.white.opacity(0.75))
            
            Spacer()
            
            Text(value)
                .adaptiveFont(size: 12, weight: .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background((customColor ?? (isOk ? Color.semJi : Color.semXiong)).opacity(0.15))
                .foregroundColor(customColor ?? (isOk ? Color.semJi : Color.semXiong))
                .cornerRadius(4)
        }
    }
}
