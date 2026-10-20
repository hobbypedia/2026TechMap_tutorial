import SwiftUI

/// Displays one formatted metric and combines its content into a single accessibility element.
/// 형식이 지정된 환경 수치 하나를 표시하고 내용을 하나의 접근성 요소로 묶습니다.
struct MetricView: View {
    let viewModel: AirQualityMetricViewModel

    var body: some View {
        VStack(spacing: 3) {
            Label(viewModel.title, systemImage: viewModel.symbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 4) {
                if let level = viewModel.level {
                    Text(level.title)
                        .foregroundStyle(level.color)
                }
                Text(viewModel.value)
            }
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(viewModel.title)
        .accessibilityValue(viewModel.accessibilityValue)
    }
}

private extension AirQualityLevel {
    var color: Color {
        switch self {
        case .veryBad: .red
        case .bad: .orange
        case .moderate: .primary
        case .good: .green
        case .veryGood: .blue
        }
    }
}
