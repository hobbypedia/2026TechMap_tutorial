import Foundation
import simd

/// 4단계 체크포인트: PM2.5와 바람을 파티클 속성으로 변환합니다.
enum AirQualityVisualizationMapper {
    static let severePM25Threshold = 76.0
    static let particleLifeSpan: Double = 8

    static func particleBirthRate(forPM25 value: Double) -> Float {
        let clampedValue = max(value, 0)
        if clampedValue >= severePM25Threshold {
            return min(120 + Float(clampedValue - severePM25Threshold) * 0.6, 180)
        }
        return min(max(Float(clampedValue) * 2, 30), 90)
    }

    /// 기상 풍향은 바람이 불어오는 방향이므로 먼지 이동 방향은 180도 반대입니다.
    static func windTravelDirection(
        forMeteorologicalDegrees degrees: Double
    ) -> SIMD2<Float> {
        guard degrees.isFinite else { return .zero }
        let radians = Float(degrees * .pi / 180)
        return SIMD2<Float>(-sin(radians), cos(radians))
    }

    static func visualWindSpeed(forMetersPerSecond value: Double) -> Float {
        guard value.isFinite else { return 0 }
        return min(max(Float(value), 0) * 0.035, 0.65)
    }

    static func emitterDirection(
        forMeteorologicalDegrees degrees: Double
    ) -> SIMD3<Float> {
        let direction = windTravelDirection(forMeteorologicalDegrees: degrees)
        return SIMD3<Float>(direction.x, 0, direction.y)
    }

    static func dustFieldRadius(forPM25 value: Double) -> Float {
        value >= severePM25Threshold ? 3.25 : 2.85
    }
}
