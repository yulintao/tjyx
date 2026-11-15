import Foundation

/// 主导航的稳定语义标识。
///
/// 产品收敛为「AR 实景测绘 + 户型布局 + 家人分配」后只剩三个入口，
/// 视图、深链、快捷指令都只使用枚举，不再传裸下标。
public enum AppTab: Int, CaseIterable, Identifiable, Hashable, Sendable {
    case ar = 0
    case floorplan = 1
    case settings = 2

    public var id: Int { rawValue }

    public var titleKey: String {
        switch self {
        case .ar: return "tab_ar"
        case .floorplan: return "tab_floorplan"
        case .settings: return "tab_settings"
        }
    }

    public var symbol: String {
        switch self {
        case .ar: return "camera.viewfinder"
        case .floorplan: return "house.fill"
        case .settings: return "gearshape.fill"
        }
    }

    /// 旧深链 / 快捷指令携带的是「五 Tab 时代」的裸下标：
    /// 0 罗盘、1 AR、2 户型、3 理气、4 设置。理气页族下线后，
    /// 罗盘与理气入口统一落到 AR 实景页，户型入口落到户型页。
    public static func fromLegacyIndex(_ index: Int) -> AppTab {
        switch index {
        case 0, 1: return .ar
        case 2, 3: return .floorplan
        case 4: return .settings
        default: return .ar
        }
    }
}
