import SwiftUI
import Foundation
import UIKit

// MARK: - 功能页 3: 界面语言设置 (UI Language & Preferences Page)

public struct LanguagePreferencesPageView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    @State private var showCalibrationGuide: Bool = false

    public init() {}

    public var body: some View {
        List {
            // 1. 语言与偏好
            Section(header: Text(lang.t("app_language"))) {
                Toggle(lang.t("haptic_feedback"), isOn: $motion.isHapticEnabled)

                Picker(lang.t("app_language"), selection: $lang.currentSetting) {
                    ForEach(AppLanguage.selectable) { item in
                        Text(item.displayName).tag(item)
                    }
                }

                Picker(lang.t("heading_reference"), selection: $motion.northReference) {
                    Text(lang.t("heading_reference_true")).tag(CompassNorthReference.trueNorth)
                    Text(lang.t("heading_reference_magnetic")).tag(CompassNorthReference.magneticNorth)
                }

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(lang.t("gps_coords"))
                        Spacer()
                        Text(motion.coordsDesc)
                            .foregroundColor(.secondary)
                            .adaptiveFont(size: 11)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    if motion.locationAuthorizationStatus == .denied || motion.locationAuthorizationStatus == .restricted {
                        Button(lang.t("open_system_settings")) {
                            motion.openLocationSettings()
                        }
                        .adaptiveFont(size: 11, weight: .semibold)
                        .foregroundColor(Color.yanCyan)
                    } else if motion.locationAuthorizationStatus == .notDetermined {
                        Button(lang.t("request_location_permission")) {
                            motion.requestLocationPermission()
                        }
                        .adaptiveFont(size: 11, weight: .semibold)
                        .foregroundColor(Color.yanCyan)
                    }
                }

                HStack {
                    Text(lang.t("true_solar_time"))
                    Spacer()
                    Text(motion.solarTimeDesc)
                        .foregroundColor(.secondary)
                        .adaptiveFont(size: 11)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            // 2. 硬件传感器与校准
            Section(header: Text(lang.t("settings_calib_title"))) {
                HStack {
                    Text(lang.t("mag_distortion"))
                    Spacer()
                    Text(motion.isDistorted ? lang.t("settings_mag_field_warning") : lang.t("settings_mag_field_normal"))
                        .foregroundColor(motion.isDistorted ? .red : .green)
                        .adaptiveFont(size: 13)
                }

                HStack {
                    Text(lang.t("settings_mag_intensity"))
                    Spacer()
                    Text(String(format: "%.1f μT", motion.magneticStrengthUT))
                        .foregroundColor(.secondary)
                        .adaptiveFont(size: 13, design: .monospaced)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .fixedSize(horizontal: true, vertical: false)
                }

                Button(action: {
                    showCalibrationGuide = true
                }) {
                    HStack {
                        Text(lang.t("compass_calib"))
                        Spacer()
                        Text(motion.isDistorted ? lang.t("settings_calib_status_need") : lang.t("settings_calib_status_high"))
                            .adaptiveFont(size: 12, weight: .bold)
                            .foregroundColor(motion.isDistorted ? .orange : .green)
                        Image(systemName: "chevron.right")
                            .adaptiveFont(size: 12)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .frame(maxWidth: horizontalSizeClass == .regular ? 900 : 700)
        .frame(maxWidth: .infinity)
        .background(Color.black.ignoresSafeArea())
        .navigationBarTitle(lang.t("settings_menu_language"), displayMode: .inline)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCalibrationGuide) {
            CalibrationSheet(keepsMotionActive: true)
        }
    }
}
