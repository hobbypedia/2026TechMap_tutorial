import SwiftUI

/// ViewModel이 만든 세 가지 현재 상태를 한 줄로 보여 주는 컴팩트 패널입니다.
struct AirQualityStatusPanel: View {
    let locationName: String
    let metrics: [AirQualityMetricViewModel]
    let isLoading: Bool
    let errorMessage: String?
    let attributionURL: URL?
    let attributionMarkURL: URL?
    let pm25SourceURL: URL?
    let pm25ModelSourceURL: URL?

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

            if let attributionURL, let attributionMarkURL {
                Link(destination: attributionURL) {
                    AsyncImage(url: attributionMarkURL) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        Text("Apple Weather")
                            .font(.caption2)
                    }
                    .frame(height: 14)
                }
                .accessibilityLabel("Apple Weather 데이터 출처 및 법적 고지")
            }

            if let pm25SourceURL, let pm25ModelSourceURL {
                HStack(spacing: 4) {
                    Text("PM2.5:")
                    Link("Open-Meteo", destination: pm25SourceURL)
                    Text("/")
                    Link("CAMS", destination: pm25ModelSourceURL)
                }
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
                .accessibilityLabel("미세먼지 데이터 출처 Open-Meteo와 Copernicus CAMS")
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
