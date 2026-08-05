import Combine
import Foundation

/// 포항 환경 데이터 요청과 화면 상태를 관리합니다.
@MainActor
final class AirQualityViewModel: ObservableObject {
    static let pohangCityHallLatitude = 36.0190
    static let pohangCityHallLongitude = 129.3434

    @Published private(set) var loadState: AirQualityLoadState = .idle
    @Published private(set) var snapshot: AirQualitySnapshot?

    private let service: any AirQualityServiceProtocol
    private var loadTask: Task<Void, Never>?
    private var requestGeneration = 0

    init(service: any AirQualityServiceProtocol = OpenMeteoAirQualityService()) {
        self.service = service
    }

    /// 최초 데이터를 불러옵니다. 이미 요청 중이면 중복 요청을 만들지 않습니다.
    func load() {
        guard loadTask == nil else { return }
        startLoad(cancellingCurrent: false)
    }

    /// 진행 중인 요청을 취소하고 최신 데이터를 다시 요청합니다.
    func refresh() {
        startLoad(cancellingCurrent: true)
    }

    /// 실패한 요청을 다시 시도합니다.
    func retry() {
        startLoad(cancellingCurrent: true)
    }

    /// 화면이 사라질 때 진행 중인 네트워크 작업을 정리합니다.
    func cancel() {
        loadTask?.cancel()
        loadTask = nil
    }

    private func startLoad(cancellingCurrent: Bool) {
        if cancellingCurrent {
            loadTask?.cancel()
        } else if loadTask != nil {
            return
        }

        requestGeneration += 1
        let generation = requestGeneration
        loadState = .loading
        loadTask = Task { [weak self, service] in
            do {
                let snapshot = try await service.fetchCurrentAirQuality(
                    latitude: Self.pohangCityHallLatitude,
                    longitude: Self.pohangCityHallLongitude
                )
                guard !Task.isCancelled, self?.requestGeneration == generation else { return }
                self?.snapshot = snapshot
                self?.loadState = .loaded
            } catch let error as AirQualityServiceError where error == .cancelled {
                // 새로고침이나 화면 종료로 취소된 요청은 오류로 노출하지 않습니다.
            } catch is CancellationError {
                // 취소는 사용자에게 실패 상태로 표시하지 않습니다.
            } catch {
                guard !Task.isCancelled, self?.requestGeneration == generation else { return }
                self?.loadState = .failed(
                    (error as? LocalizedError)?.errorDescription
                        ?? "환경 데이터를 불러오지 못했습니다."
                )
            }
            if self?.requestGeneration == generation {
                self?.loadTask = nil
            }
        }
    }
}
