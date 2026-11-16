import SwiftUI

// MARK: - 立极画布的装饰层（蓝图网格 / 边缘暗角 / 四角角标）
// 三者只吃 canvasSize，不碰视图状态，所以能从 4000 行的 FloorplanView 里独立出来，
// 以后调图纸感只改这一个文件。

enum FloorplanCanvasDecor {
    /// 蓝图网格：只用来托住图纸感，透明度压到 0.06，不和房间色块抢注意力。
    static func grid(size: CGSize) -> some View {
        let step = max(16, min(size.width, size.height) / 12)
        return Path { path in
            var x = step
            while x < size.width {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                x += step
            }
            var y = step
            while y < size.height {
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                y += step
            }
        }
        .stroke(Color.yanCyan.opacity(0.06), lineWidth: 0.5)
        .allowsHitTesting(false)
    }

    /// 中心透、边缘暗的径向遮罩：截图里八宫角标与房间名会同时挤在边缘，压暗后层级立刻分开。
    static func vignette(size: CGSize) -> some View {
        RadialGradient(
            gradient: Gradient(colors: [Color.black.opacity(0), Color.black.opacity(0.34)]),
            center: .center,
            startRadius: min(size.width, size.height) * 0.34,
            endRadius: max(size.width, size.height) * 0.70
        )
        .allowsHitTesting(false)
    }

    /// 四角 L 形角标（不走 .rotationEffect，手机横竖屏都保持同一朝向）。
    static func cornerTicks(size: CGSize) -> some View {
        let inset: CGFloat = 9
        let len: CGFloat = 18
        return Path { path in
            path.move(to: CGPoint(x: inset, y: inset + len))
            path.addLine(to: CGPoint(x: inset, y: inset))
            path.addLine(to: CGPoint(x: inset + len, y: inset))

            path.move(to: CGPoint(x: size.width - inset - len, y: inset))
            path.addLine(to: CGPoint(x: size.width - inset, y: inset))
            path.addLine(to: CGPoint(x: size.width - inset, y: inset + len))

            path.move(to: CGPoint(x: size.width - inset, y: size.height - inset - len))
            path.addLine(to: CGPoint(x: size.width - inset, y: size.height - inset))
            path.addLine(to: CGPoint(x: size.width - inset - len, y: size.height - inset))

            path.move(to: CGPoint(x: inset + len, y: size.height - inset))
            path.addLine(to: CGPoint(x: inset, y: size.height - inset))
            path.addLine(to: CGPoint(x: inset, y: size.height - inset - len))
        }
        .stroke(Color.yanGold.opacity(0.5), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
        .allowsHitTesting(false)
    }
}
