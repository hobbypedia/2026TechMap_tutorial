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
            attributionURL: viewModel.snapshot?.attributionURL,
            attributionMarkURL: viewModel.snapshot?.attributionMarkURL,
            pm25SourceURL: viewModel.snapshot?.pm25SourceURL,
            pm25ModelSourceURL: viewModel.snapshot?.pm25ModelSourceURL
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
