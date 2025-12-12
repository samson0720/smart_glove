# SmartGlove Navigation App 🚴‍♂️

一個專為機車騎士打造的 Flutter 導航 App，整合震動手套進行觸覺導航回饋。

## ✨ 核心功能

### 🗺️ 導航系統
- **Google Maps 整合** - 完整的地圖顯示與路線規劃
- **Google Directions API** - 精確的轉彎指令
- **智慧搜尋** - 支援地點自動完成與快速搜尋（加油站/便利商店/停車格）
- **3D 導航視角** - Google Maps 風格的跟隨與旋轉相機
- **Ultra Zoom** - 20級超近視野，路口細節一清二楚
- **自訂導航箭頭** - 大型藍色方向箭頭取代預設藍點

### 🧭 方向感測
- **Compass 整合** - 使用手機電子羅盤精確感知方向
- **智慧切換邏輯**：
  - 低速 (<5km/h)：使用電子羅盤，原地轉動也能即時反應
  - 高速 (>5km/h)：切換 GPS bearing，確保穩定導航

### 🚨 測速照相偵測
- **OpenStreetMap 整合** - 透過 Overpass API 取得測速點資料
- **即時警告** - 距離測速點 <500m 時顯示紅色警告框
- **距離顯示** - 實時顯示到測速點的距離（例如「測速照相 250m」）
- **Demo 模式** - 在目前位置北方 250m 設置假測速點測試

### 📳 BLE 震動手套整合
- **自動連接** - App 啟動時自動掃描並連接 "SmartGlove" 設備
- **轉彎震動提醒**：
  - 右轉 → 右手套震動 500ms
  - 左轉 → 左手套震動 500ms
  - 直行 → 雙手套短震 200ms
- **智慧觸發** - 距離轉彎點 <50m 時自動發送震動指令
- **防重複** - 確保每個轉彎只震動一次

### 🎨 UI/UX 優化
- **即時路況** - Google Maps 交通圖層
- **專業路線渲染** - 雙層 Polyline（深藍底 + 淺藍主線）
- **BikerHUD** - 機車專用抬頭顯示介面（速度/指令/距離）
- **相機鎖定** - Google Maps 風格的跟隨/解鎖機制
- **動態地圖邊距** - 確保控制元件不被 UI 遮擋

---

## 🛠️ 技術架構

### 使用套件
```yaml
dependencies:
  google_maps_flutter: ^2.14.0    # Google Maps
  geolocator: ^14.0.2             # GPS 定位
  flutter_compass: ^0.8.0         # 電子羅盤
  flutter_blue_plus: ^1.32.12     # BLE 通訊
  http: ^1.6.0                    # API 請求
  sensors_plus: ^6.1.0            # 加速度感測器（跌倒偵測）
```

### 主要服務
- **SafetyService** - 測速照相偵測與跌倒偵測
- **BLEService** - 藍牙手套通訊管理
- **TurnPoint Model** - 轉彎點資料結構

---

## 📦 安裝與設定

### 1. 環境需求
- Flutter SDK 3.0+
- Android Studio / VS Code
- Android 設備（實體機）
- Google Maps API Key（需啟用 Maps SDK、Directions API、Places API）

### 2. 安裝依賴
```bash
cd smart-glove-main
flutter pub get
```

### 3. 配置 API 金鑰（可選）
**注意**：專案中已包含 Google Maps API Key，可以直接使用。如果遇到 API 限制或想使用自己的金鑰，請：

1. 在 `lib/main.dart` 第 27 行修改 `GOOGLE_MAPS_API_KEY` 常數
2. 在 `android/app/src/main/AndroidManifest.xml` 第 40 行修改 `com.google.android.geo.API_KEY` 的值

### 4. 執行 App
```bash
flutter run
```

**⚠️ 重要提示**：如果 Google Maps API Key 達到使用限制，您需要：
- 前往 [Google Cloud Console](https://console.cloud.google.com/) 建立自己的 API Key
- 啟用以下服務：Maps SDK for Android、Directions API、Places API
- 更新上述兩個檔案中的 API Key

---

## 🎮 ESP32 震動手套設定

### 硬體需求
- ESP32 開發板
- 2x 震動馬達（左/右手套）
- 2x NPN 電晶體（例如 2N2222）
- 電阻、導線

### 電路接線
```
ESP32 GPIO 25 → 左手套震動馬達（透過電晶體）
ESP32 GPIO 26 → 右手套震動馬達（透過電晶體）
```

### Arduino 程式碼
參考 [`esp32_reference/SmartGlove_BLE.ino`](esp32_reference/SmartGlove_BLE.ino)

### BLE 通訊協定
- **Service UUID**: `4fafc201-1fb5-459e-8fcc-c5c9c331914b`
- **Characteristic UUID**: `beb5483e-36e1-4688-b7f5-ea07361b26a8`
- **設備名稱**: `SmartGlove`

---

## 🚀 使用方式

1. **開啟 App** - 自動獲取位置並掃描 BLE 設備
2. **搜尋目的地** - 使用搜尋框或快速搜尋按鈕
3. **開始導航** - 點擊「開始導航」
4. **享受震動引導** - 接近轉彎時手套會自動震動

### 特殊功能
- 📍 **點擊地圖** - 直接點擊任意位置設為目的地
- 📌 **回到目前位置** - 點擊右下角定位按鈕
- ⚡ **測速 Demo** - 點擊紅色閃電按鈕測試測速警告

---

## 🐛 疑難排解

### BLE 連接失敗
1. 確認 ESP32 已上傳程式且正在廣播
2. 確認藍牙已開啟且權限已授予
3. 檢查設備名稱是否為 "SmartGlove"

### GPS 定位不準
1. 確認位置權限已授予（精確位置）
2. 在戶外測試（室內 GPS 訊號弱）
3. 等待 GPS 冷啟動完成（約 30 秒）

### 測速照相無反應
1. 確認網路連線（需存取 Overpass API）
2. 查看 Console log 確認是否取得資料
3. 使用 Demo 模式測試功能

---

## 📝 授權

本專案僅供學習與研究使用。

## 🙏 致謝

- Google Maps Platform
- OpenStreetMap
- Flutter Community
