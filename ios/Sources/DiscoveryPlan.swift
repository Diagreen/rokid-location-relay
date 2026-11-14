import Foundation

enum DiscoveryPlan {
    static func ipv4(_ text: String) -> UInt32? {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return nil }
        var value: UInt32 = 0
        for part in parts {
            guard let n = UInt32(part), n < 256, String(n) == part else { return nil }
            value = (value << 8) | n
        }
        return value
    }
    static func text(_ ip: UInt32) -> String {
        [24,16,8,0].map { String((ip >> $0) & 255) }.joined(separator: ".")
    }
    static func hosts(address: String, mask: String) -> [String] {
        guard PairingProtocol.baseURL("http://\(address):8765") != nil,
              let ip = ipv4(address), let original = ipv4(mask) else { return [] }
        let inverse = ~original
        guard inverse & (inverse &+ 1) == 0 else { return [] }
        // Never enumerate more than the local /24, even on large private networks.
        let subnet = original | 0xffffff00
        let first = ip & subnet, last = first | ~subnet
        guard last > first + 1 else { return [] }
        return ((first + 1)..<last).filter { $0 != ip }.map(text)
    }
    static func candidates(interfaces: [(String,String)]) -> [String] {
        // Known iPhone hotspot subnet is only a fallback when the bridge interface is hidden.
        let fallback = hosts(address: "172.20.10.1", mask: "255.255.255.240")
        var seen = Set<String>()
        return (fallback + interfaces.flatMap { hosts(address: $0.0, mask: $0.1) })
            .filter { seen.insert($0).inserted }.prefix(1024).map { $0 }
    }
    static func isGlasses(_ data: Data) -> Bool {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String:Any],
              json["service"] as? String == "Rokid OSM Voice",
              let version = json["version"] as? String else { return false }
        return version.hasPrefix("0.2.") || version.hasPrefix("0.3.") || version.hasPrefix("0.4.")
    }
}
