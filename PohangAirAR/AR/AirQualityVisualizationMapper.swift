import Foundation

/// 환경 수치를 RealityKit 도형의 개수와 크기로 변환하는 순수 계산 모음입니다.
enum AirQualityVisualizationMapper {
    static let severePM25Threshold = 76.0

    /// PM2.5가 심각 수준에 도달하면 입자 수를 급격히 늘려 화면을 더 채웁니다.
    /// - Important: 이 규칙은 교육용 시각화이며 공식 건강 기준이 아닙니다.
    static func particleCount(forPM25 value: Double) -> Int {
        let clampedValue = max(value, 0)
        if clampedValue >= severePM25Threshold {
            return min(240 + Int(((clampedValue - severePM25Threshold) * 1.2).rounded()), 360)
        }
        return min(max(Int((clampedValue * 4.0).rounded()), 20), 180)
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

    private static func normalized(_ value: UInt64) -> Float {
        Float(value % 10_000) / 9_999
    }
}
