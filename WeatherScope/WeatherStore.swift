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
        do {
            main = try await WeatherService.fetchMain(place: p)
        } catch {
            errorMessage = "予報の取得に失敗: \(error.localizedDescription)"
            return
        }
        async let aq = try? WeatherService.fetchAirQuality(place: p)
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
        airQuality = await aq
        fetchedAt = Date()
    }
}
