@MainActor
final class AirQualityViewModel: ObservableObject {
    @Published private(set) var loadState: AirQualityLoadState = .idle
    @Published private(set) var snapshot: AirQualitySnapshot?
    private var loadTask: Task<Void, Never>?
    private var requestGeneration = 0

    func load() {
        guard loadTask == nil else { return }
        startLoad(cancellingCurrent: false)
    }

    func refresh() {
        startLoad(cancellingCurrent: true)
    }

    private func startLoad(cancellingCurrent: Bool) {
        if cancellingCurrent { loadTask?.cancel() }
        requestGeneration += 1
        let generation = requestGeneration
        loadState = .loading

        loadTask = Task {
            let latest = try? await service.fetchCurrentAirQuality(
                latitude: 36.0190,
                longitude: 129.3434
            )
            guard !Task.isCancelled, generation == requestGeneration else { return }
            snapshot = latest
            loadState = latest == nil ? .failed("데이터를 불러오지 못했습니다.") : .loaded
        }
    }
}
