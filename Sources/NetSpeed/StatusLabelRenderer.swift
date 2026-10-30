import AppKit

/// 菜单栏状态项的标签渲染。
///
/// 关键点：标签用**固定尺寸**的 NSImage 承载，状态项的宽度由图片尺寸决定，
/// 与文字内容完全无关 —— 这样速率位数变化时，旁边的图标绝对不会被推着移动。
/// 文字用等宽字体（SF Mono）绘制，字符位置固定，看起来也不会左右跳动。
enum StatusLabelRenderer {

    /// 固定尺寸（点）。宽度需容纳 "↓ 00.0M ↑ 00.0M" 共 15 个等宽字符。
    static let size = NSSize(width: 116, height: 18)

    static let font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

    /// 生成状态项标签图片。
    /// - Parameters:
    ///   - download: 下行速率（紧凑定宽格式，如 " 36.2M"）
    ///   - upload: 上行速率（紧凑定宽格式，如 "  1.4M"）
    ///   - showUpload: 是否显示上行
    static func makeImage(download: String, upload: String, showUpload: Bool) -> NSImage {
        let text = showUpload ? "↓\(download) ↑\(upload)" : "↓\(download)      "

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

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attributed = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributed.size()
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
