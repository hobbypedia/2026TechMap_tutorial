import Foundation
import simd

/// 환경 수치를 RealityKit 시각화 속성으로 변환하는 순수 계산 모음입니다.
enum AirQualityVisualizationMapper {
    static let severePM25Threshold = 76.0

    /// PM2.5 농도를 초당 생성할 먼지 입자 수로 변환합니다.
    /// - Important: 이 규칙은 교육용 시각화이며 공식 건강 기준이 아닙니다.
    static func dustBirthRate(forPM25 value: Double) -> Float {
        guard value.isFinite else { return 35 }
        let clampedValue = max(value, 0)
        if clampedValue >= severePM25Threshold {
            return min(320 + Float(clampedValue - severePM25Threshold) * 0.65, 520)
        }
        return 35 + Float(clampedValue) * 3
    }

    /// PM2.5가 높을수록 입자를 조금 더 불투명하게 만듭니다.
    static func dustOpacity(forPM25 value: Double) -> Float {
        guard value.isFinite else { return 0.14 }
        let normalized = min(max(Float(value / severePM25Threshold), 0), 1)
        return 0.14 + normalized * 0.20
    }

    /// UV Index를 시각화용 `0...1` 값으로 변환합니다.
    /// - Important: 이 값은 데이터 표현용이며 의료 또는 행동 지침이 아닙니다.
    static func normalizedUV(for value: Double) -> Float {
        min(max(Float(value / 11), 0), 1)
    }

    /// 약한 UV는 매우 옅게, 강한 UV는 점진적으로 선명하게 표현합니다.
    static func uvOpacity(for value: Double) -> Float {
        0.06 + normalizedUV(for: value) * 0.36
    }

    /// 카메라가 태양을 정면으로 바라볼수록 렌즈 플레어를 부드럽게 강하게 만듭니다.
    static func solarFlareIntensity(
        cameraForward: SIMD3<Float>,
        directionToSun: SIMD3<Float>
    ) -> Float {
        let cameraLengthSquared = simd_length_squared(cameraForward)
        let sunLengthSquared = simd_length_squared(directionToSun)
        guard cameraLengthSquared.isFinite,
              sunLengthSquared.isFinite,
              cameraLengthSquared > 0.0001,
              sunLengthSquared > 0.0001 else {
            return 0
        }

        let alignment = simd_dot(
            cameraForward / sqrt(cameraLengthSquared),
            directionToSun / sqrt(sunLengthSquared)
        )
        let linear = min(max((alignment - 0.82) / (0.985 - 0.82), 0), 1)
        return linear * linear * (3 - 2 * linear)
    }

    /// 기상 풍향은 바람이 불어오는 방향이므로 180도 반대인 먼지 이동 방향으로 변환합니다.
    /// `gravityAndHeading` 월드에서 X축은 동쪽, -Z축은 북쪽입니다.
    static func windTravelDirection(forMeteorologicalDegrees degrees: Double) -> SIMD2<Float> {
        guard degrees.isFinite else { return .zero }
        let radians = Float(degrees * .pi / 180)
        return SIMD2<Float>(-sin(radians), cos(radians))
    }

    /// 실제 풍속을 AR에서 식별 가능하면서 과도하지 않은 이동 속도로 매핑합니다.
    static func visualWindSpeed(forMetersPerSecond value: Double) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(Float(value), 0) * 0.035, 0.65)
    }

}
