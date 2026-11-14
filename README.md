# 天気予報プロ (WeatherScope)

複数の数値予報モデルを同時に読み込み、中央値とモデル間のばらつき（不確実性）まで見せる詳細天気予報アプリ。

## データソース（Open-Meteo、APIキー不要）
- メイン予報: best_match（地点ごとに最適モデルを自動選択）16日分・全項目
- モデル比較: ECMWF IFS / NOAA GFS / DWD ICON / 気象庁 JMA / GEM / UKMO / Météo-France ARPEGE の7モデルを並列取得
- 大気質: CAMS（米国式・欧州式AQI、PM2.5、PM10、NO2、O3）
- 場所検索: Open-Meteo Geocoding＋日本の主要都市14件を内蔵（日本語検索が不安定なため）

## 精度の考え方
- 時間別気温・降水確率は各モデルの「中央値」を表示し、あわせて最低〜最高の範囲を表示
- 範囲が広い時間帯はモデル間で意見が割れている＝不確実性が高い
- 気象庁・フランスモデルはこのAPIでは降水確率を出さないため、確率は確率を出す5モデルの中央値

## ビルド
GitHub Actions（macos-26 / 署名なしIPA）。GHアップローダでZIPを上げてビルドし、IPAをLiveContainerへ。
