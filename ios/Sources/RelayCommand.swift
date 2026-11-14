import Foundation

enum TravelMode: String, CaseIterable, Identifiable {
    case bicycle, pedestrian
    var id: String { rawValue }
    var title: String { self == .bicycle ? "자전거" : "도보" }
}
enum RelayCommand {
    static func destination(name: String, latitude: Double, longitude: Double, mode: TravelMode) throws -> Data {
        let label = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100))
        guard !label.isEmpty, latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw NSError(domain: "Rokid", code: 1, userInfo: [NSLocalizedDescriptionKey:"목적지 이름과 좌표를 확인하세요."])
        }
        return try JSONSerialization.data(withJSONObject: ["name":label,"lat":latitude,"lon":longitude,"mode":mode.rawValue])
    }
    static func map(_ action: String) throws -> Data {
        guard ["zoomIn","zoomOut","overview"].contains(action) else { throw NSError(domain:"Rokid",code:2) }
        return try JSONSerialization.data(withJSONObject: ["action":action])
    }
}
