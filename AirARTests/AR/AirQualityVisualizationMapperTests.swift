import XCTest
@testable import AirAR

final class AirQualityVisualizationMapperTests: XCTestCase {
    func testLowAndNegativePM25UseMinimumParticleCount() {
        XCTAssertEqual(AirQualityVisualizationMapper.particleCount(forPM25: 0), 80)
        XCTAssertEqual(AirQualityVisualizationMapper.particleCount(forPM25: -20), 80)
    }

    func testSeverePM25FillsMoreOfTheScreen() {
        XCTAssertEqual(AirQualityVisualizationMapper.particleCount(forPM25: 75), 720)
        XCTAssertEqual(AirQualityVisualizationMapper.particleCount(forPM25: 76), 960)
        XCTAssertEqual(AirQualityVisualizationMapper.particleCount(forPM25: 500), 1_440)
        XCTAssertNotEqual(
            AirQualityVisualizationMapper.particlePosition(index: 7, pm25: 75),
            AirQualityVisualizationMapper.particlePosition(index: 7, pm25: 76)
        )
    }

    func testUVNormalizationClampsRange() {
        XCTAssertEqual(AirQualityVisualizationMapper.normalizedUV(for: 0), 0)
        XCTAssertEqual(AirQualityVisualizationMapper.normalizedUV(for: 11), 1)
        XCTAssertEqual(AirQualityVisualizationMapper.normalizedUV(for: 20), 1)
        XCTAssertEqual(AirQualityVisualizationMapper.normalizedUV(for: -1), 0)
    }

    func testUVOpacityStartsLowAndRisesWithIntensity() {
        XCTAssertEqual(AirQualityVisualizationMapper.uvOpacity(for: 0), 0.06, accuracy: 0.001)
        XCTAssertEqual(AirQualityVisualizationMapper.uvOpacity(for: 11), 0.42, accuracy: 0.001)
        XCTAssertGreaterThan(
            AirQualityVisualizationMapper.uvOpacity(for: 8),
            AirQualityVisualizationMapper.uvOpacity(for: 2)
        )
    }

    func testDustPositionsSurroundTheViewer() {
        let positions = (0..<180).map { index in
            AirQualityVisualizationMapper.particlePosition(index: index, pm25: 40)
        }
        XCTAssertTrue(positions.contains { position in position.x > 0 && position.z > 0 })
        XCTAssertTrue(positions.contains { position in position.x > 0 && position.z < 0 })
        XCTAssertTrue(positions.contains { position in position.x < 0 && position.z > 0 })
        XCTAssertTrue(positions.contains { position in position.x < 0 && position.z < 0 })
    }

    func testPerspectiveScaleMakesNearDustLargerThanFarDust() {
        let near = AirQualityVisualizationMapper.perspectiveScale(for: [0.45, 0, 0])
        let far = AirQualityVisualizationMapper.perspectiveScale(for: [2.8, 0, 0])
        XCTAssertGreaterThan(near, far)
        XCTAssertEqual(near, 1.22, accuracy: 0.001)
        XCTAssertLessThan(far, 0.75)
    }

    func testDustFieldUsesMultipleDepthLayers() {
        let distances = (0..<180).map { index in
            let position = AirQualityVisualizationMapper.particlePosition(index: index, pm25: 40)
            return hypot(position.x, position.z)
        }
        XCTAssertLessThan(distances.min() ?? .infinity, 0.8)
        XCTAssertGreaterThan(distances.max() ?? 0, 2.4)
    }

    func testSameDataProducesSameParticlePosition() {
        XCTAssertEqual(
            AirQualityVisualizationMapper.particlePosition(index: 7, pm25: 13.2),
            AirQualityVisualizationMapper.particlePosition(index: 7, pm25: 13.2)
        )
    }

    func testSmallerParticlesKeepSimilarTotalProjectedArea() {
        let scale = AirQualityVisualizationMapper.particleLinearScale
        let density = Float(AirQualityVisualizationMapper.particleDensityMultiplier)
        XCTAssertEqual(scale, 0.5)
        XCTAssertEqual(scale * scale * density, 1, accuracy: 0.001)
    }

    func testNearDustMovesFasterAndParticlesHaveSpeedVariation() {
        let near = AirQualityVisualizationMapper.animationSpeed(forDistance: 0.5, variation: 1)
        let far = AirQualityVisualizationMapper.animationSpeed(forDistance: 3.2, variation: 1)
        XCTAssertGreaterThan(near, far)
        XCTAssertGreaterThan(
            AirQualityVisualizationMapper.animationSpeed(forDistance: 1.5, variation: 1.2),
            AirQualityVisualizationMapper.animationSpeed(forDistance: 1.5, variation: 0.8)
        )
    }

    func testMeteorologicalWindDirectionConvertsToDustTravelDirection() {
        let northWind = AirQualityVisualizationMapper.windTravelDirection(
            forMeteorologicalDegrees: 0
        )
        XCTAssertEqual(northWind.x, 0, accuracy: 0.001)
        XCTAssertEqual(northWind.y, 1, accuracy: 0.001)

        let eastWind = AirQualityVisualizationMapper.windTravelDirection(
            forMeteorologicalDegrees: 90
        )
        XCTAssertEqual(eastWind.x, -1, accuracy: 0.001)
        XCTAssertEqual(eastWind.y, 0, accuracy: 0.001)

        let southWind = AirQualityVisualizationMapper.windTravelDirection(
            forMeteorologicalDegrees: 180
        )
        XCTAssertEqual(southWind.x, 0, accuracy: 0.001)
        XCTAssertEqual(southWind.y, -1, accuracy: 0.001)
    }

    func testWindSpeedMapsToBoundedVisualSpeed() {
        XCTAssertEqual(
            AirQualityVisualizationMapper.visualWindSpeed(forMetersPerSecond: 0),
            0
        )
        XCTAssertEqual(
            AirQualityVisualizationMapper.visualWindSpeed(forMetersPerSecond: 10),
            0.35,
            accuracy: 0.001
        )
        XCTAssertEqual(
            AirQualityVisualizationMapper.visualWindSpeed(forMetersPerSecond: 100),
            0.65,
            accuracy: 0.001
        )
    }

    func testWindDisplacementMovesAndWrapsInsideDustField() {
        let south = SIMD2<Float>(0, 1)
        let moved = AirQualityVisualizationMapper.windDisplacedPosition(
            base: [1, 0.2, 0],
            travelDistance: 0.5,
            direction: south,
            fieldRadius: 2.85
        )
        XCTAssertEqual(moved.x, 1, accuracy: 0.001)
        XCTAssertEqual(moved.y, 0.2, accuracy: 0.001)
        XCTAssertEqual(moved.z, 0.5, accuracy: 0.001)

        let wrapped = AirQualityVisualizationMapper.windDisplacedPosition(
            base: [0, 0, 2.8],
            travelDistance: 0.1,
            direction: south,
            fieldRadius: 2.85
        )
        XCTAssertLessThan(wrapped.z, -2.7)
        XCTAssertLessThanOrEqual(hypot(wrapped.x, wrapped.z), 2.85)
    }
}
