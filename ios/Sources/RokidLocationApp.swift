import SwiftUI
import CoreLocation

@main struct RokidLocationApp: App {
    @StateObject private var relay = LocationRelay()
    var body: some Scene { WindowGroup { ContentView().environmentObject(relay) } }
}

@MainActor final class LocationRelay: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var address = UserDefaults.standard.string(forKey: "address") ?? ""
    // Pairing secrets stay in memory; only the address is persisted.
    @Published var code = ""
    @Published var pairing = false
    @Published var status = "안경 자동 탐색 후 6자리 연결 코드를 입력하세요."
    @Published var active = false
    @Published var discovering = false
    @Published var devices: [String] = []
    @Published var sentCount = 0
    private lazy var discovery: GlassesDiscovery = {
        let value = GlassesDiscovery()
        value.onFound = { [weak self] base in
            guard let self else { return }
            self.devices.append(base)
            if self.devices.count == 1 { self.address = base }
            self.status = "안경 발견: \(self.devices.count)대 · 6자리 코드를 입력하고 위치 전송을 시작하세요."
        }
        value.onStatus = { [weak self] message in self?.status = message }
        value.onFinished = { [weak self] in self?.discovering = false }
        return value
    }()
    func findGlasses() {
        guard !active && !pairing else { return }
        devices = []; address = ""; discovering = true; discovery.start()
    }

    private let manager = CLLocationManager()
    private var destination: URL?
    private var sessionToken = ""
    private var pairedAddress: String?
    private let redirects = NoRedirects()
    private lazy var session = URLSession(configuration: .ephemeral, delegate: redirects, delegateQueue: nil)
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
        let input = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = PairingProtocol.baseURL(input) else {
            findGlasses(); return
        }
        guard !pairing else { return }
        if code.isEmpty, pairedAddress == base.absoluteString, !sessionToken.isEmpty {
            beginLocation(base); return
        }
        guard PairingProtocol.validCode(code) else {
            status = "안경에 표시된 숫자 6자리를 입력하세요."; return
        }
        stop(); sentCount = 0; pairing = true; sessionToken = ""; pairedAddress = nil
        let current = generation
        var request = URLRequest(url: base.appendingPathComponent("pair"))
        request.httpMethod = "POST"; request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ["code": code])
        status = "안경과 연결 중…"
        task = session.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor in
                guard let self, self.generation == current else { return }
                self.task = nil; self.pairing = false
                if let error {
                    self.status = "연결 실패: \(error.localizedDescription) · 코드가 이미 사용됐다면 안경 설정에서 재발급하세요."
                    return
                }
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard statusCode == 200, let data, let token = PairingProtocol.token(from: data) else {
                    self.status = PairingProtocol.errorMessage(statusCode); return
                }
                self.sessionToken = token; self.pairedAddress = base.absoluteString; self.code = ""
                self.beginLocation(base)
            }
        }; task?.resume()
    }
    private func beginLocation(_ base: URL) {
        destination = base.appendingPathComponent("fix"); active = true
        generation = UUID(); sentAt = .distantPast
        UserDefaults.standard.set(base.absoluteString, forKey: "address")
        manager.requestWhenInUseAuthorization(); manager.startUpdatingLocation()
        status = "페어링 완료 · 위치 권한과 정확한 위치를 허용하세요."
    }
    func enableBackground() { manager.requestAlwaysAuthorization() }
    func stop() {
        discovery.stop(); discovering = false
        active = false; pairing = false; generation = UUID(); task?.cancel(); task = nil
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
        task = session.dataTask(with: request) { [weak self] _, response, error in
            Task { @MainActor in
                guard let self, self.generation == current else { return }; self.task = nil
                if let error { self.status = "연결 대기: \(error.localizedDescription)" }
                else if (response as? HTTPURLResponse)?.statusCode == 200 {
                    self.sentCount += 1
                    self.status = "위치 전송 성공 \(self.sentCount)회 · 오차 약 \(Int(location.horizontalAccuracy)) m"
                } else if (response as? HTTPURLResponse)?.statusCode == 401 {
                    self.stop(); self.sessionToken = ""; self.pairedAddress = nil
                    self.status = "연결 만료 · 안경 설정에서 코드를 재발급한 뒤 입력하세요."
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
                    Text("안경을 이 iPhone의 핫스팟 또는 같은 Wi-Fi에 연결하고 안경 앱을 실행하세요. 자동 탐색 후 6자리 코드만 입력하면 됩니다.")
                    Button(relay.discovering ? "안경 탐색 중… 다시 찾기" : "안경 자동 탐색") { relay.findGlasses() }.disabled(relay.active || relay.pairing)
                    ForEach(relay.devices, id: \.self) { device in
                        Button((relay.address == device ? "✓ " : "") + device) { relay.address = device }.disabled(relay.active || relay.pairing)
                    }
                    TextField("자동으로 찾은 안경 주소 / 직접 입력 가능", text: $relay.address).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL).disabled(relay.active || relay.pairing)
                    TextField("6자리 일회용 코드", text: $relay.code).keyboardType(.numberPad).textContentType(.oneTimeCode).autocorrectionDisabled().disabled(relay.active || relay.pairing)
                }
                Section("2 · 위치 연결") {
                    Button(relay.active ? "위치 전송 중지" : "위치 전송 시작") { if relay.active { relay.stop() } else { relay.start() } }.disabled(relay.pairing)
                    Button("백그라운드 위치 권한 요청") { relay.enableBackground() }
                    Text(relay.status)
                    Text("위치 권한의 ‘정확한 위치’를 켜세요. 화면 잠금 후 연결 지속 여부는 iPhone 실기기에서 확인해야 합니다.").font(.footnote)
                }
                Section("3 · 안경에서 말하기") { Text("목적지 → 후보 번호 → 자전거 또는 도보.\n음성·LLM은 안경에서 처리하며 지도 검색과 경로 계산에는 인터넷이 필요합니다.") }
            }.navigationTitle("Rokid 위치 연결")
        }
    }
}

