import Foundation

/// 命令行自检模式：`NetSpeed --report [秒数]`
/// 逐秒打印各接口与汇总速率，用于验证采集逻辑是否正确。
enum HeadlessReport {

    static func run(seconds: Int) {
        var previous: [String: InterfaceCounters] = [:]
        var previousDate = Date()

        for _ in 0..<seconds {
            let sample = NetworkReader.read()
            let now = sample.date
            let elapsed = now.timeIntervalSince(previousDate)
            guard elapsed > 0 else { continue }

            var lines: [String] = []
            var totalDown = 0.0
            var totalUp = 0.0

            for current in sample.interfaces {
                guard let old = previous[current.name] else { continue }
                let down = current.receivedBytes >= old.receivedBytes
                    ? Double(current.receivedBytes - old.receivedBytes) / elapsed : 0
                let up = current.sentBytes >= old.sentBytes
                    ? Double(current.sentBytes - old.sentBytes) / elapsed : 0
                guard down > 0 || up > 0 else { continue }
                let excluded = InterfaceFilter.auto.isExcluded(name: current.name)
                lines.append(String(format: "  %-8@ ↓%-12@ ↑%-12@%@",
                                    current.name as NSString,
                                    ByteFormatter.speed(down) as NSString,
                                    ByteFormatter.speed(up) as NSString,
                                    excluded ? "  (自动模式不计)" : ""))
                if !excluded {
                    totalDown += down
                    totalUp += up
                }
            }

            print("── 采样 ─────────────────────────────")
            lines.forEach { print($0) }
            print(String(format: "  合计     ↓%@  ↑%@",
                         ByteFormatter.speed(totalDown) as NSString,
                         ByteFormatter.speed(totalUp) as NSString))
            fflush(stdout)

            previous = Dictionary(uniqueKeysWithValues: sample.interfaces.map { ($0.name, $0) })
            previousDate = now
            Thread.sleep(forTimeInterval: 1.0)
        }
    }
}
