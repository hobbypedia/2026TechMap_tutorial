import XCTest
@testable import AirAR

final class AirQualityVisualizationMapperTests: XCTestCase {
    func testLowAndNegativePM25UseMinimumParticleBirthRate() {
        XCTAssertEqual(AirQualityVisualizationMapper.particleBirthRate(forPM25: 0), 30)
        XCTAssertEqual(AirQualityVisualizationMapper.particleBirthRate(forPM25: -20), 30)
    }

    func testSeverePM25RaisesAndCapsParticleBirthRate() {
        XCTAssertEqual(AirQualityVisualizationMapper.particleBirthRate(forPM25: 75), 90)
        XCTAssertEqual(AirQualityVisualizationMapper.particleBirthRate(forPM25: 76), 120)
        XCTAssertEqual(AirQualityVisualizationMapper.particleBirthRate(forPM25: 500), 180)
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

    func testSolarFlareOnlyAppearsWhenCameraFacesSun() {
        XCTAssertEqual(
            AirQualityVisualizationMapper.solarFlareIntensity(
                cameraForward: [0, 1, 0],
                directionToSun: [0, 1, 0]
            ),
            1,
            accuracy: 0.001
        )
        XCTAssertEqual(
            AirQualityVisualizationMapper.solarFlareIntensity(
                cameraForward: [0, 0, -1],
                directionToSun: [0, 1, 0]
            ),
            0,
            accuracy: 0.001
        )
    }

    func testSunVisibilityUsesSunriseAndSunset() {
        let sunrise = Date(timeIntervalSince1970: 100)
        let sunset = Date(timeIntervalSince1970: 200)
        let snapshot = AirQualitySnapshot(
            locationName: "테스트",
            measuredAt: "",
            temperature: 20,
            pm25: 10,
            uvIndex: 5,
            sunrise: sunrise,
            sunset: sunset
        )

        XCTAssertFalse(snapshot.isSunVisible(at: Date(timeIntervalSince1970: 99)))
        XCTAssertTrue(snapshot.isSunVisible(at: Date(timeIntervalSince1970: 100)))
        XCTAssertTrue(snapshot.isSunVisible(at: Date(timeIntervalSince1970: 199)))
        XCTAssertFalse(snapshot.isSunVisible(at: Date(timeIntervalSince1970: 200)))
    }

    func testSeverePM25UsesWiderEmitterField() {
        XCTAssertEqual(AirQualityVisualizationMapper.dustFieldRadius(forPM25: 75), 2.85)
        XCTAssertEqual(AirQualityVisualizationMapper.dustFieldRadius(forPM25: 76), 3.25)
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

    func testEmitterDirectionUsesHorizontalWorldVector() {
        let direction = AirQualityVisualizationMapper.emitterDirection(
            forMeteorologicalDegrees: 90
        )
        XCTAssertEqual(direction.x, -1, accuracy: 0.001)
        XCTAssertEqual(direction.y, 0, accuracy: 0.001)
        XCTAssertEqual(direction.z, 0, accuracy: 0.001)
    }
}
