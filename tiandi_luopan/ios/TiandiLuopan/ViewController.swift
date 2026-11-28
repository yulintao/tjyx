import UIKit
import SwiftUI

// MARK: - 原生 Swift / SwiftUI 宿主控制器 (Pure Swift View Controller)

public class ViewController: UIHostingController<SpacePuzzleRootView> {
    
    public init() {
        super.init(rootView: SpacePuzzleRootView())
    }
    
    @objc required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: SpacePuzzleRootView())
    }
    
    override public var preferredStatusBarStyle: UIStatusBarStyle {
        return .darkContent
    }
    
    override public var prefersStatusBarHidden: Bool {
        return false
    }

    override public func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 242/255.0, green: 240/255.0, blue: 247/255.0, alpha: 1.0)
        
        // 新版空间解谜界面由 SpacePuzzleRootView 自持状态。
        // 旧 RootContentView 的传感器生命周期不再由本宿主触发。
    }
    
    deinit {
        // 多窗口（Stage Manager）：关掉一个窗口的宿主控制器，不代表 App 不再需要传感器。
        // 只有当前没有任何前台活跃场景时才停，避免影响另一个窗口的采集页面。
        let hasActiveScene = UIApplication.shared.connectedScenes
            .contains { $0.activationState == .foregroundActive }
        guard !hasActiveScene else { return }
        UIApplication.shared.isIdleTimerDisabled = false
        CompassMotionManager.shared.stop()
    }
}
