import AppKit
import Observation

struct HourForecast: Identifiable, Equatable {
    let date: Date
    let temperature: Double
    let code: Int
    let isDay: Bool
    let rain: Int

    var id: Date { date }
}

struct WeatherSnapshot: Equatable {
    let city: String
    let temperature: Double
    let feelsLike: Double
    let code: Int
    let isDay: Bool
    let high: Double
    let low: Double
    let hours: [HourForecast]
    let timeZone: TimeZone
    let updated: Date
}

enum WeatherCondition {
    static func symbol(_ code: Int, isDay: Bool) -> String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1: return isDay ? "sun.max.fill" : "moon.fill"
        case 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57, 66, 67: return "cloud.sleet.fill"
        case 61, 63: return "cloud.rain.fill"
        case 65, 82: return "cloud.heavyrain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81: return isDay ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    static func text(_ code: Int) -> String {
        switch code {
        case 0: return "Céu limpo"
        case 1: return "Quase limpo"
        case 2: return "Parcialmente nublado"
        case 3: return "Nublado"
        case 45, 48: return "Neblina"
        case 51: return "Garoa fraca"
        case 53: return "Garoa"
        case 55: return "Garoa forte"
        case 56, 57: return "Garoa congelante"
        case 61: return "Chuva fraca"
        case 63: return "Chuva"
        case 65: return "Chuva forte"
        case 66, 67: return "Chuva congelante"
        case 71: return "Neve fraca"
        case 73: return "Neve"
        case 75: return "Neve forte"
        case 77: return "Grãos de neve"
        case 80: return "Pancadas fracas"
        case 81: return "Pancadas de chuva"
        case 82: return "Pancadas fortes"
        case 85, 86: return "Pancadas de neve"
        case 95: return "Trovoadas"
        case 96, 99: return "Trovoadas com granizo"
        default: return "—"
        }
    }
}

private struct Forecast: Decodable {
    struct Current: Decodable {
        let temperature_2m: Double?
        let apparent_temperature: Double?
        let weather_code: Double?
        let is_day: Double?
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature_2m: [Double?]
        let weather_code: [Double?]
        let precipitation_probability: [Double?]
        let is_day: [Double?]
    }

    struct Daily: Decodable {
        let temperature_2m_max: [Double?]
        let temperature_2m_min: [Double?]
    }

    let utc_offset_seconds: Int
    let current: Current
    let hourly: Hourly
    let daily: Daily
}

@MainActor
@Observable
final class WeatherService {
    struct Place: Equatable {
        let name: String
        let latitude: Double
        let longitude: Double
        let query: String?
    }

    nonisolated static let cityKey = "weatherCity"

    private(set) var snapshot: WeatherSnapshot?
    private(set) var isLoading = false
    private(set) var failed = false

    @ObservationIgnored private var place: Place?
    @ObservationIgnored private var placeDate: Date?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?

    func start() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard !SystemActivity.shared.paused else { return }
                self?.refresh()
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    func refreshIfStale() {
        guard let snapshot else {
            refresh()
            return
        }
        if Date().timeIntervalSince(snapshot.updated) > 900 {
            refresh()
        }
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        Task { [weak self] in
            await self?.load()
        }
    }

    private func load() async {
        defer { isLoading = false }
        do {
            let place = try await currentPlace()
            snapshot = try await Self.forecast(for: place)
            failed = false
        } catch {
            failed = true
        }
    }

    private func currentPlace() async throws -> Place {
        let stored = UserDefaults.standard.string(forKey: Self.cityKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let wanted = stored?.isEmpty == false ? stored : nil
        if let place, place.query == wanted, let placeDate, Date().timeIntervalSince(placeDate) < 6 * 3600 {
            return place
        }
        let next: Place
        if let wanted {
            next = try await Self.geocode(wanted)
        } else {
            next = try await Self.locateByIP()
        }
        place = next
        placeDate = Date()
        return next
    }

    nonisolated private static func geocode(_ name: String) async throws -> Place {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        components.queryItems = [
            URLQueryItem(name: "name", value: name),
            URLQueryItem(name: "count", value: "1"),
            URLQueryItem(name: "language", value: "pt"),
            URLQueryItem(name: "format", value: "json")
        ]
        let json = try await fetchJSON(components.url!)
        guard let first = (json["results"] as? [[String: Any]])?.first,
              let latitude = number(first["latitude"]),
              let longitude = number(first["longitude"]) else {
            throw URLError(.cannotParseResponse)
        }
        return Place(name: first["name"] as? String ?? name, latitude: latitude, longitude: longitude, query: name)
    }

    nonisolated private static func locateByIP() async throws -> Place {
        let endpoints = ["https://ipwho.is/", "https://ipapi.co/json/", "https://get.geojs.io/v1/ip/geo.json"]
        for endpoint in endpoints {
            guard let url = URL(string: endpoint), let json = try? await fetchJSON(url) else { continue }
            if let success = json["success"] as? Bool, !success { continue }
            if let latitude = number(json["latitude"]), let longitude = number(json["longitude"]) {
                return Place(name: json["city"] as? String ?? "Aqui", latitude: latitude, longitude: longitude, query: nil)
            }
        }
        throw URLError(.cannotFindHost)
    }

    nonisolated private static func forecast(for place: Place) async throws -> WeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code,is_day"),
            URLQueryItem(name: "hourly", value: "temperature_2m,weather_code,precipitation_probability,is_day"),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "2")
        ]
        let data = try await fetchData(components.url!)
        let forecast = try JSONDecoder().decode(Forecast.self, from: data)
        let zone = TimeZone(secondsFromGMT: forecast.utc_offset_seconds) ?? .current

        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = zone
        parser.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let hourly = forecast.hourly
        let earliest = Date().addingTimeInterval(-3600)
        var hours: [HourForecast] = []
        for index in hourly.time.indices where hours.count < 6 {
            guard let date = parser.date(from: hourly.time[index]), date > earliest,
                  index < hourly.temperature_2m.count,
                  let temperature = hourly.temperature_2m[index] else { continue }
            hours.append(HourForecast(
                date: date,
                temperature: temperature,
                code: Int(value(hourly.weather_code, index) ?? 3),
                isDay: (value(hourly.is_day, index) ?? 1) >= 1,
                rain: Int(value(hourly.precipitation_probability, index) ?? 0)
            ))
        }

        let current = forecast.current
        let temperature = current.temperature_2m ?? hours.first?.temperature ?? 0
        return WeatherSnapshot(
            city: place.name,
            temperature: temperature,
            feelsLike: current.apparent_temperature ?? temperature,
            code: Int(current.weather_code ?? 3),
            isDay: (current.is_day ?? 1) >= 1,
            high: forecast.daily.temperature_2m_max.first.flatMap { $0 } ?? temperature,
            low: forecast.daily.temperature_2m_min.first.flatMap { $0 } ?? temperature,
            hours: hours,
            timeZone: zone,
            updated: Date()
        )
    }

    nonisolated private static func value(_ array: [Double?], _ index: Int) -> Double? {
        index < array.count ? array[index] : nil
    }

    nonisolated private static func number(_ value: Any?) -> Double? {
        if let number = value as? NSNumber { return number.doubleValue }
        if let text = value as? String { return Double(text) }
        return nil
    }

    nonisolated private static func fetchData(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: 10)
        request.setValue("Notchy", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return data
    }

    nonisolated private static func fetchJSON(_ url: URL) async throws -> [String: Any] {
        let data = try await fetchData(url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }
        return json
    }
}
