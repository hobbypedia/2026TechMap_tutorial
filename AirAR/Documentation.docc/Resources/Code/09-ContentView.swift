ZStack {
    AirQualityARView(
        controller: arController,
        sessionState: $sessionState,
        animationsEnabled: !reduceMotion
    )
    .ignoresSafeArea()

    VStack {
        AirQualityStatusPanel(
            locationName: viewModel.locationName,
            metrics: viewModel.metrics,
            isLoading: viewModel.isLoading,
            errorMessage: viewModel.errorMessage,
            sourceURL: viewModel.snapshot?.sourceURL,
            airQualityModelSourceURL: viewModel.snapshot?.airQualityModelSourceURL
        )
        Spacer()
        Button("새로고침", systemImage: "arrow.clockwise") {
            refreshAndReposition()
        }
    }
    .padding()
}
.onChange(of: sessionState) { _, _ in
    placeSnapshotWhenReady()
}

private func refreshAndReposition() {
    viewModel.refresh()
    placeSnapshotWhenReady()
}
