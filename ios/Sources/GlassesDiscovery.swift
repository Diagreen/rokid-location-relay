import Foundation
import Darwin

// Bonjour plus bounded, unauthenticated /health probes. No code or position is sent during discovery.
@MainActor final class GlassesDiscovery: NSObject, NetServiceBrowserDelegate, NetServiceDelegate {
    var onFound: ((String) -> Void)?
    var onStatus: ((String) -> Void)?
    var onFinished: (() -> Void)?
    private var browser: NetServiceBrowser?
    private var services: [NetService] = []
    private var scan: Task<Void, Never>?
    private var timer: Task<Void, Never>?
    private var probes: [Task<Void, Never>] = []
    private var seen = Set<String>()
    private var generation = UUID()
    private let redirects = NoRedirects()
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.timeoutIntervalForResource = 3
        return URLSession(configuration: config, delegate: redirects, delegateQueue: nil)
    }()
    func start() {
        stop(); seen = []; let current = generation
        onStatus?("안경 찾는 중 · 로컬 네트워크 접근을 허용하세요.")
        let browser = NetServiceBrowser(); browser.delegate = self; self.browser = browser
        browser.searchForServices(ofType: "_rokidnav._tcp.", inDomain: "local.")
        let hosts = DiscoveryPlan.candidates(interfaces: Self.interfaces())
        scan = Task { [weak self] in
            guard let self else { return }
            // Eight probes at a time; timeout/cancellation prevents unbounded local traffic.
            for offset in stride(from: 0, to: hosts.count, by: 8) {
                if Task.isCancelled || self.generation != current { return }
                await withTaskGroup(of: String?.self) { group in
                    for host in hosts[offset..<min(hosts.count,offset+8)] {
                        group.addTask { [session = self.session] in
                            let base = "http://\(host):8765"
                            guard let url = URL(string: base + "/health") else { return nil }
                            var request = URLRequest(url: url); request.timeoutInterval = 1.5
                            do {
                                let (data,response) = try await session.data(for: request)
                                return (response as? HTTPURLResponse)?.statusCode == 200 && DiscoveryPlan.isGlasses(data) ? base : nil
                            } catch { return nil }
                        }
                    }
                    for await base in group {
                        if self.generation == current, !Task.isCancelled, let base { self.found(base) }
                    }
                }
            }
            // Keep Bonjour running briefly if address probes completed quickly.
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if !Task.isCancelled && self.generation == current { self.finish() }
        }
        timer = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 55_000_000_000)
            guard !Task.isCancelled, let self, self.generation == current else { return }
            self.finish()
        }
    }
    private func found(_ base: String) {
        guard PairingProtocol.baseURL(base) != nil, seen.insert(base).inserted else { return }
        onFound?(base)
    }
    private func finish() {
        let foundAny = !seen.isEmpty
        stop()
        onStatus?(foundAny ? "안경 탐색 완료 · 6자리 코드로 연결하세요." : "안경을 찾지 못했습니다. 로컬 네트워크 권한, 안경 앱 실행, 핫스팟 실제 연결을 확인하세요.")
        onFinished?()
    }
    func stop() {
        generation = UUID(); scan?.cancel(); scan = nil; timer?.cancel(); timer = nil
        probes.forEach { $0.cancel() }; probes = []
        browser?.stop(); browser = nil; services.forEach { $0.stop() }; services = []
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        guard self.browser === browser else { return }
        services.append(service); service.delegate = self; service.resolve(withTimeout: 4)
    }
    func netServiceBrowser(_ browser: NetServiceBrowser, didNotSearch errorDict: [String : NSNumber]) {
        guard self.browser === browser else { return }
        onStatus?("Bonjour 탐색 불가 · 핫스팟 주소 탐색 계속 중. 로컬 네트워크 권한을 확인하세요.")
    }
    func netServiceDidResolveAddress(_ sender: NetService) {
        guard services.contains(where: { $0 === sender }), sender.port == 8765 else { return }
        let current = generation
        var bases: [String] = []
        if let hostname = sender.hostName {
            let host = hostname.hasSuffix(".") ? String(hostname.dropLast()) : hostname
            let base = "http://\(host):8765"
            if PairingProtocol.baseURL(base) != nil { bases.append(base) }
        }
        for data in sender.addresses ?? [] {
            let bytes = [UInt8](data)
            guard bytes.count >= 8, bytes[1] == UInt8(AF_INET) else { continue }
            let host = bytes[4...7].map { String($0) }.joined(separator: ".")
            let base = "http://\(host):8765"
            if PairingProtocol.baseURL(base) != nil { bases.append(base) }
        }
        // Prefer the Bonjour hostname; IPv4 address remains a fallback if mDNS URL resolution fails.
        probes.append(Task { [weak self] in
            guard let self else { return }
            for base in bases {
                if Task.isCancelled || self.generation != current { return }
                guard let url = URL(string: base + "/health") else { continue }
                do {
                    let (data,response) = try await self.session.data(from: url)
                    if !Task.isCancelled, self.generation == current,
                       (response as? HTTPURLResponse)?.statusCode == 200, DiscoveryPlan.isGlasses(data) { self.found(base); return }
                } catch { }
            }
        })
    }

    private static func interfaces() -> [(String,String)] {
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }
        func numeric(_ address: UnsafePointer<sockaddr>?) -> String? {
            guard let address, Int32(address.pointee.sa_family) == AF_INET else { return nil }
            var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(address,socklen_t(address.pointee.sa_len),&buffer,socklen_t(buffer.count),nil,0,NI_NUMERICHOST) == 0 else { return nil }
            return String(cString: buffer)
        }
        var result: [(String,String)] = []
        var pointer: UnsafeMutablePointer<ifaddrs>? = first
        while let p = pointer {
            let name = String(cString: p.pointee.ifa_name)
            if name.hasPrefix("en") || name.hasPrefix("bridge") || name.hasPrefix("ap") {
                if let ip = numeric(p.pointee.ifa_addr), let mask = numeric(p.pointee.ifa_netmask) { result.append((ip,mask)) }
            }
            pointer = p.pointee.ifa_next
        }
        return result
    }
}
