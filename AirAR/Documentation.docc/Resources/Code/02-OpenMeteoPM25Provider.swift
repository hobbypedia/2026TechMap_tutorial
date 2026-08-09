var components = URLComponents(
    string: "https://air-quality-api.open-meteo.com/v1/air-quality"
)!
components.queryItems = [
    URLQueryItem(name: "latitude", value: String(latitude)),
    URLQueryItem(name: "longitude", value: String(longitude)),
    URLQueryItem(name: "current", value: "pm2_5"),
    URLQueryItem(name: "timezone", value: "auto")
]

let (data, response) = try await URLSession.shared.data(from: components.url!)
let decoded = try JSONDecoder().decode(PM25Response.self, from: data)
return decoded.current.pm25
