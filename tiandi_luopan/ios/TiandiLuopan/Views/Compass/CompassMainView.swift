import SwiftUI
import Combine

// MARK: - 主罗盘界面 (Compass Main View)

public struct CompassMainView: View {
    public var isActive: Bool = true
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    /// 布局环境值：iPad 横屏与 Duo 内屏一样走右栏研判工作台，竖屏回底部状态卡。
    @Environment(\.adaptiveLayoutForm) private var layoutForm
    @ObservedObject var motion = CompassMotionManager.shared
    @ObservedObject var layers = CompassLayerManager.shared
    @ObservedObject var lang = LocalizationManager.shared
    
    // 弹窗状态
    @State private var showFenjinSheet = false
    @State private var showKongwangSheet = false
    @State private var showPalaceSheet = false
    @State private var showLayerSheet = false
    @State private var showCalibSheet = false
    @State private var showMountainPickerSheet = false
    @State private var showBearingAppliedToast = false
    @State private var isPrecisionSampling = false
    @State private var sampleAngles: [Double] = []
    @State private var sampleMagneticUT: [Double] = []
    @State private var lastSampleSummary: BearingSampleSummary? = nil
    @ObservedObject private var workflow = SpatialWorkflowStore.shared
    @ObservedObject private var training = CompassTrainingStore.shared
    @State private var levelHoldStart: Date? = nil
    private static let precisionSampleTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private static let precisionTargetCount = 25
    
    public init(isActive: Bool = true) {
        self.isActive = isActive
    }
    
    public var body: some View {
        ZStack {
            // 背景渐变
            Color.screenInk
                .ignoresSafeArea()
            
            if isActive {
                // 分栏态（Duo 内屏 / iPad 横屏）：左栏 = 罗盘主交互（仪表/工具条/盘面），
                // 右栏 = 周易分金与八宅提示卡（分析解释）；单列态保持原纵排。
                FoldableTwoPane(compactSpacing: 4) {
                    VStack(spacing: 4) {
                        WorkflowStepperBar(activeStep: 1)
                            .padding(.horizontal, 16)
                            .padding(.top, 4)

                        // 0. 结论看板：此刻·此地·此向 + 四类结论（一屏看尽）
                        DSConclusionDashboard()
                            .padding(.horizontal, 16)

                        // 0.5 训练与每日挑战：默认收起，首屏只留仪表 / 盘体 / 主操作
                        DSFoldableSection(title: "训练 · 每日挑战", defaultExpanded: false) {
                            VStack(spacing: DS.padS) {
                                DSTrainingProgressHUD(module: "compass")
                                DSDailyChallengeCard()
                            }
                            .padding(.horizontal, 16)
                        }

                        // 1. 顶部数据仪表
                        CompassHeaderView()

                        // 专业测量仪器遥测条（基准北向 / WMM 磁偏角 / 磁场稳定度 / 双轴水平状态）
                        instrumentTelemetryStrip()
                            .padding(.horizontal, 16)
                        
                        // 强磁干扰动态告警条
                        if motion.isDistorted {
                            Button(action: {
                                showCalibSheet = true
                            }) {
                                HStack(spacing: 5) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(Color.semWarn)
                                    Text("\(lang.t("mag_warning_tap")) (\(String(format: "%.0f", motion.magneticStrengthUT)) μT) · \(lang.t("tap_to_calib"))")
                                        .adaptiveFont(size: 11, weight: .bold)
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.65)
                                        .layoutPriority(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .adaptiveFont(size: 10)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.semWarn.opacity(0.25))
                                .cornerRadius(6)
                                .padding(.horizontal, 16)
                            }
                        }
                        
                        // 2. 专业方位仪测量工具条（锁定 / 同步至工作流 / 24方位手选 / 精度校准 / 图层）
                        compassToolBar()
                            .padding(.top, 2)

                        if isPrecisionSampling {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .yanCyan))
                                    .scaleEffect(0.8)
                                Text(lang.effectiveLanguage == .en
                                     ? "Sampling steady bearing (\(sampleAngles.count)/\(Self.precisionTargetCount))... Hold level"
                                     : "稳态均值采集中（\(sampleAngles.count)/\(Self.precisionTargetCount)）… 请保持水平")
                                    .adaptiveFont(size: 10.5, weight: .semibold, design: .monospaced)
                                    .foregroundColor(.yanCyan)
                                Spacer()
                                Button(lang.t("cancel")) {
                                    isPrecisionSampling = false
                                    sampleAngles.removeAll()
                                    sampleMagneticUT.removeAll()
                                }
                                .adaptiveFont(size: 10, weight: .bold)
                                .foregroundColor(.semWarn)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.yanCyan.opacity(0.14))
                            .cornerRadius(7)
                            .padding(.horizontal, 16)
                        } else if showBearingAppliedToast {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .foregroundColor(.semJi)
                                Text(precisionToastText)
                                    .adaptiveFont(size: 10.5, weight: .semibold)
                                    .foregroundColor(.semJi)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                                Spacer()
                                Button(lang.effectiveLanguage == .en ? "Compute →" : "去计算 →") {
                                    AppNavigationRouter.shared.requestRoute(tab: 3)
                                }
                                .adaptiveFont(size: 10.5, weight: .bold)
                                .foregroundColor(.yanCyan)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.semJi.opacity(0.14))
                            .cornerRadius(7)
                            .padding(.horizontal, 16)
                        }

                        if !workflow.bearingStations.isEmpty {
                            bearingStationsStrip()
                                .padding(.horizontal, 16)
                        }
                        
                        Spacer(minLength: 4)
                        
                        // 3. 核心随动电子方位盘 (双轴水准仪、精密刻度与 24 方位)
                        CompassDialView()
                            .padding(.horizontal, 8)
                        
                        Spacer(minLength: 4)

                        // 4. 拇指区核心操作底座（锁定 / 稳态采样 / 一键同步工作流，无需横向滑动）
                        primaryInstrumentActionDock()
                            .padding(.horizontal, 16)
                            .padding(.bottom, 2)
                    }
                } analysis: {
                    // 4. 展开态右侧专业研判工作台（独立滚动）/ 单列态底部快捷卡片
                    // Duo 内屏与 iPad 横屏都走右栏；iPad 竖屏保持单列，改用底部状态卡。
                    if AdaptiveLayout.isTwoPane(horizontal: horizontalSizeClass,
                                                vertical: verticalSizeClass,
                                                form: layoutForm) {
                        ScrollView {
                            VStack(spacing: 12) {
                                unfoldedCompassAnalysisPanel()
                                DSTrainingBadgeShelf(compact: false)
                            }
                            .padding(16)
                            // iOS 27 浮动 TabBar 不占 safe area，会盖住右栏末尾卡片；
                            // 直接给可滚动内容留底部余量，保证最后一张卡能完整滚出。
                            .padding(.bottom, 80)
                        }
                    } else {
                        // 单列宽屏（iPad 竖屏 / Duo 折叠外屏）下底部卡片会被拉得很宽，
                        // 收在 900pt（与户型/设置同一套内容宽度口径）后居中；
                        // iPad 横屏走上面的右栏工作台分支，不会到这里。
                        VStack(spacing: 12) {
                            bottomStatusCard()
                                .frame(maxWidth: 900)
                            DSTrainingBadgeShelf(compact: true)
                                .frame(maxWidth: 900)
                        }
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                    }
                }
            }
        }
        .sheet(isPresented: $showFenjinSheet) {
            FenjinDetailSheet(fenjin: Fenjin120Data.shared.resolveFenjin(for: motion.headingState.facingAngle))
        }
        .sheet(isPresented: $showKongwangSheet) {
            KongWangDetailSheet(heading: motion.headingState.facingAngle)
        }
        .sheet(isPresented: $showPalaceSheet) {
            FengshuiPalaceDetailSheet()
        }
        .sheet(isPresented: $showLayerSheet) {
            LayerSettingsSheet()
        }
        .sheet(isPresented: $showCalibSheet) {
            CalibrationSheet()
        }
        .sheet(isPresented: $showMountainPickerSheet) {
            Mountain24PickerSheet(isPresented: $showMountainPickerSheet)
        }
        .onAppear {
            layers.showDailyGodMarkers = false
            motion.refreshTimeAndSolarTerm()
        }
        .onChange(of: isActive) { active in
            if active {
                motion.refreshTimeAndSolarTerm()
            }
        }
        // 测绘训练：连续水平 3 秒达标（真实姿态，不改变测量逻辑）
        .onChange(of: motion.isLevel) { level in
            if level {
                levelHoldStart = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    guard let start = levelHoldStart, Date().timeIntervalSince(start) >= 3.0,
                          motion.isLevel, isActive else { return }
                    training.completeDrill(.level, isEn: lang.effectiveLanguage == .en)
                    training.earnBadge(.steadyHand, isEn: lang.effectiveLanguage == .en)
                }
            } else {
                levelHoldStart = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            motion.refreshTimeAndSolarTerm()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            motion.refreshTimeAndSolarTerm()
        }
        .onReceive(Self.precisionSampleTimer) { _ in
            guard isActive, isPrecisionSampling else { return }
            let rawHeading = motion.physicalHeading() ?? motion.headingState.facingAngle
            sampleAngles.append(rawHeading)
            sampleMagneticUT.append(motion.magneticStrengthUT)
            if sampleAngles.count >= Self.precisionTargetCount {
                finishPrecisionSampling()
            }
        }
    }
    
    // MARK: - 拇指区高频主操作底座（锁定 / 稳态均值采样 / 一键同步测绘与计算）
    private func primaryInstrumentActionDock() -> some View {
        let isEn = (lang.effectiveLanguage == .en)
        return HStack(spacing: 8) {
            // 1. 锁定 / 解锁朝向
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                motion.toggleLock()
                if motion.isLocked { training.completeDrill(.lock, isEn: isEn) }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: motion.isLocked ? "lock.fill" : "lock.open")
                    Text(motion.isLocked ? lang.t("locked_heading") : lang.t("lock_heading"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .adaptiveFont(size: 11.5, weight: .bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                // 统一「锁定」语义色为金色：与 CompassHeaderView 的锁定钮一致，红色只留给凶煞
                .background(motion.isLocked ? Color.goldPrimary.opacity(0.22) : Color.white.opacity(0.08))
                .foregroundColor(motion.isLocked ? .goldText : .white)
                .cornerRadius(DS.radiusM)
                .overlay(
                    RoundedRectangle(cornerRadius: DS.radiusM)
                        .stroke(motion.isLocked ? Color.goldPrimary.opacity(0.55) : Color.strokeSoft, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(motion.isLocked ? lang.t("locked_heading") : lang.t("lock_heading"))

            // 2. 2.5 秒多样本圆周均值稳态采集
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                startPrecisionSampling()
            }) {
                HStack(spacing: 5) {
                    Image(systemName: isPrecisionSampling ? "hourglass" : "scope")
                    Text(isPrecisionSampling
                         ? "\(sampleAngles.count)/\(Self.precisionTargetCount)"
                         : (isEn ? "Sample" : "稳态采样"))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .adaptiveFont(size: 11.5, weight: .bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(isPrecisionSampling ? Color.yanCyan.opacity(0.28) : Color.yanCyan.opacity(0.14))
                .foregroundColor(.yanCyan)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yanCyan.opacity(0.45), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPrecisionSampling)

            // 3. 锁定并同步实测方位到测绘与计算工作流
            Button(action: {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                if !motion.isLocked {
                    motion.toggleLock()
                }
                applyCurrentBearingToWorkflow()
                training.completeDrill(.sync, isEn: isEn)
                if workflow.bearingStations.count >= 2 { training.earnBadge(.twoStations, isEn: isEn) }
            }) {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.triangle.branch")
                    Text(isEn ? "Sync" : "同步方位")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .adaptiveFont(size: 11.5, weight: .bold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .background(
                    LinearGradient(
                        colors: [Color.goldText, Color.goldDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .foregroundColor(.black)
                .cornerRadius(12)
                .shadow(color: Color.yanGold.opacity(0.25), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 罗盘辅助工具条（手选24山 / 空亡诊断 / 校准 / 图层 / 八方全鉴）
    private func compassToolBar() -> some View {
        // 判级复用 Mountain24.kongWangLevel 统一口径（与详勘 sheet 一致）：
        // 大空亡 ≥6.8°+子午卯酉缝 / 小空亡 ≥6.5° / 兼向 ≥1.5° / 其余纯清
        let kwLevel = motion.headingState.kongWangLevel
        let kwStatus = kwLevel.localizedTitle
        let kwColor: Color
        switch kwLevel {
        // 统一空亡语义色（与黑金主题一致，替代高饱和系统色）
        case .pure: kwColor = Color.semJi
        case .jianXiang: kwColor = Color.semWarn
        case .smallVoid: kwColor = Color.semWarn
        case .largeVoid: kwColor = Color.semXiong
        }
        
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 7) {
                // 手选24山快速选向与锁定
                Button(action: {
                    showMountainPickerSheet = true
                    training.recordTool("mountain_picker", isEn: lang.effectiveLanguage == .en)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "dial.medium.fill")
                        Text(lang.effectiveLanguage == .en ? "24 Mtns" : "手选24山")
                    }
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(.horizontal, DS.padM)
                    .frame(minHeight: DS.touchMin)
                    .background(Color.yanCyan.opacity(0.16))
                    .foregroundColor(Color.yanCyan)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // 空亡全景诊断
                Button(action: {
                    showKongwangSheet = true
                    training.recordTool("kongwang", isEn: lang.effectiveLanguage == .en)
                }) {
                    HStack(spacing: 4) {
                        Circle().fill(kwColor).frame(width: 6, height: 6)
                        Text(kwStatus)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .adaptiveFont(size: 11, weight: .bold)
                    .padding(.horizontal, DS.padM)
                    .frame(minHeight: DS.touchMin)
                    .background(kwColor.opacity(0.15))
                    .foregroundColor(kwColor)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kwStatus)

                // 校准
                Button(action: {
                    showCalibSheet = true
                    training.recordTool("calibration", isEn: lang.effectiveLanguage == .en)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "safari.fill")
                        Text(lang.t("btn_calib"))
                    }
                    .adaptiveFont(size: 11, weight: .medium)
                    .padding(.horizontal, DS.padM)
                    .frame(minHeight: DS.touchMin)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(motion.isDistorted ? Color.semWarn : Color.goldText)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)

                // 次要工具收纳：图层 / 八方全鉴 收进「更多」菜单，减少首屏横向滚动的按钮数
                Menu {
                    Button(action: {
                        showLayerSheet = true
                        training.recordTool("layers", isEn: lang.effectiveLanguage == .en)
                    }) {
                        Label(lang.t("btn_layers"), systemImage: "square.3.layers.3d")
                    }
                    Button(action: {
                        showPalaceSheet = true
                    }) {
                        Label(lang.t("btn_palace_all"), systemImage: "square.grid.2x2")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "ellipsis.circle.fill")
                        Text(lang.effectiveLanguage == .en ? "More" : "更多")
                    }
                    .adaptiveFont(size: 11, weight: .medium)
                    .padding(.horizontal, DS.padM)
                    .frame(minHeight: DS.touchMin)
                    .background(Color.white.opacity(0.08))
                    .foregroundColor(Color.yanCyan)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
        }
    }

    private var precisionToastText: String {
        let isEn = (lang.effectiveLanguage == .en)
        if let summary = lastSampleSummary {
            return isEn
                ? String(format: "Mean %.1f° (±%.2f°, n=%d) synced", summary.meanDegrees, summary.sigmaDegrees, summary.sampleCount)
                : String(format: "稳态均值 %.1f°（σ=%.2f°，%d 次采样）已同步", summary.meanDegrees, summary.sigmaDegrees, summary.sampleCount)
        }
        return isEn
            ? String(format: "Locked %.1f° synced to Survey & Compute", motion.headingState.facingAngle)
            : String(format: "已锁定 %.1f° 并同步至测绘与计算模块", motion.headingState.facingAngle)
    }

    private func startPrecisionSampling() {
        if motion.isLocked {
            motion.toggleLock()
        }
        sampleAngles = []
        sampleMagneticUT = []
        lastSampleSummary = nil
        showBearingAppliedToast = false
        isPrecisionSampling = true
    }

    private func finishPrecisionSampling() {
        isPrecisionSampling = false
        guard let summary = BearingSampleSummary.compute(
            anglesDegrees: sampleAngles,
            magneticSamplesUT: sampleMagneticUT
        ) else { return }
        lastSampleSummary = summary
        motion.lockAtFacingAngle(summary.meanDegrees)
        SpatialWorkflowStore.shared.recordInstrumentBearing(
            bearingDegrees: summary.meanDegrees,
            northReferenceRaw: motion.northReference.rawValue,
            declinationDegrees: motion.currentDeclination,
            magneticStrengthUT: motion.magneticStrengthUT,
            isLevel: motion.isLevel,
            pitchDegrees: motion.pitch,
            rollDegrees: motion.roll,
            sourceLabel: summary.isStable ? "Precision Mean" : "Sampled Mean",
            sigmaDegrees: summary.sigmaDegrees,
            sampleCount: summary.sampleCount
        )
        showBearingAppliedToast = true

        // 测绘训练：按真实采样条件发放徽章（不改变任何测量数据）
        let isEn = lang.effectiveLanguage == .en
        training.completeDrill(.sample, isEn: isEn)
        training.earnBadge(.firstSample, isEn: isEn)
        if motion.isLevel { training.earnBadge(.levelMaster, isEn: isEn) }
        if !motion.isDistorted && motion.magneticStrengthUT < 70 {
            training.earnBadge(.cleanRead, isEn: isEn)
        }
        if motion.northReference == .trueNorth && motion.hasDeclination {
            training.earnBadge(.navAligned, isEn: isEn)
        }
    }

    private func bearingStationsStrip() -> some View {
        let isEn = (lang.effectiveLanguage == .en)
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text(isEn ? "Stations:" : "测站记录:")
                    .adaptiveFont(size: 9.5, weight: .bold)
                    .foregroundColor(.white.opacity(0.6))
                ForEach(workflow.bearingStations.prefix(5)) { st in
                    let isSelected = workflow.bearing?.id == st.id
                    Button(action: {
                        workflow.selectStation(st)
                        motion.lockAtFacingAngle(st.bearingDegrees)
                        showBearingAppliedToast = true
                    }) {
                        HStack(spacing: 3) {
                            Text(String(format: "%.1f°", st.bearingDegrees))
                                .adaptiveFont(size: 10, weight: .bold, design: .monospaced)
                            if let sigma = st.sigmaDegrees {
                                Text(String(format: "±%.1f°", sigma))
                                    .adaptiveFont(size: 8.5, design: .monospaced)
                                    .foregroundColor(.yanCyan)
                            }
                        }
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3.5)
                        .background(isSelected ? Color.yanGold.opacity(0.25) : Color.white.opacity(0.08))
                        .foregroundColor(isSelected ? .yanGold : .white.opacity(0.85))
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func applyCurrentBearingToWorkflow() {
        let heading = motion.headingState.facingAngle
        lastSampleSummary = nil
        SpatialWorkflowStore.shared.recordInstrumentBearing(
            bearingDegrees: heading,
            northReferenceRaw: motion.northReference.rawValue,
            declinationDegrees: motion.currentDeclination,
            magneticStrengthUT: motion.magneticStrengthUT,
            isLevel: motion.isLevel,
            pitchDegrees: motion.pitch,
            rollDegrees: motion.roll,
            sourceLabel: motion.isLocked ? "Instrument Lock" : "Instrument Sample"
        )
        showBearingAppliedToast = true
    }

    /// 电子方位仪工程遥测状态条：真北/磁北、磁偏角、磁场强度（轻点校准）与双轴水准状态一目了然。
    private func instrumentTelemetryStrip() -> some View {
        let isEn = (lang.effectiveLanguage == .en)
        let refText = motion.northReference == .trueNorth
            ? (isEn ? "True N" : "真北")
            : (isEn ? "Mag N" : "磁北")
        let levelText = motion.isLevel ? (isEn ? "Level OK" : "水平就绪") : (isEn ? "Tilt" : "请端平")
        return HStack(spacing: 8) {
            Button(action: { showCalibSheet = true }) {
                Label("\(refText) \(String(format: "%+.1f°", motion.currentDeclination))", systemImage: "location.north.line")
                    .foregroundColor(.yanCyan)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 4)
            Button(action: { showCalibSheet = true }) {
                Label(String(format: "%.0f μT", motion.magneticStrengthUT), systemImage: "waveform.path.ecg")
                    .foregroundColor(motion.isDistorted ? .semWarn : .semJi)
            }
            .buttonStyle(.plain)
            Spacer(minLength: 4)
            Label(levelText, systemImage: motion.isLevel ? "checkmark.circle.fill" : "level")
                .foregroundColor(motion.isLevel ? .semJi : .semWarn)
        }
        .adaptiveFont(size: 10, weight: .semibold, design: .monospaced)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(motion.isDistorted ? Color.semWarn.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
    
    // MARK: - 展开态右侧研判工作台 (iPhone Duo 内屏 / iPad)
    //
    // 展开态右栏（独立滚动）：向首总览、一百二十分金度数跨度与秘传断语、
    // 六十四卦卦象与分金描述、空亡判级与化解指引，并附四个快捷入口。
    // 折叠态不渲染本面板（右栏改用 bottomStatusCard()，见 body 内分支）。
    private func unfoldedCompassAnalysisPanel() -> some View {
        let heading = motion.headingState
        let hex = Hexagram64Data.shared.hexagram(for: heading.facingAngle)
        let fenjin = Fenjin120Data.shared.resolveFenjin(for: heading.facingAngle)
        let kwLevel = heading.kongWangLevel

        // 空亡判级配色与文案 key（四档均有完整多语种文案，避免硬编码）
        let kwColor: Color
        let kwGradeKey: String
        let kwDescKey: String
        let kwRemedyKey: String
        switch kwLevel {
        case .pure:
            kwColor = Color.semJi
            kwGradeKey = "kw_pure_grade"
            kwDescKey = "kw_pure_desc"
            kwRemedyKey = "kw_pure_remedy"
        case .jianXiang:
            kwColor = Color.semWarn
            kwGradeKey = "kw_sub_grade"
            kwDescKey = "kw_sub_desc"
            kwRemedyKey = "kw_sub_remedy"
        case .smallVoid:
            kwColor = Color.semWarn
            kwGradeKey = "kw_small_grade"
            kwDescKey = "kw_small_desc"
            kwRemedyKey = "kw_small_remedy"
        case .largeVoid:
            kwColor = Color.semXiong
            kwGradeKey = "kw_large_grade"
            kwDescKey = "kw_large_desc"
            kwRemedyKey = "kw_large_remedy"
        }

        return VStack(alignment: .leading, spacing: 12) {
            // 1. 向首总览：实时度数 / 二十四山 / 俯仰横滚 / 磁场强度
            VStack(alignment: .leading, spacing: 8) {
                // 窄右栏（Duo 内屏 / iPad 分栏）里横向 HStack 会把泰语/印尼语
                // 无空格长词与数值、徽章挤成互相穿插；改为纵向堆叠，各占整行。
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.t("kw_heading_prefix"))
                        .adaptiveFont(size: 11, weight: .bold)
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Text(String(format: "%.1f°", heading.facingAngle))
                            .adaptiveFont(size: 24, weight: .bold, design: .monospaced)
                            .foregroundColor(Color.goldText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(fenjin.localizedMountainName)
                            .adaptiveFont(size: 12, weight: .bold)
                            .foregroundColor(Color.yanCyan)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 0)
                    }
                }
                HStack(spacing: 12) {
                    Text("\(lang.t("pitch_label")) \(String(format: "%.1f°", motion.pitch))")
                    Text("\(lang.t("roll_label")) \(String(format: "%.1f°", motion.roll))")
                    Text(String(format: "%.0f μT", motion.magneticStrengthUT))
                }
                .adaptiveFont(size: 11)
                .foregroundColor(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(analysisPanelBackground())

            // 2. 一百二十分金：度数跨度 + 孤虚旺相秘传断语 + 立向指引
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.t("fenjin_range_section"))
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(fenjin.localizedJiaziName)
                            .adaptiveFont(size: 13, weight: .bold, design: .serif)
                            .foregroundColor(Color.goldText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Spacer(minLength: 4)
                        Text(fenjin.localizedGrade)
                            .adaptiveFont(size: 10, weight: .bold)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(fenjin.isAuspicious ? Color.semJi.opacity(0.2) : Color.semXiong.opacity(0.2))
                            .foregroundColor(fenjin.isAuspicious ? Color.semJi : Color.semXiong)
                            .cornerRadius(4)
                    }
                }
                Text("\(String(format: "%.1f", fenjin.startAngle))° \(lang.t("fenjin_to")) \(String(format: "%.1f", fenjin.endAngle))° · \(lang.t("fenjin_center_deg")) \(String(format: "%.1f", fenjin.centerAngle))°")
                    .adaptiveFont(size: 11, design: .monospaced)
                    .foregroundColor(.white.opacity(0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(lang.t("fenjin_lore_section"))
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(Color.goldText)
                Text(fenjin.localizedLore)
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.85))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text(fenjin.isAuspicious ? lang.t("fenjin_auspicious_advice") : lang.t("fenjin_inauspicious_advice"))
                    .adaptiveFont(size: 10)
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(analysisPanelBackground())

            // 3. 六十四卦：卦名 / 上下卦 / 卦气吉凶 / 穿山透地分金描述
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(hex.localizedName)
                        .adaptiveFont(size: 18, weight: .bold, design: .serif)
                        .foregroundColor(Color.goldText)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(hex.localizedUpperTrigram) · \(hex.localizedLowerTrigram)")
                            .adaptiveFont(size: 11)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 4)
                        Text(hex.localizedLuckDegree)
                            .adaptiveFont(size: 10, weight: .bold)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(hex.isGreatAuspicious ? Color.semJi.opacity(0.2) : Color.white.opacity(0.08))
                            .foregroundColor(hex.isGreatAuspicious ? Color.semJi : .white.opacity(0.85))
                            .cornerRadius(4)
                    }
                }
                Text(hex.localizedFenJinDetail)
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(analysisPanelBackground())

            // 4. 空亡判级与化解指引
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.t("kw_sheet_title"))
                        .adaptiveFont(size: 12, weight: .bold)
                        .foregroundColor(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 6) {
                        Text(lang.t(kwGradeKey))
                            .adaptiveFont(size: 10, weight: .bold)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(kwColor.opacity(0.2))
                            .foregroundColor(kwColor)
                            .cornerRadius(4)
                        Spacer(minLength: 0)
                    }
                }
                Text(kwLevel.localizedTitle)
                    .adaptiveFont(size: 11, weight: .bold)
                    .foregroundColor(kwColor)
                Text(lang.t(kwDescKey))
                    .adaptiveFont(size: 11)
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text("\(lang.t("kw_master_remedy_section"))\(lang.t(kwRemedyKey))")
                    .adaptiveFont(size: 10)
                    .foregroundColor(.white.opacity(0.6))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(analysisPanelBackground())

            // 5. 快捷工具入口与工作流流转
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    analysisPanelToolButton(title: lang.t("btn_fenjin_detail"),
                                            systemImage: "ruler",
                                            tint: Color.yanCyan) { showFenjinSheet = true }
                    analysisPanelToolButton(title: lang.t("kw_sheet_title"),
                                            systemImage: "scope",
                                            tint: kwColor) { showKongwangSheet = true }
                }
                HStack(spacing: 8) {
                    analysisPanelToolButton(title: lang.t("btn_palace_all"),
                                            systemImage: "square.grid.2x2",
                                            tint: Color.goldDeep) { showPalaceSheet = true }
                    analysisPanelToolButton(title: lang.effectiveLanguage == .en ? "Sync & Compute" : "同步至计算模块",
                                            systemImage: "arrow.triangle.branch",
                                            tint: Color.semJi) {
                        if !motion.isLocked { motion.toggleLock() }
                        applyCurrentBearingToWorkflow()
                        AppNavigationRouter.shared.requestRoute(tab: 3)
                    }
                }
            }
        }
    }

    /// 研判工作台卡片底：深色圆角 + 淡金描边（与全工程卡片口径一致）
    private func analysisPanelBackground() -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.surfaceCard)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.goldDeep.opacity(0.2), lineWidth: 1)
            )
    }

    /// 研判工作台快捷工具按钮
    private func analysisPanelToolButton(title: String,
                                        systemImage: String,
                                        tint: Color,
                                        action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .adaptiveFont(size: 11)
                Text(title)
                    .adaptiveFont(size: 11, weight: .bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - 底部状态卡
    private func bottomStatusCard() -> some View {
        let hex = Hexagram64Data.shared.hexagram(for: motion.headingState.facingAngle)
        let fenjin = Fenjin120Data.shared.resolveFenjin(for: motion.headingState.facingAngle)
        
        return Button(action: {
            showFenjinSheet = true
        }) {
            VStack(spacing: 6) {
                HStack {
                    HStack(spacing: 6) {
                        Text(hex.localizedName)
                            .adaptiveFont(size: 15, weight: .bold, design: .serif)
                            .foregroundColor(Color.goldText)
                        Text(fenjin.localizedJiaziName)
                            .adaptiveFont(size: 11, weight: .bold)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(fenjin.isAuspicious ? Color.semJi.opacity(0.2) : Color.semXiong.opacity(0.2))
                            .foregroundColor(fenjin.isAuspicious ? Color.semJi : Color.semXiong)
                            .cornerRadius(4)
                        Text(fenjin.localizedGrade)
                            .adaptiveFont(size: 10)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 2) {
                        Text(lang.t("btn_fenjin_detail"))
                            .adaptiveFont(size: 11)
                            .foregroundColor(Color.yanCyan)
                        Image(systemName: "chevron.right")
                            .adaptiveFont(size: 9)
                            .foregroundColor(Color.yanCyan)
                    }
                }
                
                HStack {
                    Text(fenjin.localizedLore)
                        .adaptiveFont(size: 11)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.surfaceCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.goldDeep.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
