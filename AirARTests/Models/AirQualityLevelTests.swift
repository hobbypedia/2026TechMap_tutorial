import XCTest
@testable import AirAR

final class AirQualityLevelTests: XCTestCase {
    func testPM25FiveLevelBoundaries() {
        XCTAssertEqual(AirQualityLevel.pm25(0), .veryGood)
        XCTAssertEqual(AirQualityLevel.pm25(7.9), .veryGood)
        XCTAssertEqual(AirQualityLevel.pm25(8), .good)
        XCTAssertEqual(AirQualityLevel.pm25(15.9), .good)
        XCTAssertEqual(AirQualityLevel.pm25(16), .moderate)
        XCTAssertEqual(AirQualityLevel.pm25(35.9), .moderate)
        XCTAssertEqual(AirQualityLevel.pm25(36), .bad)
        XCTAssertEqual(AirQualityLevel.pm25(75.9), .bad)
        XCTAssertEqual(AirQualityLevel.pm25(76), .veryBad)
    }

    func testUVIndexFiveLevelBoundaries() {
        XCTAssertEqual(AirQualityLevel.uvIndex(0), .veryGood)
        XCTAssertEqual(AirQualityLevel.uvIndex(2.9), .veryGood)
        XCTAssertEqual(AirQualityLevel.uvIndex(3), .good)
        XCTAssertEqual(AirQualityLevel.uvIndex(5.9), .good)
        XCTAssertEqual(AirQualityLevel.uvIndex(6), .moderate)
        XCTAssertEqual(AirQualityLevel.uvIndex(7.9), .moderate)
        XCTAssertEqual(AirQualityLevel.uvIndex(8), .bad)
        XCTAssertEqual(AirQualityLevel.uvIndex(10.9), .bad)
        XCTAssertEqual(AirQualityLevel.uvIndex(11), .veryBad)
    }

    func testLevelTitles() {
        XCTAssertEqual(AirQualityLevel.allCases.map(\.title), [
            "매우 좋음", "좋음", "보통", "나쁨", "매우 나쁨"
        ])
    }
}
