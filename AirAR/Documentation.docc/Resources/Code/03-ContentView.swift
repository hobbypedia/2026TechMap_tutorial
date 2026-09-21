import SwiftUI

/// 3단계 체크포인트: AR을 붙이기 전에 위치와 환경 데이터 화면을 먼저 완성합니다.
struct ContentView: View {
    @StateObject private var viewModel: AirQualityViewModel
    @Environment(\.openURL) private var openURL

    init(viewModel: AirQualityViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? AirQualityViewModel())
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [.blue.opacity(0.72), .cyan.opacity(0.34)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                AirQualityStatusPanel(
                    locationName: viewModel.locationName,
                    metrics: viewModel.metrics,
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage
                )

                if viewModel.shouldShowLocationSettings {
                    Button {
                        guard let settingsURL = URL(
                            string: UIApplication.openSettingsURLString
                        ) else { return }
                        openURL(settingsURL)
                    } label: {
                        Label("위치 설정 열기", systemImage: "location.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button(action: viewModel.refresh) {
                    Label("새로고침", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isLoading)
            }
            .padding()
        }
        .onAppear(perform: viewModel.load)
        .onDisappear(perform: viewModel.cancel)
    }
}
