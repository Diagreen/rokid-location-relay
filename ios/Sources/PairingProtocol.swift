import Foundation

enum PairingProtocol {
    static func validCode(_ code: String) -> Bool {
        code.utf8.count == 6 && code.utf8.allSatisfy { (48...57).contains($0) }
    }
    static func baseURL(_ input: String) -> URL? {
        guard let p = URLComponents(string: input), p.scheme == "http", let host = p.host,
              p.port == 8765, (p.path.isEmpty || p.path == "/"),
              p.user == nil, p.password == nil, p.query == nil, p.fragment == nil else { return nil }
        let components = host.split(separator: ".", omittingEmptySubsequences: false)
        guard components.count == 4, components.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy { (48...57).contains($0) } }) else { return nil }
        let o = components.compactMap { Int($0) }
        guard o.count == 4, o.allSatisfy({ (0...255).contains($0) }),
              o[0] == 10 || (o[0] == 192 && o[1] == 168) || (o[0] == 172 && (16...31).contains(o[1])) else { return nil }
        return URL(string: "http://\(host):8765")
    }
    static func token(from data: Data) -> String? {
        guard let body = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = body["token"] as? String, token.utf8.count == 32,
              token.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else { return nil }
        return token
    }
    static func errorMessage(_ status: Int) -> String {
        switch status {
        case 401: return "연결 코드가 틀립니다. 5회 실패하면 안경에서 재발급해야 합니다."
        case 409: return "이미 사용한 코드입니다. 안경 설정에서 코드를 재발급하세요."
        case 410: return "코드가 만료됐습니다. 안경 설정에서 코드를 재발급하세요."
        case 429: return "5회 입력 제한에 도달했습니다. 안경 설정에서 코드를 재발급하세요."
        default: return "페어링 실패 · 안경 APK도 6자리 코드 지원 버전인지 확인하세요."
        }
    }
}
