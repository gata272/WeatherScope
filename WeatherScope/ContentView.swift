import SwiftUI

struct ContentView: View {
    @StateObject private var store = WeatherStore()

    var body: some View {
        NavigationStack {
            Form {
                searchSection
                presetsSection
                favoritesSection
                if store.isLoading && store.main == nil {
                    Section {
                        HStack {
                            ProgressView()
                            Text("複数の気象モデルから予報を取得中…")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                if !store.errorMessage.isEmpty {
                    Section {
                        Text(store.errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                if let main = store.main {
                    currentSection(main)
                    todaySection(main)
                    confidenceSection(main)
                    modelSection
                    hourlySection(main)
                    dailySection(main)
                    airSection
                    sourceSection(main)
                }
            }
            .navigationTitle("天気予報プロ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack {
                        Button {
                            store.toggleFavorite()
                        } label: {
                            Image(systemName: store.isFavorite ? "star.fill" : "star")
                        }
                        Button {
                            Task { await store.refresh() }
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .disabled(store.isLoading)
                    }
                }
            }
            .task {
                if store.main == nil { await store.refresh() }
            }
            .refreshable { await store.refresh() }
        }
    }

    // MARK: - 検索・お気に入り

    private var searchSection: some View {
        Section("場所を検索") {
            HStack {
                TextField("都市名（ローマ字推奨：Osaka、Kyoto）", text: $store.query)
                    .onSubmit { Task { await store.search() } }
                Button("検索") { Task { await store.search() } }
            }
            if !store.searchNote.isEmpty {
                Text(store.searchNote).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(store.searchResults) { p in
                Button {
                    Task { await store.select(p) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(p.name).foregroundStyle(.primary)
                            Text(p.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private var presetsSection: some View {
        Section("日本の主要都市") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presetCities) { city in
                        Button {
                            Task { await store.select(city) }
                        } label: {
                            Text(city.name)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var favoritesSection: some View {
        Group {
            if !store.favorites.isEmpty {
                Section("お気に入り") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.favorites) { fav in
                                Button {
                                    Task { await store.select(fav) }
                                } label: {
                                    Label(fav.name, systemImage: fav.id == store.place.id ? "mappin.circle.fill" : "mappin")
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }

    // MARK: - 現在の天気

    private func currentSection(_ main: ForecastResponse) -> some View {
        Section {
            if let cur = main.current {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(store.place.name).font(.title2.bold())
                        if !store.place.subtitle.isEmpty {
                            Text(store.place.subtitle).font(.caption).foregroundStyle(.secondary)
                        }
                        Text(weatherText(cur.weatherCode)).font(.subheadline)
                        Text("現地 \(clockText(cur.time)) 時点")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Image(systemName: weatherSymbol(cur.weatherCode, isDay: cur.isDay == 1))
                            .font(.system(size: 40))
                            .symbolRenderingMode(.multicolor)
                        Text("\(num(cur.temperature2m))°")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                        Text("体感 \(num(cur.apparentTemperature))°")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                let idx = currentHourIndex(main)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    DetailCell(symbol: "humidity.fill", label: "湿度", value: "\(num(cur.relativeHumidity2m))%")
                    DetailCell(symbol: "thermometer.medium", label: "露点", value: "\(num(at(main.hourly?.dewPoint2m, idx), digits: 1))℃")
                    DetailCell(symbol: "gauge.medium", label: "気圧", value: "\(num(cur.pressureMsl)) hPa")
                    DetailCell(symbol: "wind", label: "風", value: "\(compass(cur.windDirection10m)) \(num(cur.windSpeed10m, digits: 1)) km/h")
                    DetailCell(symbol: "tornado", label: "突風", value: "\(num(cur.windGusts10m, digits: 1)) km/h")
                    DetailCell(symbol: "cloud.fill", label: "雲量", value: "\(num(cur.cloudCover))%")
                    DetailCell(symbol: "eye.fill", label: "視程", value: visibilityText(at(main.hourly?.visibility, idx)))
                    DetailCell(symbol: "sun.max.fill", label: "UV指数（現在）", value: num(at(main.hourly?.uvIndex, idx), digits: 1))
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
            }
        } header: {
            Text("現在の天気（best_matchモデル）")
        }
    }

    private func visibilityText(_ meters: Double?) -> String {
        guard let m = meters else { return "—" }
        return String(format: "%.1f km", m / 1000)
    }

    // MARK: - 今日の概要

    private func todaySection(_ main: ForecastResponse) -> some View {
        Section("今日の概要") {
            if let d = main.daily {
                LabeledContent("最高 / 最低", value: "\(num(at(d.temperature2mMax, 0)))° / \(num(at(d.temperature2mMin, 0)))°")
                    .font(.subheadline)
                LabeledContent("降水確率（最大）", value: "\(num(at(d.precipitationProbabilityMax, 0)))%")
                    .font(.subheadline)
                LabeledContent("降水量（合計）", value: "\(num(at(d.precipitationSum, 0), digits: 1)) mm")
                    .font(.subheadline)
                LabeledContent("最大風速 / 突風", value: "\(num(at(d.windSpeed10mMax, 0), digits: 1)) / \(num(at(d.windGusts10mMax, 0), digits: 1)) km/h")
                    .font(.subheadline)
                LabeledContent("UV指数（最大）", value: num(at(d.uvIndexMax, 0), digits: 1))
                    .font(.subheadline)
                LabeledContent("日の出 / 日の入り", value: "\(clockText(at(d.sunrise, 0) ?? "")) / \(clockText(at(d.sunset, 0) ?? ""))")
                    .font(.subheadline)
            }
        }
    }

    // MARK: - モデルの一致度

    private func confidenceSection(_ main: ForecastResponse) -> some View {
        Section {
            let c = confidence(main: main)
            LabeledContent("予報の一致度", value: c.label)
                .font(.headline)
            Text(c.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("気温予報は \(store.models.count) モデルの中央値を採用しています。中央値は、1つのモデルだけを見るより外れ値に強く、一般に安定した予報になります。範囲（最低〜最高）が広い時間帯は、モデル間で意見が割れている＝不確実性が高い時間帯です。")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("なぜ複数のモデルを見るのか")
        }
    }

    private func confidence(main: ForecastResponse) -> (label: String, detail: String) {
        let cons = hourlyConsensus(main: main, models: store.models)
        let spreads = cons.compactMap { c -> Double? in
            guard let a = c.minTemp, let b = c.maxTemp else { return nil }
            return b - a
        }
        guard !spreads.isEmpty else { return ("—", "モデルデータが不足しています") }
        let avg = spreads.reduce(0, +) / Double(spreads.count)
        let t = String(format: "%.1f", avg)
        if avg < 1.5 {
            return ("高い", "今後24時間のモデル間の気温差は平均 \(t)℃。各モデルの予報がよく一致しています。")
        } else if avg < 3.0 {
            return ("中程度", "今後24時間のモデル間の気温差は平均 \(t)℃。おおむね一致していますが、時間帯によって差があります。")
        }
        return ("低め", "今後24時間のモデル間の気温差が平均 \(t)℃ と大きめ。予報が変わりやすい状況です。")
    }

    // MARK: - モデル別

    private var modelSection: some View {
        Section {
            LabeledContent("今日の中央値", value: "最高 \(num(dailyMedian(day: 0, max: true)))° / 最低 \(num(dailyMedian(day: 0, max: false)))°")
                .font(.subheadline.weight(.semibold))
            LabeledContent("明日の中央値", value: "最高 \(num(dailyMedian(day: 1, max: true)))° / 最低 \(num(dailyMedian(day: 1, max: false)))°")
                .font(.subheadline.weight(.semibold))
            ForEach(store.models, id: \.spec.id) { pair in
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(pair.spec.label).font(.subheadline)
                        Text(pair.spec.provider).font(.caption2).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("最高 \(num(at(pair.forecast.daily?.temperature2mMax, 0)))°")
                        .font(.subheadline)
                    Text("最低 \(num(at(pair.forecast.daily?.temperature2mMin, 0)))°")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("モデル別予報（今日）")
        } footer: {
            Text("メイン予報の best_match は、地点ごとに最適なモデル（日本では気象庁モデル等）を自動選択する統合予報です。下の各モデルと比較できます。")
        }
    }

    private func dailyMedian(day: Int, max isMax: Bool) -> Double? {
        let values = store.models.compactMap { pair -> Double? in
            isMax ? at(pair.forecast.daily?.temperature2mMax, day) : at(pair.forecast.daily?.temperature2mMin, day)
        }
        return median(values)
    }

    // MARK: - 時間別（中央値）

    private func hourlySection(_ main: ForecastResponse) -> some View {
        Section("時間別予報（モデル中央値・24時間）") {
            ForEach(hourlyConsensus(main: main, models: store.models)) { c in
                HStack {
                    Text(hourText(c.time))
                        .font(.subheadline)
                        .frame(width: 42, alignment: .leading)
                    Image(systemName: weatherSymbol(c.code))
                        .symbolRenderingMode(.multicolor)
                    Text("\(num(c.medianTemp))°")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 46, alignment: .trailing)
                    if let lo = c.minTemp, let hi = c.maxTemp {
                        Text("（\(num(lo))〜\(num(hi))）")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let pop = c.medianPop {
                        Label("\(Int(pop))%", systemImage: "drop.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    // MARK: - 日別

    private func dailySection(_ main: ForecastResponse) -> some View {
        Section("16日間予報（best_match）") {
            if let d = main.daily {
                ForEach(Array(d.time.enumerated()), id: \.offset) { i, date in
                    HStack {
                        Text(dayText(date))
                            .font(.subheadline)
                            .frame(width: 88, alignment: .leading)
                        Image(systemName: weatherSymbol(at(d.weatherCode, i)))
                            .symbolRenderingMode(.multicolor)
                        Text("\(num(at(d.temperature2mMin, i)))°")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("〜")
                            .foregroundStyle(.secondary)
                        Text("\(num(at(d.temperature2mMax, i)))°")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        if let pop = at(d.precipitationProbabilityMax, i) {
                            Label("\(Int(pop))%", systemImage: "drop.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                        if let sum = at(d.precipitationSum, i), sum > 0 {
                            Text("\(num(sum, digits: 1))mm")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 大気質

    private var airSection: some View {
        Group {
            if let aq = store.airQuality?.current {
                Section("大気質") {
                    LabeledContent("大気質指数（米国式）", value: "\(num(aq.usAqi))（\(aqiLabel(aq.usAqi))）")
                        .font(.subheadline)
                    LabeledContent("大気質指数（欧州式）", value: num(aq.europeanAqi))
                        .font(.subheadline)
                    LabeledContent("PM2.5", value: "\(num(aq.pm25, digits: 1)) µg/m³")
                        .font(.subheadline)
                    LabeledContent("PM10", value: "\(num(aq.pm10, digits: 1)) µg/m³")
                        .font(.subheadline)
                    LabeledContent("二酸化窒素", value: "\(num(aq.nitrogenDioxide, digits: 1)) µg/m³")
                        .font(.subheadline)
                    LabeledContent("オゾン", value: "\(num(aq.ozone, digits: 1)) µg/m³")
                        .font(.subheadline)
                }
            }
        }
    }

    // MARK: - データ情報

    private func sourceSection(_ main: ForecastResponse) -> some View {
        Section {
            if let fetchedAt = store.fetchedAt {
                LabeledContent("取得時刻", value: fetchedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
            }
            LabeledContent("タイムゾーン", value: main.timezone ?? store.place.timezone ?? "—")
                .font(.caption)
            LabeledContent("標高", value: "\(num(main.elevation)) m")
                .font(.caption)
            if !store.failedModels.isEmpty {
                Text("取得できなかったモデル: \(store.failedModels.joined(separator: "、"))")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            Text("データ: Open-Meteo（各国気象機関の数値予報モデルを集約）。降水確率は、確率を出すモデル（ECMWF/GFS/ICON/GEM/UKMO）の中央値です（気象庁・フランスモデルはこのAPIでは確率を出さないため、気温の中央値にのみ参加します）。予報は本質的に不確実で、特に数日先や降水の細部は変わります。警報・注意報は気象庁の公式情報を確認してください。")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("データソース")
        }
    }
}

private struct DetailCell: View {
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.medium)).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
