import Foundation
import Combine

/// 一次采样得到的速率信息。
struct SpeedSnapshot {
    var downloadBytesPerSecond: Double = 0
    var uploadBytesPerSecond: Double = 0
    var perInterface: [InterfaceSpeed] = []
}

struct InterfaceSpeed: Identifiable {
    var id: String { name }
    let name: String
    let downloadBytesPerSecond: Double
    let uploadBytesPerSecond: Double
}

/// 采样间隔选项。
enum RefreshInterval: Double, CaseIterable, Identifiable {
    case one = 1.0
    case two = 2.0
    case five = 5.0

    var id: Double { rawValue }
    var title: String { "\(Int(rawValue)) 秒" }
}

/// 网络速率采样器：定时读取内核计数并做差分。
final class SpeedMonitor {

    private(set) var snapshot = SpeedSnapshot()

    var interval: RefreshInterval = .one {
        didSet {
            restartTimer()
            UserDefaults.standard.set(interval.rawValue, forKey: "refreshInterval")
        }
    }

    var filter: InterfaceFilter = .auto {
        didSet {
            resetBaseline()
            UserDefaults.standard.set(filter.rawValue, forKey: "interfaceFilter")
        }
    }

    var showUpload = true {
        didSet { UserDefaults.standard.set(showUpload, forKey: "showUpload") }
    }

    /// 每次采样完成后的回调（主线程）。
    var onChange: (() -> Void)?

    private var previous: [String: InterfaceCounters] = [:]
    private var previousDate: Date?
    private var timer: Timer?

    /// 速率上限（1 TB/s），避免异常差值产生离谱数字
    private let maxRate = 1_000_000_000_000.0

    init() {
        let defaults = UserDefaults.standard
        if let raw = defaults.object(forKey: "refreshInterval") as? Double,
           let value = RefreshInterval(rawValue: raw) {
            interval = value
        }
        if let raw = defaults.string(forKey: "interfaceFilter"),
           let value = InterfaceFilter(rawValue: raw) {
            filter = value
        }
        if defaults.object(forKey: "showUpload") != nil {
            showUpload = defaults.bool(forKey: "showUpload")
        }
        resetBaseline()
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        restartTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func resetBaseline() {
        previous = Dictionary(uniqueKeysWithValues: NetworkReader.read().interfaces.map { ($0.name, $0) })
        previousDate = Date()
    }

    private func restartTimer() {
        timer?.invalidate()
        resetBaseline()
        let t = Timer(timeInterval: interval.rawValue, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        let sample = NetworkReader.read()
        let now = sample.date
        let elapsed = now.timeIntervalSince(previousDate ?? now)
        guard elapsed > 0 else { return }

        var perInterface: [InterfaceSpeed] = []
        for current in sample.interfaces {
            guard let old = previous[current.name] else { continue }
            // 接口计数器可能回绕/重置（重新连接、接口重建），差值出现负数时按 0 处理
            let deltaDown = current.receivedBytes >= old.receivedBytes
                ? Double(current.receivedBytes - old.receivedBytes) : 0
            let deltaUp = current.sentBytes >= old.sentBytes
                ? Double(current.sentBytes - old.sentBytes) : 0
            guard deltaDown > 0 || deltaUp > 0 else { continue }
            perInterface.append(InterfaceSpeed(name: current.name,
                                               downloadBytesPerSecond: min(deltaDown / elapsed, maxRate),
                                               uploadBytesPerSecond: min(deltaUp / elapsed, maxRate)))
        }

        let upNames = Set(sample.interfaces.filter { $0.isUp }.map { $0.name })
        let selected = select(perInterface, upNames: upNames)

        let down = selected.reduce(0.0) { $0 + $1.downloadBytesPerSecond }
        let up = selected.reduce(0.0) { $0 + $1.uploadBytesPerSecond }

        snapshot = SpeedSnapshot(downloadBytesPerSecond: down,
                                  uploadBytesPerSecond: up,
                                  perInterface: selected.sorted { $0.downloadBytesPerSecond > $1.downloadBytesPerSecond })

        previous = Dictionary(uniqueKeysWithValues: sample.interfaces.map { ($0.name, $0) })
        previousDate = now

        onChange?()
    }

    /// 根据过滤模式挑出参与统计的接口。
    private func select(_ speeds: [InterfaceSpeed], upNames: Set<String>) -> [InterfaceSpeed] {
        let alive = speeds.filter { upNames.contains($0.name) }

        switch filter {
        case .all:
            return alive.filter { !$0.name.hasPrefix("lo") }
        case .primary:
            if let name = InterfaceFilter.primaryPriority.first(where: { upNames.contains($0) }) {
                return alive.filter { $0.name == name }
            }
            return alive.filter { !InterfaceFilter.auto.isExcluded(name: $0.name) }
        case .auto:
            return alive.filter { !filter.isExcluded(name: $0.name) }
        }
    }
}
