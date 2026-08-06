import SwiftUI

/// ViewModel이 만든 세 가지 현재 상태를 한 줄로 보여 주는 컴팩트 패널입니다.
struct AirQualityStatusPanel: View {
    let locationName: String
    let metrics: [AirQualityMetricViewModel]
    let isLoading: Bool
    let errorMessage: String?

    var body: some View {
        VStack(spacing: 9) {
            Label(locationName, systemImage: "location.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .accessibilityLabel("환경 데이터 위치 \(locationName)")

            HStack(spacing: 0) {
                ForEach(metrics) { metric in
                    if metric.id != metrics.first?.id {
                        divider
                    }
                    MetricView(viewModel: metric)
                }
            }

            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var divider: some View {
        Divider()
            .frame(height: 38)
            .overlay(.white.opacity(0.16))
    }
}
