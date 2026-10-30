import AppKit

/// 菜单栏状态项的标签渲染。
///
/// 关键点：标签用 NSImage 承载，状态项的宽度由图片尺寸决定。
/// - 下行部分**定宽**（等宽字体 + `%5.1f` 补位）：速率位数变化时宽度恒定，菜单栏图标不会抖动。
/// - 上行部分可开关：关闭时整块去掉（不占位），标签宽度随之收缩；
///   再打开时按同样的定宽规则恢复，宽度与之前完全一致。
enum StatusLabelRenderer {

    /// 标签高度（点）。
    static let height: CGFloat = 18

    static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    /// 生成状态项标签图片。
    /// - Parameters:
    ///   - download: 下行速率（紧凑定宽格式，如 " 36.2M"）
    ///   - upload: 上行速率（紧凑定宽格式，如 "  1.4M"）
    ///   - showUpload: 是否显示上行
    static func makeImage(download: String, upload: String, showUpload: Bool) -> NSImage {
        // 不显示上行时，整块上行内容（箭头 + 数值）都不画，不留空位
        let text = showUpload ? "↓\(download) ↑\(upload)" : "↓\(download)"

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
        // 宽度 = 文字实际宽度（字符数固定 ⇒ 宽度恒定），右侧留 2pt 余量
        let size = NSSize(width: ceil(textSize.width) + 2, height: height)

        // 用 2x 像素缓冲区绘制，保证 Retina 下不被拉伸变形
        let scale: CGFloat = 2
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else {
            return NSImage(size: size)
        }
        rep.size = size

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: size).fill()

        // 垂直居中，水平固定从 x=0 开始（等宽字体 ⇒ 每个字符位置恒定）
        attributed.draw(at: NSPoint(x: 0, y: ((size.height - textSize.height) / 2).rounded(.down) - 1))
        NSGraphicsContext.restoreGraphicsState()

        let image = NSImage(size: size)
        image.addRepresentation(rep)
        // 模板图片：自动适配深色/浅色菜单栏
        image.isTemplate = true
        return image
    }
}
