import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AirQualityViewModel
    @StateObject private var arController = ARExperienceController()
    @State private var sessionState: ARSessionState = .initializing
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    init(viewModel: AirQualityViewModel? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel ?? AirQualityViewModel())
    }

    var body: some View {
        ZStack {
            AirQualityARView(
                controller: arController,
                sessionState: $sessionState,
                animationsEnabled: !reduceMotion
            )
                .environment(\.colorScheme, .dark)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                AirQualityStatusPanel(
                    locationName: viewModel.locationName,
                    metrics: viewModel.metrics,
                    isLoading: viewModel.isLoading,
                    errorMessage: viewModel.errorMessage,
                    sourceURL: viewModel.snapshot?.sourceURL,
                    airQualityModelSourceURL: viewModel.snapshot?.airQualityModelSourceURL
                )
                if viewModel.shouldShowLocationSettings {
                    Button {
                        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                        openURL(settingsURL)
                    } label: {
                        Label("위치 설정 열기", systemImage: "location.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange.opacity(0.9))
                }
                Spacer(minLength: 20)
                Button(action: refreshAndReposition) {
                    Label("새로고침", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black.opacity(0.72))
                .disabled(viewModel.isLoading)
                .accessibilityLabel("현재 위치 환경 데이터 새로고침")
            }
            .padding()
        }
        .onAppear(perform: viewModel.load)
        .onDisappear(perform: viewModel.cancel)
        .onChange(of: viewModel.snapshot) { _, snapshot in
            guard let snapshot else { return }
            if arController.isPlaced {
                arController.update(snapshot)
            } else {
                placeSnapshot()
            }
        }
        .onChange(of: sessionState) { _, _ in
            placeSnapshot()
        }
    }

    private func placeSnapshot() {
        guard let snapshot = viewModel.snapshot, sessionState.isReadyForPlacement else { return }
        arController.place(snapshot)
    }

    private func refreshAndReposition() {
        viewModel.refresh()
        placeSnapshot()
    }
}
