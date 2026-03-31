# SmartGlove — 讓導航觸手可及

> **智慧型機車騎士觸覺導航系統**
>
> SmartGlove 是一套結合 Flutter 行動應用與 ESP32 穿戴裝置的全端導航系統，透過藍牙低功耗（BLE）將轉向指令轉化為震動觸覺回饋，讓騎士無需分心低頭看手機，即可安全感知路線指引，並即時偵測跌倒事故與測速照相。

---

## 目錄

- [專案目的](#專案目的)
- [核心功能](#核心功能)
- [系統架構](#系統架構)
- [技術棧](#技術棧)
- [外部 API 整合](#外部-api-整合)
- [硬體設計](#硬體設計)
- [BLE 通訊協定](#ble-通訊協定)
- [專案結構](#專案結構)
- [安裝與執行](#安裝與執行)
- [環境變數設定](#環境變數設定)

---

## 專案目的

機車是台灣最普遍的交通工具，然而騎乘途中查看導航地圖卻是重大事故隱患。SmartGlove 的目標是透過穿戴式觸覺介面，將「左轉」、「右轉」等導航指令編碼為手套上的震動訊號，讓騎士雙眼不離路面即可掌握路線。

系統同時整合**跌倒偵測**（加速度計）與**測速照相預警**（OpenStreetMap），提供完整的騎乘安全防護網。

---

## 核心功能

### 1. 觸覺導航回饋
- 輸入目的地後，後端呼叫 Google Directions API 計算逐轉路線。
- 系統持續比對 GPS 位置與前方轉彎點，於接近時透過 BLE 向 ESP32 發送震動指令。
- 左轉、右轉、直行各有對應的震動模式，無需視覺輔助即可直覺辨別。

### 2. 即時地圖導航
- 整合 Google Maps 顯示即時位置、路線多邊線與目的地標記。
- 支援 Google Places 地點搜尋與自動補全，快速設定目的地。
- 提供騎士專屬 HUD（Head-Up Display）介面，顯示車速與方位。

### 3. 跌倒偵測
- 持續監測手機加速度計，計算合力加速度（G 值）。
- 瞬間 G 值超過 15 m/s² 時觸發跌倒警示，並於畫面顯示警告覆蓋層。
- 設有 5 秒冷卻時間，避免路況顛簸造成誤觸發。

### 4. 測速照相預警
- 定期向 Overpass API 查詢周邊 2 km 內的測速照相機位置。
- 距離縮短至 500 m 以內時，地圖與安全覆蓋層即時顯示警告。
- 查詢結果本地快取，減少網路請求次數。

### 5. 藍牙裝置管理
- BLE 儀表板頁面可掃描、配對、連線 ESP32 手套裝置。
- 顯示連線狀態，支援重新連線與斷線操作。

---

## 系統架構

```
┌─────────────────────────────────────────────────────────────────┐
│                    Flutter App (前端)                            │
│                                                                 │
│  MapScreen ──┬── BLE Dashboard       (藍牙裝置管理)             │
│              ├── Safety Screen       (安全警示介面)             │
│              ├── Settings Screen     (偏好設定)                 │
│              ├── BikerHUD            (騎士抬頭顯示器)            │
│              └── GlobalSafetyOverlay (全域安全覆蓋層)           │
│                                                                 │
│  Services                                                       │
│  ├── BleService       ← BLE 指令傳送 / 連線管理                 │
│  └── SafetyService    ← 跌倒偵測 / 測速照相查詢                 │
│                                                                 │
│  感測器串流                                                       │
│  ├── Geolocator       ← GPS 位置（10m 距離過濾）                │
│  ├── FlutterCompass   ← 設備方位角                              │
│  └── SensorsPlus      ← 加速度計（跌倒偵測）                    │
└──────────────────────┬──────────────────────────────────────────┘
                       │  BLE (flutter_blue_plus)
┌──────────────────────▼──────────────────────────────────────────┐
│                    ESP32 智慧手套 (硬體)                          │
│                                                                 │
│  BLE Server (SmartGlove_BLE.ino)                                │
│  ├── 接收 1-byte 震動指令                                        │
│  ├── GPIO 25 → 右側震動馬達 (2N2222 驅動)                       │
│  └── GPIO 26 → 左側震動馬達 (2N2222 驅動)                       │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                    外部 API 服務                                  │
├─────────────────────────────────────────────────────────────────┤
│ Google Maps API       → 地圖渲染 / 標記 / 路線多邊線             │
│ Google Directions API → 逐轉路線計算 / 轉彎點提取               │
│ Google Places API     → 目的地搜尋 / 自動補全                   │
│ Overpass API          → 測速照相機位置（OpenStreetMap 資料）     │
└─────────────────────────────────────────────────────────────────┘
```

### 導航觸覺回饋資料流

```
使用者輸入目的地
    │
    ▼
Google Places API 自動補全
    │
    ▼
Google Directions API 取得路線
    │  JSON: legs → steps → maneuver + polyline
    ▼
解析轉彎點 (TurnPoint: lat/lng + 轉向類型)
    │
    ▼
GPS 串流持續更新位置
    │  距下一轉彎點 < 30m？
    ▼ YES
BleService.sendCommand(code)
    │  BLE GATT Characteristic Write
    ▼
ESP32 接收指令 → 驅動對應馬達震動
    │
    ▼
騎士感受觸覺回饋（左 / 右 / 直行）
```

### 安全偵測架構

```
加速度計串流 (SensorsPlus)
    │  合力 = √(x² + y² + z²)
    ▼
超過 15 m/s² 門檻值？
    │ YES（且冷卻期已過）
    ▼
跌倒事件觸發 → GlobalSafetyOverlay 警示

GPS 位置更新
    │  每隔固定距離觸發
    ▼
Overpass API 查詢周邊 2 km 測速照相
    │
    ▼
Haversine 公式計算各相機距離
    │  距離 < 500m？
    ▼ YES
SafetyScreen / 地圖標記顯示測速預警
```

---

## 技術棧

### 前端（Flutter / Dart）

| 套件 | 版本 | 用途 |
|------|------|------|
| `flutter` | ≥3.0.0 | 跨平台 UI 框架 |
| `google_maps_flutter` | ^2.14.0 | 地圖渲染與路線視覺化 |
| `flutter_polyline_points` | ^2.1.0 | Polyline 編解碼 |
| `geolocator` | ^14.0.2 | 即時 GPS 定位（10m 距離過濾） |
| `flutter_compass` | ^0.8.0 | 設備方位角感測 |
| `sensors_plus` | ^6.1.0 | 加速度計（跌倒偵測） |
| `flutter_blue_plus` | ^1.32.12 | BLE 裝置掃描、連線與資料傳輸 |
| `http` | ^1.6.0 | REST API 請求 |
| `permission_handler` | ^11.3.1 | 位置、藍牙等運行時權限管理 |
| `flutter_dotenv` | ^6.0.0 | 環境變數讀取（API 金鑰） |
| `url_launcher` | ^6.3.0 | 外部連結開啟 |

### 硬體韌體（Arduino / C++）

| 環境 | 說明 |
|------|------|
| Arduino IDE | ESP32 韌體編譯與燒錄 |
| `BLEDevice` / `BLEServer` | ESP32 Arduino BLE 函式庫 |
| GPIO 25 / 26 | 左右震動馬達輸出腳位 |

---

## 外部 API 整合

### Google Cloud Platform

| 服務 | 用途 | 計費 |
|------|------|------|
| Maps SDK for Android | 地圖底圖、標記、Polyline 渲染 | 依用量計費 |
| Directions API | 逐轉路線計算、轉彎點與距離提取 | 依請求計費 |
| Places API | 地點搜尋、Autocomplete | 依請求計費 |

### OpenStreetMap / Overpass API

| 服務 | 協定 | 用途 |
|------|------|------|
| Overpass API | HTTPS REST | 查詢周邊 2 km 測速照相機座標 |

Overpass 查詢範例（速度執法設備）：

```
[out:json];
node["highway"="speed_camera"](around:2000,{lat},{lng});
out body;
```

---

## 硬體設計

### ESP32 接線

| 腳位 | 連接 | 說明 |
|------|------|------|
| GPIO 25 | 2N2222 Base（右馬達電路） | 右轉震動馬達控制 |
| GPIO 26 | 2N2222 Base（左馬達電路） | 左轉震動馬達控制 |
| 3.3V / GND | 電源供應 | |

### 電路概念

```
ESP32 GPIO ──► 1kΩ 電阻 ──► 2N2222 Base
                              │
                         Collector ──► 震動馬達(+) ──► VCC
                              │
                           Emitter ──► GND
                              │
                      (馬達並聯 1N4148 飛輪二極體)
```

---

## BLE 通訊協定

ESP32 以 BLE GATT Server 運行，Flutter 透過 Characteristic Write 傳送單一位元組指令。

### 震動指令碼

| 指令碼 | 動作 | 震動時長 | 導航含義 |
|--------|------|---------|---------|
| `0` | 全部停止 | — | 無動作 |
| `1` | 右側馬達震動 | 500 ms | **右轉** |
| `2` | 左側馬達震動 | 500 ms | **左轉** |
| `3` | 雙側馬達震動 | 200 ms | **直行** |

### BLE 服務識別碼

| 項目 | UUID |
|------|------|
| Service UUID | `4fafc201-1fb5-459e-8fcc-c5c9c331914b` |
| Characteristic UUID | `beb5483e-36e1-4688-b7f5-ea07361b26a8` |

---

## 專案結構

```
smart_glove/
├── lib/
│   ├── main.dart                        # 應用入口、MapScreen（核心導航邏輯）
│   ├── models/
│   │   └── turn_point.dart              # 轉彎點資料模型（座標、轉向類型）
│   ├── screens/
│   │   ├── ble_dashboard.dart           # 藍牙裝置掃描與連線管理
│   │   ├── safety_screen.dart           # 安全警示與測速照相介面
│   │   └── settings_screen.dart         # 應用偏好設定
│   ├── services/
│   │   ├── ble_service.dart             # BLE 連線管理與震動指令傳送
│   │   └── safety_service.dart          # 跌倒偵測 & 測速照相查詢邏輯
│   ├── widgets/
│   │   ├── biker_hud.dart               # 騎士抬頭顯示器（車速、方位）
│   │   └── global_safety_overlay.dart   # 全域安全警示覆蓋層
│   └── utils/
│       └── map_style.dart               # Google Maps 自訂地圖樣式 JSON
├── esp32_reference/
│   └── SmartGlove_BLE.ino               # ESP32 韌體（BLE Server + 馬達控制）
├── android/                             # Android 原生建置設定
├── pubspec.yaml                         # Flutter 套件依賴宣告
├── pubspec.lock                         # 鎖定版本依賴
├── .env                                 # 環境變數（API 金鑰，不提交版控）
└── .gitignore
```

---

## 安裝與執行

### 前置需求

- Flutter SDK ≥ 3.0.0
- Android Studio 或 VS Code（含 Flutter 外掛）
- Android 裝置（需支援 Bluetooth 5.0 + GPS）
- Google Cloud 專案，並啟用 Maps、Directions、Places API
- Arduino IDE（若需燒錄 ESP32 韌體）

### Flutter 應用設定

```bash
# 1. 複製專案
git clone https://github.com/samson0720/smart_glove.git
cd smart_glove

# 2. 安裝 Flutter 依賴
flutter pub get

# 3. 設定環境變數（參見下方「環境變數設定」章節）
cp .env.example .env
# 編輯 .env 填入 Google Maps API 金鑰

# 4. 執行（需連接 Android 裝置）
flutter run

# 或建置 APK
flutter build apk --release
```

### ESP32 韌體燒錄

```
1. 以 Arduino IDE 開啟 esp32_reference/SmartGlove_BLE.ino
2. 安裝 ESP32 開發板支援（Board Manager → esp32 by Espressif）
3. 選擇對應的 ESP32 開發板型號與 COM Port
4. 點選「上傳」燒錄韌體
5. 開啟序列監視器（115200 baud）確認 BLE 服務啟動訊息
```

### 執行環境需求

- Android 裝置需開啟藍牙與位置服務
- 建議於戶外測試以確保 GPS 精度
- ESP32 手套需先完成配對，再從 BLE Dashboard 頁面連線

---

## 環境變數設定

在專案根目錄建立 `.env` 檔案：

```env
# Google Cloud Platform API 金鑰
GOOGLE_MAPS_API_KEY=your_google_maps_api_key_here
```

同時需更新 Android 原生設定：

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="your_google_maps_api_key_here"/>
```

> **注意**：`.env` 已列入 `.gitignore`，請勿將 API 金鑰提交至版本控制。

---

## 系統需求

| 項目 | 最低需求 |
|------|---------|
| Android 版本 | Android 6.0 (API 23) 以上 |
| 藍牙規格 | Bluetooth LE 4.0 以上 |
| 位置權限 | 精確位置（Fine Location） |
| 網路 | 導航與地圖載入需網路連線 |
