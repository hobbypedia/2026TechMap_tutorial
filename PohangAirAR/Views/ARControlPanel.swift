import SwiftUI

struct ARControlPanel: View {
    let hasSnapshot: Bool
    let isTrackingReady: Bool
    let isPlaced: Bool
    let place: () -> Void
    let replace: () -> Void
    let refresh: () -> Void
    let reset: () -> Void

    private var canPlace: Bool { hasSnapshot && isTrackingReady }

    var body: some View {
        VStack(spacing: 10) {
            Button(action: isPlaced ? replace : place) {
                Label(isPlaced ? "다시 배치" : "공간에 표시", systemImage: "arkit")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canPlace)
            .accessibilityLabel(isPlaced ? "환경 데이터 다시 배치" : "환경 데이터 공간에 표시")
            .accessibilityHint(canPlace ? "카메라 앞 1.2미터 위치에 표시합니다." : "데이터와 공간 추적이 준비될 때 활성화됩니다.")

            HStack(spacing: 10) {
                Button(action: refresh) {
                    Label("데이터 새로고침", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("포항 환경 데이터 새로고침")

                Button(role: .destructive, action: reset) {
                    Label("공간 초기화", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .disabled(!isPlaced)
                .accessibilityLabel("배치한 환경 데이터 제거")
            }
            .buttonStyle(.bordered)
            .font(.subheadline)
        }
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}
