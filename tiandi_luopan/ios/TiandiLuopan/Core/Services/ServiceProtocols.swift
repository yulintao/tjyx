import Foundation
import Combine
import CoreLocation

/// 文案与语言。页面只依赖这个协议，不再直接抓 LocalizationManager.shared。
public protocol LocalizationProviding: AnyObject {
    func t(_ key: String) -> String
    var currentLanguage: AppLanguage { get }
}

/// 方位 / 姿态 / 真太阳时。AR、户型、理气共用，但都不再直接持有全局单例。
public protocol MotionProviding: AnyObject {
    var heading: Double { get }
    var pitch: Double { get }
    var roll: Double { get }
    var headingState: CompassHeadingState { get }
    var trueSolarTimeStr: String { get }
    func start()
    func stop()
    func resumeIfSensorsEnabled()
    func setDeviceMotionEnabled(_ enabled: Bool)
    func setHeadingUpdatesEnabled(_ enabled: Bool)
}

extension LocalizationManager: LocalizationProviding {}
extension CompassMotionManager: MotionProviding {}

/// 依赖访问点：新代码从这里取服务，替换实现时不必逐页改调用。
public enum AppService {
    public static var localization: LocalizationProviding { LocalizationManager.shared }
    public static var motion: MotionProviding { CompassMotionManager.shared }
}
