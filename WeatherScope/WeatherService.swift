import Foundation

// MARK: - 場所

struct Place: Identifiable, Codable, Equatable {
    var id: Int
    var name: String
    var latitude: Double
    var longitude: Double
    var elevation: Double?
    var country: String?
    var admin1: String?
    var timezone: String?

    var subtitle: String {
        [admin1, country].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "・")
    }
}

struct GeocodingResponse: Decodable {
    let results: [Place]?
}

// MARK: - 予報レスポンス（Open-Meteo）

struct ForecastResponse: Decodable {
    let latitude: Double?
    let longitude: Double?
    let elevation: Double?
    let timezone: String?
    let current: Current?
    let hourly: Hourly?
    let daily: Daily?

    struct Current: Decodable {
        let time: String
        let temperature2m: Double?
        let relativeHumidity2m: Double?
        let apparentTemperature: Double?
        let isDay: Int?
        let precipitation: Double?
        let weatherCode: Int?
        let cloudCover: Double?
        let pressureMsl: Double?
        let windSpeed10m: Double?
        let windDirection10m: Double?
        let windGusts10m: Double?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case apparentTemperature = "apparent_temperature"
            case isDay = "is_day"
            case precipitation
            case weatherCode = "weather_code"
            case cloudCover = "cloud_cover"
            case pressureMsl = "pressure_msl"
            case windSpeed10m = "wind_speed_10m"
            case windDirection10m = "wind_direction_10m"
            case windGusts10m = "wind_gusts_10m"
        }
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature2m: [Double?]?
        let precipitationProbability: [Double?]?
        let precipitation: [Double?]?
        let weatherCode: [Int?]?
        let cloudCover: [Double?]?
        let windSpeed10m: [Double?]?
        let windGusts10m: [Double?]?
        let relativeHumidity2m: [Double?]?
        let dewPoint2m: [Double?]?
        let apparentTemperature: [Double?]?
        let pressureMsl: [Double?]?
        let visibility: [Double?]?
        let uvIndex: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2m = "temperature_2m"
            case precipitationProbability = "precipitation_probability"
            case precipitation
            case weatherCode = "weather_code"
            case cloudCover = "cloud_cover"
            case windSpeed10m = "wind_speed_10m"
            case windGusts10m = "wind_gusts_10m"
            case relativeHumidity2m = "relative_humidity_2m"
            case dewPoint2m = "dew_point_2m"
            case apparentTemperature = "apparent_temperature"
            case pressureMsl = "pressure_msl"
            case visibility
            case uvIndex = "uv_index"
        }
    }

    struct Daily: Decodable {
        let time: [String]
        let weatherCode: [Int?]?
        let temperature2mMax: [Double?]?
        let temperature2mMin: [Double?]?
        let sunrise: [String]?
        let sunset: [String]?
        let uvIndexMax: [Double?]?
        let precipitationSum: [Double?]?
        let precipitationProbabilityMax: [Double?]?
        let windSpeed10mMax: [Double?]?
        let windGusts10mMax: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case weatherCode = "weather_code"
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case sunrise, sunset
            case uvIndexMax = "uv_index_max"
            case precipitationSum = "precipitation_sum"
            case precipitationProbabilityMax = "precipitation_probability_max"
            case windSpeed10mMax = "wind_speed_10m_max"
            case windGusts10mMax = "wind_gusts_10m_max"
        }
    }
}

// MARK: - 大気質

struct AirQualityResponse: Decodable {
    let current: AQCurrent?

    struct AQCurrent: Decodable {
        let europeanAqi: Double?
        let usAqi: Double?
        let pm25: Double?
        let pm10: Double?
        let nitrogenDioxide: Double?
        let ozone: Double?

        enum CodingKeys: String, CodingKey {
            case europeanAqi = "european_aqi"
            case usAqi = "us_aqi"
            case pm25 = "pm2_5"
            case pm10
            case nitrogenDioxide = "nitrogen_dioxide"
            case ozone
        }
    }
}

// MARK: - モデル定義

struct ModelSpec: Identifiable {
    let id: String
    let label: String
    let provider: String
}

/// 比較に使う各国の数値予報モデル（best_match はメイン予報として別に取得）
let modelSpecs: [ModelSpec] = [
    ModelSpec(id: "ecmwf_ifs025", label: "ECMWF IFS", provider: "欧州中期予報センター"),
    ModelSpec(id: "gfs_seamless", label: "GFS", provider: "NOAA（米国）"),
    ModelSpec(id: "icon_seamless", label: "ICON", provider: "DWD（ドイツ気象局）"),
    ModelSpec(id: "jma_seamless", label: "JMA", provider: "気象庁（日本）"),
    ModelSpec(id: "gem_seamless", label: "GEM", provider: "カナダ気象庁"),
    ModelSpec(id: "ukmo_seamless", label: "UKMO", provider: "英国気象庁"),
    ModelSpec(id: "meteofrance_seamless", label: "ARPEGE", provider: "フランス気象庁"),
]

// MARK: - 日本の主要都市プリセット
// ジオコーディング検索は日本語名だとヒットが不安定なため（例：「大阪」は0件、「大阪市」は可）、
// 主要都市は座標つきで内蔵し、タップですぐ選べるようにする。IDは実在IDと衝突しない負数。
let presetCities: [Place] = [
    Place(id: -1, name: "札幌", latitude: 43.0618, longitude: 141.3545, elevation: 26, country: "日本", admin1: "北海道", timezone: "Asia/Tokyo"),
    Place(id: -2, name: "仙台", latitude: 38.2682, longitude: 140.8694, elevation: 55, country: "日本", admin1: "宮城県", timezone: "Asia/Tokyo"),
    Place(id: -3, name: "新潟", latitude: 37.9026, longitude: 139.0236, elevation: 5, country: "日本", admin1: "新潟県", timezone: "Asia/Tokyo"),
    Place(id: -4, name: "東京", latitude: 35.6895, longitude: 139.6917, elevation: 40, country: "日本", admin1: "東京都", timezone: "Asia/Tokyo"),
    Place(id: -5, name: "横浜", latitude: 35.4437, longitude: 139.6380, elevation: 28, country: "日本", admin1: "神奈川県", timezone: "Asia/Tokyo"),
    Place(id: -6, name: "金沢", latitude: 36.5947, longitude: 136.6256, elevation: 58, country: "日本", admin1: "石川県", timezone: "Asia/Tokyo"),
    Place(id: -7, name: "名古屋", latitude: 35.1815, longitude: 136.9066, elevation: 15, country: "日本", admin1: "愛知県", timezone: "Asia/Tokyo"),
    Place(id: -8, name: "京都", latitude: 35.0116, longitude: 135.7681, elevation: 55, country: "日本", admin1: "京都府", timezone: "Asia/Tokyo"),
    Place(id: -9, name: "大阪", latitude: 34.6937, longitude: 135.5023, elevation: 23, country: "日本", admin1: "大阪府", timezone: "Asia/Tokyo"),
    Place(id: -10, name: "神戸", latitude: 34.6901, longitude: 135.1956, elevation: 55, country: "日本", admin1: "兵庫県", timezone: "Asia/Tokyo"),
    Place(id: -11, name: "広島", latitude: 34.3853, longitude: 132.4553, elevation: 8, country: "日本", admin1: "広島県", timezone: "Asia/Tokyo"),
    Place(id: -12, name: "福岡", latitude: 33.5904, longitude: 130.4017, elevation: 18, country: "日本", admin1: "福岡県", timezone: "Asia/Tokyo"),
    Place(id: -13, name: "鹿児島", latitude: 31.5602, longitude: 130.5581, elevation: 30, country: "日本", admin1: "鹿児島県", timezone: "Asia/Tokyo"),
    Place(id: -14, name: "那覇", latitude: 26.2124, longitude: 127.6809, elevation: 39, country: "日本", admin1: "沖縄県", timezone: "Asia/Tokyo"),
]

// MARK: - API

enum WeatherError: LocalizedError {
    case http(Int)
    case decode(String)

    var errorDescription: String? {
        switch self {
        case .http(let code): return "サーバーエラー (HTTP \(code))"
        case .decode(let detail): return "データの解析に失敗しました: \(detail)"
        }
    }
}

enum WeatherService {
    private static func makeURL(_ base: String, _ params: [(String, String)]) -> URL {
        var c = URLComponents(string: base)!
        c.queryItems = params.map { URLQueryItem(name: $0.0, value: $0.1) }
        return c.url!
    }

    /// 専用セッション: 応答待ちを長めに取り、接続が不安定なときは接続完了まで待つ
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 180
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }()

    /// タイムアウト等の一次的な失敗は最大3回まで自動リトライする
    private static func get<T: Decodable>(_ url: URL) async throws -> T {
        var lastError: Error?
        for attempt in 0..<3 {
            if attempt > 0 {
                try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_500_000_000)
            }
            do {
                var req = URLRequest(url: url)
                req.timeoutInterval = 60
                let (data, response) = try await session.data(for: req)
                let code = (response as? HTTPURLResponse)?.statusCode ?? 0
                guard code == 200 else { throw WeatherError.http(code) }
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw WeatherError.decode(String(describing: error))
                }
            } catch let e as WeatherError {
                if case .decode = e { throw e }
                if case .http(let code) = e, code < 500 { throw e }
                lastError = e
            } catch {
                lastError = error
            }
        }
        throw lastError ?? WeatherError.http(0)
    }

    static func searchPlaces(_ query: String) async throws -> [Place] {
        let url = makeURL("https://geocoding-api.open-meteo.com/v1/search", [
            ("name", query), ("count", "10"), ("language", "ja"), ("format", "json"),
        ])
        let r: GeocodingResponse = try await get(url)
        return r.results ?? []
    }

    /// メイン予報（best_match: 地点ごとに最適なモデルを自動選択、16日分・全項目）
    static func fetchMain(place: Place) async throws -> ForecastResponse {
        let url = makeURL("https://api.open-meteo.com/v1/forecast", [
            ("latitude", "\(place.latitude)"), ("longitude", "\(place.longitude)"),
            ("current", "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
            ("hourly", "temperature_2m,precipitation_probability,precipitation,weather_code,cloud_cover,wind_speed_10m,wind_gusts_10m,relative_humidity_2m,dew_point_2m,apparent_temperature,pressure_msl,visibility,uv_index"),
            ("daily", "weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_sum,precipitation_probability_max,wind_speed_10m_max,wind_gusts_10m_max"),
            ("timezone", "auto"), ("forecast_days", "16"),
        ])
        return try await get(url)
    }

    /// モデル別予報（比較・中央値計算用、7日分・要点のみ）
    static func fetchModel(place: Place, model: String) async throws -> ForecastResponse {
        let url = makeURL("https://api.open-meteo.com/v1/forecast", [
            ("latitude", "\(place.latitude)"), ("longitude", "\(place.longitude)"),
            ("current", "temperature_2m,relative_humidity_2m,apparent_temperature,is_day,precipitation,weather_code,cloud_cover,pressure_msl,wind_speed_10m,wind_direction_10m,wind_gusts_10m"),
            ("hourly", "temperature_2m,precipitation_probability,precipitation"),
            ("daily", "temperature_2m_max,temperature_2m_min,precipitation_probability_max,precipitation_sum"),
            ("timezone", "auto"), ("forecast_days", "7"), ("models", model),
        ])
        return try await get(url)
    }

    static func fetchAirQuality(place: Place) async throws -> AirQualityResponse {
        let url = makeURL("https://air-quality-api.open-meteo.com/v1/air-quality", [
            ("latitude", "\(place.latitude)"), ("longitude", "\(place.longitude)"),
            ("current", "european_aqi,us_aqi,pm2_5,pm10,nitrogen_dioxide,ozone"),
            ("timezone", "auto"),
        ])
        return try await get(url)
    }
}

// MARK: - 集計ヘルパー

func at<T>(_ arr: [T?]?, _ i: Int) -> T? {
    guard let arr, i >= 0, i < arr.count else { return nil }
    return arr[i]
}

func median(_ values: [Double]) -> Double? {
    guard !values.isEmpty else { return nil }
    let s = values.sorted()
    let m = s.count / 2
    return s.count % 2 == 1 ? s[m] : (s[m - 1] + s[m]) / 2
}

struct HourConsensus: Identifiable {
    let time: String
    var id: String { time }
    let code: Int?
    let medianTemp: Double?
    let minTemp: Double?
    let maxTemp: Double?
    let medianPop: Double?
}

/// メイン予報の時刻軸に合わせ、各モデルの気温・降水確率の中央値と範囲を計算する
func hourlyConsensus(main: ForecastResponse,
                     models: [(spec: ModelSpec, forecast: ForecastResponse)],
                     count: Int = 24) -> [HourConsensus] {
    guard let hourly = main.hourly else { return [] }
    let nowPrefix = String((main.current?.time ?? "").prefix(13))
    let start = hourly.time.firstIndex { String($0.prefix(13)) == nowPrefix } ?? 0
    let indexMaps: [[String: Int]] = models.map { pair in
        Dictionary(uniqueKeysWithValues: (pair.forecast.hourly?.time ?? []).enumerated().map { ($0.element, $0.offset) })
    }
    var out: [HourConsensus] = []
    for i in start..<min(start + count, hourly.time.count) {
        let t = hourly.time[i]
        var temps: [Double] = []
        var pops: [Double] = []
        for (mi, pair) in models.enumerated() {
            guard let idx = indexMaps[mi][t], let h = pair.forecast.hourly else { continue }
            if let v = at(h.temperature2m, idx) { temps.append(v) }
            if let v = at(h.precipitationProbability, idx) { pops.append(v) }
        }
        out.append(HourConsensus(time: t, code: at(hourly.weatherCode, i),
                                 medianTemp: median(temps), minTemp: temps.min(), maxTemp: temps.max(),
                                 medianPop: median(pops)))
    }
    return out
}

/// 現在時刻に最も近い時間別インデックス
func currentHourIndex(_ f: ForecastResponse) -> Int {
    guard let hourly = f.hourly else { return 0 }
    let prefix = String((f.current?.time ?? "").prefix(13))
    return hourly.time.firstIndex { String($0.prefix(13)) == prefix } ?? 0
}

// MARK: - 表示ヘルパー

func num(_ v: Double?, digits: Int = 0) -> String {
    guard let v else { return "—" }
    return String(format: "%.\(digits)f", v)
}

func hourText(_ iso: String) -> String {
    let parts = iso.split(separator: "T")
    guard parts.count == 2 else { return iso }
    return String(parts[1].prefix(2)) + "時"
}

func clockText(_ iso: String) -> String {
    String(iso.suffix(5))
}

func dayText(_ date: String) -> String {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "ja_JP")
    f.timeZone = TimeZone(identifier: "UTC")
    f.dateFormat = "yyyy-MM-dd"
    guard let d = f.date(from: date) else { return date }
    f.dateFormat = "M/d（E）"
    return f.string(from: d)
}

func compass(_ deg: Double?) -> String {
    guard let deg else { return "" }
    let dirs = ["北", "北北東", "北東", "東北東", "東", "東南東", "南東", "南南東",
                "南", "南南西", "南西", "西南西", "西", "西北西", "北西", "北北西"]
    return dirs[Int((deg + 11.25) / 22.5) % 16]
}

func weatherText(_ code: Int?) -> String {
    switch code {
    case 0: return "快晴"
    case 1: return "晴れ"
    case 2: return "晴れ時々曇り"
    case 3: return "曇り"
    case 45, 48: return "霧"
    case 51: return "弱い霧雨"
    case 53: return "霧雨"
    case 55: return "強い霧雨"
    case 56, 57: return "着氷性の霧雨"
    case 61: return "弱い雨"
    case 63: return "雨"
    case 65: return "強い雨"
    case 66, 67: return "着氷性の雨"
    case 71: return "弱い雪"
    case 73: return "雪"
    case 75: return "強い雪"
    case 77: return "霧雪"
    case 80: return "弱いにわか雨"
    case 81: return "にわか雨"
    case 82: return "激しいにわか雨"
    case 85: return "弱いにわか雪"
    case 86: return "にわか雪"
    case 95: return "雷雨"
    case 96, 99: return "雹を伴う雷雨"
    default: return "—"
    }
}

func weatherSymbol(_ code: Int?, isDay: Bool = true) -> String {
    switch code {
    case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
    case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
    case 3: return "cloud.fill"
    case 45, 48: return "cloud.fog.fill"
    case 51, 53, 55: return "cloud.drizzle.fill"
    case 56, 57, 66, 67: return "cloud.sleet.fill"
    case 61, 80: return "cloud.rain.fill"
    case 63, 65, 81, 82: return "cloud.heavyrain.fill"
    case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
    case 95: return "cloud.bolt.rain.fill"
    case 96, 99: return "cloud.hail.fill"
    default: return "cloud.fill"
    }
}

func aqiLabel(_ usAqi: Double?) -> String {
    guard let v = usAqi else { return "—" }
    switch v {
    case ..<51: return "良い"
    case ..<101: return "普通"
    case ..<151: return "やや悪い"
    case ..<201: return "悪い"
    default: return "非常に悪い"
    }
}
