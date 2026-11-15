import Foundation

/// 主导航的稳定语义标识。
///
/// 视图、深链、快捷指令都只使用枚举，不再传裸下标：
/// Tab 增删时只改这一处，路由与持久化状态不会错位。
public enum AppTab: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case ar = 0
    case floorplan = 1
    case analysis = 2
    case settings = 3

    public var id: Int { rawValue }

    public var titleKey: String {
        switch self {
        case .ar: return "tab_ar"
        case .floorplan: return "tab_floorplan"
        case .analysis: return "tab_analysis"
        case .settings: return "tab_settings"
        }
    }

    public var symbol: String {
        switch self {
        case .ar: return "camera.viewfinder"
        case .floorplan: return "house.fill"
        case .analysis: return "square.grid.3x3.fill"
        case .settings: return "gearshape.fill"
        }
    }

    /// 旧深链 / 快捷指令携带的是「五 Tab 时代」的裸下标：
    /// 0 罗盘、1 AR、2 户型、3 理气、4 设置。
    /// 罗盘页移除后，原罗盘入口统一落到理气页（择日与玄空同屏）。
    public static func fromLegacyIndex(_ index: Int) -> AppTab {
        switch index {
        case 0: return .analysis
        case 1: return .ar
        case 2: return .floorplan
        case 3: return .analysis
        case 4: return .settings
        default: return .ar
        }
    }
}
