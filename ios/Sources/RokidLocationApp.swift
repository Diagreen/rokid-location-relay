import SwiftUI
import CoreLocation

@main struct RokidLocationApp: App {
    @StateObject private var relay = LocationRelay()
    var body: some Scene { WindowGroup { ContentView().environmentObject(relay) } }
}

@MainActor final class LocationRelay: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var address = UserDefaults.standard.string(forKey: "address") ?? "http://192.168.1.10:8765"
    // Session token is intentionally not persisted; each glasses launch generates a new token.
    @Published var token = ""
    @Published var status = "안경에 표시된 IP와 연결 토큰을 입력하세요."
    @Published var active = false
    private let manager = CLLocationManager()
    private var destination: URL?
    private var sessionToken = ""
    private var task: URLSessionDataTask?
    private var sentAt = Date.distantPast
    private var generation = UUID()
    override init() {
        super.init(); manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .otherNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }
    func start() {
        guard let parts = URLComponents(string: address.trimmingCharacters(in: .whitespacesAndNewlines)),
              parts.scheme == "http", let host = parts.host,
              Self.isPrivateIPv4(host), parts.port == 8765,
              (parts.path.isEmpty || parts.path == "/"), parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil,
              token.count == 32, token.allSatisfy({ $0.isHexDigit }),
              let url = URL(string: "http://\(host):8765/fix") else {
            status = "개인 Wi-Fi IPv4 주소, 포트 8765, 32자리 토큰을 확인하세요."; return
        }
        stop(); destination = url; sessionToken = token.lowercased(); active = true
        generation = UUID(); UserDefaults.standard.set(address, forKey: "address")
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
        status = "위치 권한과 정확한 위치를 허용하세요. 연결 확인 중…"
    }
    static func isPrivateIPv4(_ host: String) -> Bool {
        let octets = host.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4, octets.allSatisfy({ (0...255).contains($0) }) else { return false }
        return octets[0] == 10 || (octets[0] == 192 && octets[1] == 168) ||
            (octets[0] == 172 && (16...31).contains(octets[1]))
    }
    func enableBackground() { manager.requestAlwaysAuthorization() }
    func stop() {
        active = false; generation = UUID(); task?.cancel(); task = nil
        manager.stopUpdatingLocation(); status = "위치 전송 중지"
    }
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            stop(); status = "설정에서 위치 및 정확한 위치 권한을 허용하세요."
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        status = "위치 오류: \(error.localizedDescription)"
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard active, let location = locations.last, let url = destination,
              abs(location.timestamp.timeIntervalSinceNow) < 10,
              location.horizontalAccuracy > 0, location.horizontalAccuracy <= 35 else {
            if active { status = "정확한 GPS 대기 — 실외에서 확인하세요." }; return
        }
        guard task == nil, Date().timeIntervalSince(sentAt) >= 1 else { return }
        sentAt = Date(); let current = generation
        let payload: [String: Any] = ["lat": location.coordinate.latitude, "lon": location.coordinate.longitude,
                                     "accuracy": location.horizontalAccuracy,
                                     "timestamp": Int64(location.timestamp.timeIntervalSince1970 * 1000)]
        var request = URLRequest(url: url); request.httpMethod = "POST"; request.timeoutInterval = 4
        request.setValue(sessionToken, forHTTPHeaderField: "X-Rokid-Token")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        task = URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
            Task { @MainActor in
                guard let self, self.generation == current else { return }; self.task = nil
                if let error { self.status = "연결 대기: \(error.localizedDescription)" }
                else if (response as? HTTPURLResponse)?.statusCode == 200 {
                    self.status = "안경 연결됨 · 위치 오차 약 \(Int(location.horizontalAccuracy)) m"
                } else if (response as? HTTPURLResponse)?.statusCode == 401 {
                    self.status = "토큰 불일치 — 안경에 표시된 새 토큰을 입력하세요."
                } else { self.status = "위치 거부: 시각·정확도·휴대전화 시간 설정을 확인하세요." }
            }
        }; task?.resume()
    }
}

struct ContentView: View {
    @EnvironmentObject var relay: LocationRelay
    var body: some View {
        NavigationStack {
            Form {
                Section("1 · 같은 Wi-Fi / iPhone 개인용 핫스팟") {
                    Text("안경 Wi-Fi를 연결하고 APK를 시작하세요. 안경의 IP와 토큰을 아래에 입력합니다.")
                    TextField("http://안경IP:8765", text: $relay.address).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).disabled(relay.active)
                    TextField("32자리 연결 토큰", text: $relay.token).textInputAutocapitalization(.never).autocorrectionDisabled().disabled(relay.active)
                }
                Section("2 · 위치 연결") {
                    Button(relay.active ? "위치 전송 중지" : "위치 전송 시작") { if relay.active { relay.stop() } else { relay.start() } }
                    Button("백그라운드 위치 권한 요청") { relay.enableBackground() }
                    Text(relay.status)
                    Text("위치 권한의 ‘정확한 위치’를 켜세요. 화면 잠금 후 연결 지속 여부는 iPhone 실기기에서 확인해야 합니다.").font(.footnote)
                }
                Section("3 · 안경에서 말하기") { Text("목적지 → 후보 번호 → 자전거 또는 도보.\n음성·LLM은 안경에서 처리하며 지도 검색과 경로 계산에는 인터넷이 필요합니다.") }
            }.navigationTitle("Rokid 위치 연결")
        }
    }
}
