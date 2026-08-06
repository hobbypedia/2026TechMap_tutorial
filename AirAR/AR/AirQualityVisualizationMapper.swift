import Foundation
import simd

/// 환경 수치를 RealityKit 도형의 개수와 크기로 변환하는 순수 계산 모음입니다.
enum AirQualityVisualizationMapper {
    static let severePM25Threshold = 76.0
    /// 기존 지름의 절반으로 줄이고 입자 수를 4배로 늘리면 총 투영 면적은 비슷하게 유지됩니다.
    static let particleLinearScale: Float = 0.5
    static let particleDensityMultiplier = 4

    /// PM2.5가 심각 수준에 도달하면 입자 수를 급격히 늘려 화면을 더 채웁니다.
    /// - Important: 이 규칙은 교육용 시각화이며 공식 건강 기준이 아닙니다.
    static func particleCount(forPM25 value: Double) -> Int {
        let clampedValue = max(value, 0)
        if clampedValue >= severePM25Threshold {
            let originalCount = min(
                240 + Int(((clampedValue - severePM25Threshold) * 1.2).rounded()),
                360
            )
            return originalCount * particleDensityMultiplier
        }
        let originalCount = min(max(Int((clampedValue * 4.0).rounded()), 20), 180)
        return originalCount * particleDensityMultiplier
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

    /// 같은 데이터에 항상 같은 입자 위치가 나오도록 결정론적인 좌표를 만듭니다.
    static func particlePosition(index: Int, pm25: Double) -> SIMD3<Float> {
        let seed = UInt64(max(0, Int((pm25 * 10).rounded()))) &+ UInt64(index * 1_103)
        let x = normalized(seed &* 1_664_525 &+ 1_013_904_223)
        let y = normalized(seed &* 22_695_477 &+ 1)
        let z = normalized(seed &* 1_103_515_245 &+ 12_345)
        let isSevere = pm25 >= severePM25Threshold
        let azimuth = x * 2 * Float.pi
        let radius = (isSevere ? 0.4 : 0.45) + z * (isSevere ? 2.8 : 2.35)
        let verticalRange: Float = isSevere ? 1.8 : 1.4
        return SIMD3<Float>(
            cos(azimuth) * radius,
            (y - 0.5) * verticalRange,
            sin(azimuth) * radius
        )
    }

    /// 실제 거리 원근감에 더해 가까운 입자는 조금 키우고 먼 입자는 줄입니다.
    static func perspectiveScale(for position: SIMD3<Float>) -> Float {
        let radialDistance = hypot(position.x, position.z)
        return min(max(1.35 - radialDistance * 0.22, 0.68), 1.22)
    }

    /// 카메라와 가까운 입자는 빠르게, 먼 입자는 느리게 움직이도록 속도 배율을 계산합니다.
    static func animationSpeed(forDistance distance: Float, variation: Float) -> Float {
        let clampedDistance = min(max(distance, 0.35), 3.5)
        let proximity = 1 - (clampedDistance - 0.35) / (3.5 - 0.35)
        let depthSpeed = 0.38 + proximity * 1.32
        return depthSpeed * min(max(variation, 0.8), 1.2)
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

    /// 원형 먼지 영역 안에서 바람 방향으로 이동시키고 경계를 넘으면 반대편으로 순환시킵니다.
    static func windDisplacedPosition(
        base: SIMD3<Float>,
        travelDistance: Float,
        direction: SIMD2<Float>,
        fieldRadius: Float
    ) -> SIMD3<Float> {
        let directionLengthSquared = simd_length_squared(direction)
        guard directionLengthSquared > 0.0001, fieldRadius > 0 else { return base }

        let normalizedDirection = direction / sqrt(directionLengthSquared)
        let perpendicular = SIMD2<Float>(-normalizedDirection.y, normalizedDirection.x)
        let baseXZ = SIMD2<Float>(base.x, base.z)
        let crosswindOffset = simd_dot(baseXZ, perpendicular)
        let halfPath = sqrt(max(fieldRadius * fieldRadius - crosswindOffset * crosswindOffset, 0.04))
        let pathLength = halfPath * 2
        var alongWind = (simd_dot(baseXZ, normalizedDirection) + travelDistance + halfPath)
            .truncatingRemainder(dividingBy: pathLength)
        if alongWind < 0 {
            alongWind += pathLength
        }
        alongWind -= halfPath

        let displacedXZ = normalizedDirection * alongWind + perpendicular * crosswindOffset
        return SIMD3<Float>(displacedXZ.x, base.y, displacedXZ.y)
    }

    static func dustFieldRadius(forPM25 value: Double) -> Float {
        value >= severePM25Threshold ? 3.25 : 2.85
    }

    private static func normalized(_ value: UInt64) -> Float {
        Float(value % 10_000) / 9_999
    }
}
