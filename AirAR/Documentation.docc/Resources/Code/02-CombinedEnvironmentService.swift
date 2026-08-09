async let weather = weatherProvider.currentConditions(
    latitude: latitude,
    longitude: longitude
)
async let pm25 = pm25Provider.currentPM25(
    latitude: latitude,
    longitude: longitude
)
let (conditions, pm25Reading) = try await (weather, pm25)

return AirQualitySnapshot(
    locationName: "현재 위치",
    measuredAt: conditions.measuredAt.ISO8601Format(),
    temperature: conditions.temperature,
    pm25: pm25Reading.value,
    uvIndex: conditions.uvIndex,
    windSpeed: conditions.windSpeed,
    windDirection: conditions.windDirection
)
