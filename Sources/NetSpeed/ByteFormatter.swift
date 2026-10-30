import Foundation

enum ByteFormatter {

    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        f.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        f.includesUnit = true
        f.isAdaptive = false
        return f
    }()

    /// 人类可读的流量数值，例如 “1.2 MB/s”。
    static func speed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return "0 B/s" }
        // 防止异常值（如接口计数器重置导致的巨大值）转换 Int64 时崩溃
        let clamped = min(bytesPerSecond, 1_000_000_000_000)   // 上限 1 TB/s
        let value = formatter.string(fromByteCount: Int64(clamped))
        return "\(value)/s"
    }

    /// 菜单栏用的紧凑格式，例如 “1.2M”。
    static func compact(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return "0" }
        let units = ["B", "K", "M", "G", "T"]
        var value = bytesPerSecond
        var index = 0
        while value >= 1024 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        let digits = value >= 100 ? 0 : (value >= 10 ? 1 : 1)
        return String(format: "%.\(digits)f%@", value, units[index])
    }

    /// 菜单栏用的**定宽**紧凑格式，例如 “ 1.2M” / “999.9M”。
    ///
    /// 数值部分固定 5 个字符（不足补空格）+ 1 个单位字符 = 恒为 6 个字符，
    /// 因此菜单栏文字宽度不会因速率位数变化而抖动。
    static func compactFixed(_ bytesPerSecond: Double) -> String {
        let units = ["B", "K", "M", "G", "T"]
        var value = bytesPerSecond.isFinite ? max(0, bytesPerSecond) : 0
        value = min(value, 1_000_000_000_000)   // 上限 1 TB/s
        var index = 0
        // 达到 999.95 就换单位，保证数值部分永远能用 %5.1f 放下（固定 5 个字符）
        while value >= 999.95 && index < units.count - 1 {
            value /= 1024
            index += 1
        }
        return String(format: "%5.1f%@", value, units[index])
    }
}
