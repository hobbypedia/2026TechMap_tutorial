let endpoint = "https://api.open-meteo.com/v1/forecast"
var components = URLComponents(string: endpoint)!
components.queryItems = [
    URLQueryItem(name: "latitude", value: String(latitude)),
    URLQueryItem(name: "longitude", value: String(longitude)),
    URLQueryItem(
        name: "current",
        value: "temperature_2m,wind_speed_10m,wind_direction_10m"
    ),
    URLQueryItem(name: "daily", value: "sunrise,sunset"),
    URLQueryItem(name: "forecast_days", value: "1"),
    URLQueryItem(name: "wind_speed_unit", value: "ms"),
    URLQueryItem(name: "timezone", value: "auto")
]

let url = components.url!
// GET https://api.open-meteo.com/v1/forecast?latitude=...&longitude=...
