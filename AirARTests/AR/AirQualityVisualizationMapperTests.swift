import XCTest
@testable import AirAR

final class AirQualityVisualizationMapperTests: XCTestCase {
    func testLowAndNegativePM25UseMinimumDustBirthRate() {
        XCTAssertEqual(AirQualityVisualizationMapper.dustBirthRate(forPM25: 0), 35)
        XCTAssertEqual(AirQualityVisualizationMapper.dustBirthRate(forPM25: -20), 35)
        XCTAssertEqual(AirQualityVisualizationMapper.dustBirthRate(forPM25: .nan), 35)
    }

    func testSeverePM25RaisesAndCapsDustBirthRate() {
        XCTAssertEqual(AirQualityVisualizationMapper.dustBirthRate(forPM25: 75), 260)
        XCTAssertEqual(AirQualityVisualizationMapper.dustBirthRate(forPM25: 76), 320)
        XCTAssertEqual(AirQualityVisualizationMapper.dustBirthRate(forPM25: 500), 520)
    }

    func testDustOpacityRisesAndClampsWithPM25() {
        XCTAssertEqual(AirQualityVisualizationMapper.dustOpacity(forPM25: -1), 0.14, accuracy: 0.001)
        XCTAssertEqual(AirQualityVisualizationMapper.dustOpacity(forPM25: 76), 0.34, accuracy: 0.001)
        XCTAssertEqual(AirQualityVisualizationMapper.dustOpacity(forPM25: 500), 0.34, accuracy: 0.001)
        XCTAssertEqual(AirQualityVisualizationMapper.dustOpacity(forPM25: .nan), 0.14, accuracy: 0.001)
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

    func testSolarFlareAppearsOnlyWhenLookingTowardSun() {
        let direct = AirQualityVisualizationMapper.solarFlareIntensity(
            cameraForward: [0, 1, 0],
            directionToSun: [0, 4, 0]
        )
        let angled = AirQualityVisualizationMapper.solarFlareIntensity(
            cameraForward: [0, 0, -1],
            directionToSun: [0.31, 0, -0.95]
        )
        let side = AirQualityVisualizationMapper.solarFlareIntensity(
            cameraForward: [0, 0, -1],
            directionToSun: [1, 0, 0]
        )
        let behind = AirQualityVisualizationMapper.solarFlareIntensity(
            cameraForward: [0, 0, -1],
            directionToSun: [0, 0, 1]
        )

        XCTAssertEqual(direct, 1, accuracy: 0.001)
        XCTAssertGreaterThan(angled, 0)
        XCTAssertLessThan(angled, 1)
        XCTAssertEqual(side, 0, accuracy: 0.001)
        XCTAssertEqual(behind, 0, accuracy: 0.001)
    }

    func testSolarFlareRejectsInvalidDirections() {
        XCTAssertEqual(
            AirQualityVisualizationMapper.solarFlareIntensity(
                cameraForward: .zero,
                directionToSun: [0, 1, 0]
            ),
            0
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
}
