import SwiftUI

// MARK: - 配色（单一来源）

// 取值与 App 图标同一套：墨青底、青绿次级、金黄主强调。
// 视图里不再直接写品牌色的 Color(red:green:blue:)，改指这里的 token；
// 换色只改这一个文件。

extension Color {
    /// 页面底色：墨青 #0C1A1D
    public static let appInk = Color(red: 12.0 / 255.0, green: 26.0 / 255.0, blue: 29.0 / 255.0)

    /// 卡片与浮层底色，比底色抬一档：#12262A
    public static let appInkRaised = Color(red: 18.0 / 255.0, green: 38.0 / 255.0, blue: 42.0 / 255.0)

    /// 分隔线与描边：#1E4449
    public static let appInkLine = Color(red: 30.0 / 255.0, green: 68.0 / 255.0, blue: 73.0 / 255.0)

    /// 主强调：金黄 #FFC857
    public static let yanGold = Color(red: 1.0, green: 200.0 / 255.0, blue: 87.0 / 255.0)

    /// 金黄浅一档，暗底上的正文与要点：#F4DD9E
    public static let yanGoldSoft = Color(red: 244.0 / 255.0, green: 221.0 / 255.0, blue: 158.0 / 255.0)

    /// 金黄深一档，描边与渐变尾：#C9922E
    public static let yanGoldDeep = Color(red: 201.0 / 255.0, green: 146.0 / 255.0, blue: 46.0 / 255.0)

    /// 次级强调：青绿 #2FB5A8
    public static let yanCyan = Color(red: 47.0 / 255.0, green: 181.0 / 255.0, blue: 168.0 / 255.0)

    /// 纸与木纹的暖棕。
    public static let yanBrown = Color(red: 166.0 / 255.0, green: 115.0 / 255.0, blue: 64.0 / 255.0)
}
