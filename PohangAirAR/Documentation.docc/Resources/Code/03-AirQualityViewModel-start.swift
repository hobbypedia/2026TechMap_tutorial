@MainActor
final class AirQualityViewModel: ObservableObject {
    @Published private(set) var loadState: AirQualityLoadState = .idle
    @Published private(set) var snapshot: AirQualitySnapshot?
}
