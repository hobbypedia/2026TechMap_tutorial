let airURL = try makeURL(
    base: "https://air-quality-api.open-meteo.com/v1/air-quality",
    current: "pm2_5,uv_index"
)
let weatherURL = try makeURL(
    base: "https://api.open-meteo.com/v1/forecast",
    current: "temperature_2m,wind_speed_10m,wind_direction_10m",
    daily: "sunrise,sunset",
    forecastDays: 1
)

async let air: AirQualityAPIResponse = fetch(from: airURL)
async let weather: WeatherForecastAPIResponse = fetch(from: weatherURL)
let (airResponse, weatherResponse) = try await (air, weather)

return AirQualitySnapshot(
    locationName: "현재 위치",
    measuredAt: airResponse.current.time,
    temperature: weatherResponse.current.temperature,
    pm25: airResponse.current.pm25,
    uvIndex: airResponse.current.uvIndex,
    windSpeed: weatherResponse.current.windSpeed,
    windDirection: weatherResponse.current.windDirection,
    sunrise: parseLocalTime(weatherResponse.daily.sunrise[0]),
    sunset: parseLocalTime(weatherResponse.daily.sunset[0])
)
