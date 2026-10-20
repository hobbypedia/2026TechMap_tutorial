import Foundation
import simd

/// Pure calculations mapping environmental readings to RealityKit visualization properties.
/// 환경 수치를 RealityKit 도형의 개수와 크기로 변환하는 순수 계산 모음입니다.
enum AirQualityVisualizationMapper {
    static let severePM25Threshold = 76.0
    static let particleLifeSpan: Double = 8

    /// Sharply increases particle births per second at the severe PM2.5 threshold to fill more of the space.
    /// PM2.5가 심각 수준에 도달하면 초당 생성량을 급격히 늘려 공간을 더 채웁니다.
    /// - Important: This rule is for educational visualization, not an official health standard.
    ///   이 규칙은 교육용 시각화이며 공식 건강 기준이 아닙니다.
    static func particleBirthRate(forPM25 value: Double) -> Float {
        let clampedValue = max(value, 0)
        if clampedValue >= severePM25Threshold {
            return min(120 + Float(clampedValue - severePM25Threshold) * 0.6, 180)
        }
        return min(max(Float(clampedValue) * 2.0, 30), 90)
    }

    /// Maps UV Index to a visualization value in `0...1`.
    /// UV Index를 시각화용 `0...1` 값으로 변환합니다.
    /// - Important: This value is for data visualization, not medical or behavioral guidance.
    ///   이 값은 데이터 표현용이며 의료 또는 행동 지침이 아닙니다.
    static func normalizedUV(for value: Double) -> Float {
        min(max(Float(value / 11), 0), 1)
    }

    /// Renders low UV levels faintly and increases visibility progressively as UV rises.
    /// 약한 UV는 매우 옅게, 강한 UV는 점진적으로 선명하게 표현합니다.
    static func uvOpacity(for value: Double) -> Float {
        0.06 + normalizedUV(for: value) * 0.36
    }

    /// Smoothly increases lens flare intensity as the camera points more directly toward the sun.
    /// 카메라가 태양을 정면으로 바라볼수록 렌즈 플레어를 부드럽게 강하게 만듭니다.
    static func solarFlareIntensity(
        cameraForward: SIMD3<Float>,
        directionToSun: SIMD3<Float>
    ) -> Float {
        // Reject invalid or near-zero vectors before normalization to avoid undefined directions.
        // 정규화하기 전에 유효하지 않거나 길이가 거의 0인 벡터를 제외해 방향 계산 오류를 방지합니다.
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
        // Remap alignment into 0...1 and apply a smoothstep curve for a gradual flare transition.
        // 정렬 정도를 0...1로 변환하고 smoothstep 곡선으로 플레어 강도를 부드럽게 바꿉니다.
        let linear = min(max((alignment - 0.80) / (0.985 - 0.80), 0), 1)
        return linear * linear * (3 - 2 * linear)
    }

    /// Converts the direction wind comes from into the opposite direction in which dust travels.
    /// 기상 풍향은 바람이 불어오는 방향이므로 180도 반대인 먼지 이동 방향으로 변환합니다.
    /// In a `gravityAndHeading` world, positive X points east and negative Z points north.
    /// `gravityAndHeading` 월드에서 X축은 동쪽, -Z축은 북쪽입니다.
    static func windTravelDirection(forMeteorologicalDegrees degrees: Double) -> SIMD2<Float> {
        guard degrees.isFinite else { return .zero }
        let radians = Float(degrees * .pi / 180)
        return SIMD2<Float>(-sin(radians), cos(radians))
    }

    /// Maps real wind speed to a visible but restrained movement speed in AR.
    /// 실제 풍속을 AR에서 식별 가능하면서 과도하지 않은 이동 속도로 매핑합니다.
    static func visualWindSpeed(forMetersPerSecond value: Double) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(Float(value), 0) * 0.035, 0.65)
    }

    /// Expands the horizontal wind vector into world X/Z coordinates with no vertical movement.
    /// 수평 풍향 벡터를 수직 이동 없이 월드 X/Z 좌표로 확장합니다.
    static func emitterDirection(forMeteorologicalDegrees degrees: Double) -> SIMD3<Float> {
        let direction = windTravelDirection(forMeteorologicalDegrees: degrees)
        return SIMD3<Float>(direction.x, 0, direction.y)
    }

    /// Selects the particle field radius in meters using the visualization threshold.
    /// 시각화 임계값에 따라 미터 단위의 파티클 영역 반경을 선택합니다.
    static func dustFieldRadius(forPM25 value: Double) -> Float {
        value >= severePM25Threshold ? 3.25 : 2.85
    }
}
