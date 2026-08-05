let airURL = try makeURL(
    base: "https://air-quality-api.open-meteo.com/v1/air-quality",
    current: "pm2_5,uv_index"
)
let weatherURL = try makeURL(
    base: "https://api.open-meteo.com/v1/forecast",
    current: "temperature_2m"
)

async let air: AirQualityAPIResponse = fetch(from: airURL)
async let weather: WeatherForecastAPIResponse = fetch(from: weatherURL)
let (airResponse, weatherResponse) = try await (air, weather)

return AirQualitySnapshot(
    locationName: "포항",
    measuredAt: airResponse.current.time,
    temperature: weatherResponse.current.temperature,
    pm25: airResponse.current.pm25,
    uvIndex: airResponse.current.uvIndex
)
