import SwiftUI
import Foundation
import UIKit

/// Public HTTPS pages used by the purchase flow and App Store metadata.
/// Keep these URLs stable so the links shown in Settings and the paywall
/// always point at the currently published legal pages.
public enum LegalLinks {
    /// This page contains the service terms, subscription terms and full EULA.
    public static let termsOfUse = URL(string: "https://sdnlink.cn/i18n/zh-CN/subscription-terms.html")!
    public static let privacyPolicy = URL(string: "https://sdnlink.cn/i18n/zh-CN/privacy.html")!
    public static let support = URL(string: "https://sdnlink.cn/i18n/zh-CN/contact.html")!
    /// 正式上架后分配的 App Store 数字 ID（配置后点击评分直接直达 App Store 撰写长评页面）
    public static let appStoreID: String = ""
}

enum LegalDocument: String, Identifiable {
    case compliance

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .compliance: return "legal_compliance_title"
        }
    }

    var bodyKey: String {
        switch self {
        case .compliance: return "legal_compliance_body"
        }
    }
}
