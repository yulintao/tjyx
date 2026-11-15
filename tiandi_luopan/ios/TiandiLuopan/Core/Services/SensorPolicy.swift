import Foundation

/// 「当前页面需要哪些传感器」的唯一口径。
///
/// 原先 RootContentView 用裸下标（selectedTab == 0 || == 1）判断，
/// 每加/删一个 Tab 都要回头改三处布尔表达式，极易漏改。
public enum SensorPolicy {
    /// 需要保持屏幕常亮（相机取景 / AR 测绘）。
    public static func keepsScreenAwake(_ tab: AppTab, hasMultipleActiveScenes: Bool) -> Bool {
        hasMultipleActiveScenes || tab == .ar
    }

    /// 需要设备运动（俯仰 / 横滚）。
    public static func needsDeviceMotion(_ tab: AppTab, hasMultipleActiveScenes: Bool) -> Bool {
        hasMultipleActiveScenes || tab == .ar
    }

    /// 需要持续方位（AR / 户型 / 理气都要，设置页不需要）。
    public static func needsHeadingUpdates(_ tab: AppTab, hasMultipleActiveScenes: Bool) -> Bool {
        hasMultipleActiveScenes || tab != .settings
    }
}
