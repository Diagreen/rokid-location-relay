import SwiftUI
import MapKit

struct DestinationOption: Identifiable {
    let id = UUID()
    let name: String
    let address: String
    let coordinate: CLLocationCoordinate2D
}
@MainActor final class DestinationSearch: ObservableObject {
    @Published var query = ""
    @Published var results: [DestinationOption] = []
    @Published var selected: DestinationOption?
    @Published var searching = false
    @Published var message = "건물명·기관명 또는 주소를 입력하세요."
    private var operation: MKLocalSearch?
    private var task: Task<Void,Never>?
    private var generation = UUID()
    func search(near coordinate: CLLocationCoordinate2D?) {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, text.count <= 160 else { message = "검색어는 1~160자로 입력하세요."; return }
        operation?.cancel(); task?.cancel(); generation = UUID(); let current = generation
        results = []; selected = nil; searching = true; message = "Apple 지도에서 검색 중…"
        let request = MKLocalSearch.Request(); request.naturalLanguageQuery = text
        request.resultTypes = [.address,.pointOfInterest]
        request.region = MKCoordinateRegion(center: coordinate ?? CLLocationCoordinate2D(latitude:36.2,longitude:127.8), span: MKCoordinateSpan(latitudeDelta:coordinate == nil ? 7 : 1,longitudeDelta:coordinate == nil ? 7 : 1))
        let operation = MKLocalSearch(request: request); self.operation = operation
        task = Task { [weak self] in
            do {
                let response = try await operation.start()
                guard let self, !Task.isCancelled, self.generation == current else { return }
                self.results = response.mapItems.prefix(15).compactMap { item in
                    let point = item.placemark.coordinate
                    guard CLLocationCoordinate2DIsValid(point) else { return nil }
                    return DestinationOption(name:item.name ?? text,address:item.placemark.title ?? "",coordinate:point)
                }
                self.searching = false
                self.message = self.results.isEmpty ? "검색 결과가 없습니다. 지역명과 건물명을 함께 입력해 보세요." : "검색 결과에서 목적지를 선택하세요."
            } catch {
                guard let self, !Task.isCancelled, self.generation == current else { return }
                self.searching = false; self.message = "검색 실패: \(error.localizedDescription)"
            }
        }
    }
}

struct DestinationControls: View {
    @EnvironmentObject var relay: LocationRelay
    @StateObject private var search = DestinationSearch()
    @State private var mode: TravelMode = .bicycle
    @FocusState private var editing: Bool
    var body: some View {
        Group {
            Section("3 · iPhone에서 목적지 검색") {
                TextField("예: 서울시청, 전북대학교, 도로명주소",text:$search.query)
                    .submitLabel(.search).autocorrectionDisabled().focused($editing)
                    .onSubmit { editing = false; search.search(near:relay.latestCoordinate) }
                    .onChange(of:search.query) { _ in search.selected = nil }
                Button(search.searching ? "검색 중…" : "검색") { editing = false; search.search(near:relay.latestCoordinate) }
                    .disabled(search.searching || search.query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty)
                Text(search.message).font(.footnote)
                ForEach(search.results) { result in
                    Button { editing = false; search.selected = result } label: {
                        HStack {
                            VStack(alignment:.leading,spacing:4) {
                                Text(result.name).font(.body.weight(.semibold))
                                Text(result.address).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if search.selected?.id == result.id { Image(systemName:"checkmark.circle.fill") }
                        }
                    }
                }
                Picker("이동수단",selection:$mode) { ForEach(TravelMode.allCases) { Text($0.title).tag($0) } }.pickerStyle(.segmented)
                if let selected = search.selected {
                    Text("선택: \(selected.name)").font(.footnote)
                    Button("안경으로 안내 시작") { relay.sendDestination(selected,mode:mode) }
                        .disabled(!relay.active || relay.commandBusy)
                }
                Text("먼저 안경 연결과 위치 전송을 시작하세요. 검색은 Apple 지도, 안경 지도·경로는 OSM 기반입니다.").font(.footnote)
            }
            Section("4 · 안경 지도 범위") {
                HStack {
                    Button("축소 −") { relay.changeMap("zoomOut") }
                    Spacer()
                    Button("확대 ＋") { relay.changeMap("zoomIn") }
                    Spacer()
                    Button("전체 경로") { relay.changeMap("overview") }
                }.buttonStyle(.bordered).disabled(!relay.active || relay.commandBusy)
                Text(relay.commandStatus).font(.footnote)
                Text("축소할수록 한 화면에 더 넓은 도로가 보입니다. 안경에서도 슬라이드로 확대·축소 버튼을 선택하고 터치해 실행할 수 있습니다.").font(.footnote)
            }
        }
    }
}
