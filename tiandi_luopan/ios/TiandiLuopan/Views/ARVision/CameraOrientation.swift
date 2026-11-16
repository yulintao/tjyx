import AVFoundation
import UIKit

// MARK: - 界面方向 → 相机方向映射

extension UIInterfaceOrientation {
    /// UIInterfaceOrientation 的横屏命名与 AVCaptureVideoOrientation 相反：
    /// 界面 landscapeLeft（Home 键在左）对应设备 landscapeRight。
    /// 竖屏两种取值两者一致，横屏若直接透传会得到 180° 倒像。
    var avCaptureOrientation: AVCaptureVideoOrientation {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        default: return .portrait
        }
    }
}
