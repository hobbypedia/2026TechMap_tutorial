import XCTest
@testable import PohangAirAR

final class AirQualityVisualizationMapperTests: XCTestCase {
    func testLowAndNegativePM25UseMinimumParticleCount() {
        XCTAssertEqual(AirQualityVisualizationMapper.particleCount(forPM25: 0), 20)
        XCTAssertEqual(AirQualityVisualizationMapper.particleCount(forPM25: -20), 20)
    }

    func testSeverePM25FillsMoreOfTheScreen() {
        XCTAssertEqual(AirQualityVisualizationMapper.particleCount(forPM25: 75), 180)
        XCTAssertEqual(AirQualityVisualizationMapper.particleCount(forPM25: 76), 240)
        XCTAssertEqual(AirQualityVisualizationMapper.particleCount(forPM25: 500), 360)
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
}
