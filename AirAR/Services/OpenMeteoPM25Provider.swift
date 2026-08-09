import Foundation

/// Open-Meteo Air Quality API에서 가져온 현재 PM2.5 측정값입니다.
struct PM25Reading: Equatable, Sendable {
    let value: Double
    let measuredAt: String
    let sourceURL: URL
    let modelSourceURL: URL
}

protocol PM25Providing: Sendable {
    func currentPM25(latitude: Double, longitude: Double) async throws -> PM25Reading
}

enum PM25ProviderError: Error, Equatable {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case decodingFailed
    case networkFailed
}

/// PM2.5만 Open-Meteo REST API에서 가져옵니다. 기상 데이터는 요청하지 않습니다.
final class OpenMeteoPM25Provider: PM25Providing, @unchecked Sendable {
    private struct Response: Decodable {
        struct Current: Decodable {
            let time: String
            let pm25: Double

            enum CodingKeys: String, CodingKey {
                case time
                case pm25 = "pm2_5"
            }
        }

        let current: Current
    }

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    func currentPM25(latitude: Double, longitude: Double) async throws -> PM25Reading {
        do {
            guard var components = URLComponents(
                string: "https://air-quality-api.open-meteo.com/v1/air-quality"
            ) else {
                throw PM25ProviderError.invalidURL
            }
            components.queryItems = [
                URLQueryItem(name: "latitude", value: String(latitude)),
                URLQueryItem(name: "longitude", value: String(longitude)),
                URLQueryItem(name: "current", value: "pm2_5"),
                URLQueryItem(name: "timezone", value: "auto")
            ]
            guard let url = components.url else {
                throw PM25ProviderError.invalidURL
            }

            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw PM25ProviderError.invalidResponse
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                throw PM25ProviderError.httpError(httpResponse.statusCode)
            }

            let decoded: Response
            do {
                decoded = try decoder.decode(Response.self, from: data)
            } catch {
                throw PM25ProviderError.decodingFailed
            }

            return PM25Reading(
                value: decoded.current.pm25,
                measuredAt: decoded.current.time,
                sourceURL: URL(string: "https://open-meteo.com/en/docs/air-quality-api")!,
                modelSourceURL: URL(string: "https://atmosphere.copernicus.eu/")!
            )
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as PM25ProviderError {
            throw error
        } catch {
            throw PM25ProviderError.networkFailed
        }
    }
}
