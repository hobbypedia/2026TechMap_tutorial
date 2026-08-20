ZStack {
    AirQualityARView(
        controller: arController,
        sessionState: $sessionState,
        animationsEnabled: !reduceMotion
    )
    .ignoresSafeArea()

    VStack {
        AirQualityStatusPanel(
            loadState: viewModel.loadState,
            snapshot: viewModel.snapshot
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
