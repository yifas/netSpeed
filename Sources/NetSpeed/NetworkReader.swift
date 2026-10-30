import Foundation

/// 单个网络接口的累计流量计数（字节）。
struct InterfaceCounters: Equatable {
    let name: String
    let receivedBytes: UInt64
    let sentBytes: UInt64
    let isUp: Bool
}

/// 采样到的一组接口计数器。
struct NetworkSample {
    let date: Date
    let interfaces: [InterfaceCounters]

    static let empty = NetworkSample(date: Date(), interfaces: [])
}

enum InterfaceFilter: String, CaseIterable, Identifiable {
    case auto       // 自动：排除回环与隧道/虚拟接口，避免重复计数
    case all        // 全部：除 lo0 外所有 UP 接口
    case primary    // 主接口：优先 en0 / en1 等物理以太网或 Wi-Fi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Automatic"
        case .all: return "All Interfaces"
        case .primary: return "Primary Interface"
        }
    }

    /// 该模式下需要被排除的接口前缀。
    func isExcluded(name: String) -> Bool {
        switch self {
        case .auto:
            // 隧道接口(utun/ppp/ipsec)与桥接接口承载的是底层物理接口的重复流量
            let excludedPrefixes = ["lo", "awdl", "llw", "utun", "ppp", "ipsec", "bridge", "vlan", "gif", "stf"]
            return excludedPrefixes.contains { name.hasPrefix($0) }
        case .all:
            return name.hasPrefix("lo")
        case .primary:
            return name.hasPrefix("lo") || name.hasPrefix("awdl") || name.hasPrefix("llw")
        }
    }

    /// 主接口模式的优先顺序。
    static let primaryPriority = ["en0", "en1", "en2", "en3", "en4", "en5"]
}

/// 通过 `getifaddrs` 读取内核提供的每接口收发字节计数。
enum NetworkReader {

    /// 读取当前所有接口的累计计数。
    static func read() -> NetworkSample {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else {
            return .empty
        }
        defer { freeifaddrs(head) }

        var result: [InterfaceCounters] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first

        while let current = cursor {
            let ifa = current.pointee
            cursor = ifa.ifa_next

            guard let namePtr = ifa.ifa_name else { continue }
            let name = String(cString: namePtr)

            // ifa_data 仅在 AF_LINK 层有效，其中保存 if_data（含累计流量）
            guard let data = ifa.ifa_data?.assumingMemoryBound(to: if_data.self) else { continue }

            let isUp = (ifa.ifa_flags & UInt32(IFF_UP)) != 0
            let received = UInt64(data.pointee.ifi_ibytes)
            let sent = UInt64(data.pointee.ifi_obytes)

            result.append(InterfaceCounters(name: name,
                                             receivedBytes: received,
                                             sentBytes: sent,
                                             isUp: isUp))
        }
        return NetworkSample(date: Date(), interfaces: result)
    }
}
