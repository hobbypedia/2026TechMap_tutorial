import SwiftUI

/// 화면 상단에서 세 가지 현재 값만 한 줄로 보여 주는 컴팩트 패널입니다.
struct AirQualityStatusPanel: View {
    let loadState: AirQualityLoadState
    let snapshot: AirQualitySnapshot?

    var body: some View {
        VStack(spacing: 9) {
            HStack(spacing: 0) {
                MetricView(
                    title: "온도",
                    value: snapshot.map { String(format: "%.1f°", $0.temperature) } ?? "—",
                    accessibilityValue: snapshot.map { String(format: "섭씨 %.1f도", $0.temperature) } ?? "불러오는 중",
                    symbol: "thermometer.medium"
                )
                divider
                MetricView(
                    title: "미세먼지",
                    value: snapshot.map { String(format: "%.1f", $0.pm25) } ?? "—",
                    accessibilityValue: snapshot.map { String(format: "%.1f 마이크로그램 퍼 세제곱미터", $0.pm25) } ?? "불러오는 중",
                    symbol: "aqi.medium"
                )
                divider
                MetricView(
                    title: "UV",
                    value: snapshot.map { String(format: "%.1f", $0.uvIndex) } ?? "—",
                    accessibilityValue: snapshot.map { String(format: "자외선 지수 %.1f", $0.uvIndex) } ?? "불러오는 중",
                    symbol: "sun.max.fill"
                )
            }

            if case .loading = loadState {
                ProgressView()
                    .controlSize(.small)
            } else if case let .failed(message) = loadState {
                Text(message)
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
