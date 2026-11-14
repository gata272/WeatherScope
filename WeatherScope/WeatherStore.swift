import Foundation

@MainActor
final class WeatherStore: ObservableObject {
    @Published var place: Place
    @Published var favorites: [Place]
    @Published var main: ForecastResponse?
    @Published var models: [(spec: ModelSpec, forecast: ForecastResponse)] = []
    @Published var failedModels: [String] = []
    @Published var airQuality: AirQualityResponse?
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var fetchedAt: Date?
    @Published var query = ""
    @Published var searchResults: [Place] = []
    @Published var searchNote = ""

    private let favKey = "weather.favorites"
    private let placeKey = "weather.lastPlace"

    static var tokyo: Place {
        Place(id: 1850147, name: "東京", latitude: 35.6895, longitude: 139.6917,
              elevation: 40, country: "日本", admin1: "東京都", timezone: "Asia/Tokyo")
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: placeKey),
           let p = try? JSONDecoder().decode(Place.self, from: data) {
            place = p
        } else {
            place = Self.tokyo
        }
        if let data = UserDefaults.standard.data(forKey: favKey),
           let f = try? JSONDecoder().decode([Place].self, from: data) {
            favorites = f
        } else {
            favorites = [Self.tokyo]
        }
    }

    var isFavorite: Bool { favorites.contains { $0.id == place.id } }

    func toggleFavorite() {
        if isFavorite {
            favorites.removeAll { $0.id == place.id }
        } else {
            favorites.append(place)
        }
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: favKey)
        }
    }

    func search() async {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        searchNote = ""
        do {
            searchResults = try await WeatherService.searchPlaces(q)
            if searchResults.isEmpty { searchNote = "見つかりませんでした" }
        } catch {
            searchNote = "検索に失敗: \(error.localizedDescription)"
        }
    }

    func select(_ p: Place) async {
        place = p
        searchResults = []
        query = ""
        if let data = try? JSONEncoder().encode(p) {
            UserDefaults.standard.set(data, forKey: placeKey)
        }
        await refresh()
    }

    func refresh() async {
        let p = place
        isLoading = true
        errorMessage = ""
        defer { isLoading = false }
        // メイン予報と各モデルを並行して取得する（片方が遅くても、もう片方で表示できるように）
        async let mainFetch = WeatherService.fetchMain(place: p)
        async let aqFetch = try? WeatherService.fetchAirQuality(place: p)
        var collected: [(ModelSpec, ForecastResponse)] = []
        var failed: [String] = []
        await withTaskGroup(of: (ModelSpec, ForecastResponse?).self) { group in
            for spec in modelSpecs {
                group.addTask { (spec, try? await WeatherService.fetchModel(place: p, model: spec.id)) }
            }
            for await (spec, fc) in group {
                if let fc { collected.append((spec, fc)) } else { failed.append(spec.label) }
            }
        }
        models = modelSpecs.compactMap { spec in collected.first { $0.0.id == spec.id } }
        failedModels = failed
        do {
            main = try await mainFetch
        } catch {
            // best_match がタイムアウト等で失敗したら、取得できたモデル（気象庁→ECMWFの順）で代用表示する
            let priority = ["jma_seamless", "ecmwf_ifs025", "gfs_seamless", "icon_seamless", "gem_seamless", "ukmo_seamless", "meteofrance_seamless"]
            let fallback = priority.compactMap { id in collected.first { $0.0.id == id } }.first
            if let fallback {
                main = fallback.forecast
                errorMessage = "\(p.name): メイン予報の取得に失敗したため、\(fallback.spec.label)の予報で代用しています（\(error.localizedDescription)）"
            } else {
                errorMessage = "\(p.name)の予報の取得に失敗: \(error.localizedDescription)"
            }
        }
        airQuality = await aqFetch
        if main != nil { fetchedAt = Date() }
    }
}
