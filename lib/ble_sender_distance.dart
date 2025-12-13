import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

// ==========================================================
// ⚠️ 修正與設定參數 ⚠️
// ==========================================================

// 目標 ESP32 設備的地址
const String targetAddress = "EC:62:60:B7:85:B6";

// 傳送訊息(寫入)到 ESP32 時,應使用 ESP32 端的 TX 特性 UUID。
// 這裡假設您使用的是 Nordic UART Service (NUS) 的 TX UUID。
// const String serviceUuid = "02497b85-8226-4926-9c4a-ab8a69398eda";
// const String writeCharUuid = "02497b86-8226-4926-9c4a-ab8a69398eda";  // WRITE 特性
// const String notifyCharUuid = "02497b87-8226-4926-9c4a-ab8a69398eda"; // NOTIFY 特性 (如果需要接收數據)

// 常見的 Nordic UART Service (NUS) 設定
const String serviceUuid = "6E400001-B5A3-F393-E0A9-E50E24DCCA9E";

// 注意：手機的 Write 對應 ESP32 的 RX
const String writeCharUuid = "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"; 

// 注意：手機的 Notify 對應 ESP32 的 TX
const String notifyCharUuid = "6E400003-B5A3-F393-E0A9-E50E24DCCA9E";

// ==========================================================
// BLEService 類別 - 處理所有藍牙操作
// ==========================================================

class DistanceBLEService {

  static Future<void> sendAuto(int commandNumber) async {
    String messageToSend = commandNumber.toString();
    print("[AutoBLE] 🤖 準備自動發送指令: $messageToSend");

    try {
      // 1. 檢查藍牙狀態
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        print("[AutoBLE] ⚠️ 藍牙未開啟，取消發送");
        return;
      }

      // 2. 掃描特定設備 (設定 2 秒超時，求快)
      BluetoothDevice? targetDevice;
      print("[AutoBLE] 🔍 掃描中...");
      
      // 啟動掃描
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 2), // 自動模式時間縮短一點
        androidUsesFineLocation: true,
      );

      // 監聽掃描結果
      var scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          if (r.device.remoteId.toString().toUpperCase() == targetAddress.toUpperCase()) {
            targetDevice = r.device;
            print("[AutoBLE] ✅ 找到設備: ${r.device.remoteId}");
            FlutterBluePlus.stopScan(); // 找到就馬上停止掃描
          }
        }
      });

      // 等待掃描結束 (或手動停止)
      await Future.delayed(const Duration(seconds: 2));
      await scanSubscription.cancel();

      if (targetDevice == null) {
        print("[AutoBLE] ❌ 掃描超時，找不到設備 $targetAddress");
        return;
      }

      // 3. 連接
      print("[AutoBLE] 🔗 連接中...");
      await targetDevice!.connect(timeout: const Duration(seconds: 5));

      // 4. 發現服務與寫入
      print("[AutoBLE] 📂 尋找服務...");
      List<BluetoothService> services = await targetDevice!.discoverServices();
      
      BluetoothCharacteristic? writeCharacteristic;

      // 簡化的尋找邏輯 (直接找 UUID)
      for (var service in services) {
        if (service.uuid.toString().toLowerCase().contains(serviceUuid.toLowerCase().substring(4, 8))) {
           for (var char in service.characteristics) {
             if (char.uuid.toString().toLowerCase().contains(writeCharUuid.toLowerCase().substring(4, 8))) {
               writeCharacteristic = char;
               break;
             }
           }
        }
      }

      if (writeCharacteristic != null) {
        List<int> dataBytes = utf8.encode(messageToSend);
        
        // 寫入數據
        await writeCharacteristic.write(
          dataBytes,
          withoutResponse: writeCharacteristic.properties.writeWithoutResponse,
        );
        print("[AutoBLE] 📤 ✅ 成功發送指令: $messageToSend");
      } else {
        print("[AutoBLE] ❌ 找不到寫入特徵值");
      }

      // 5. 斷開連接 (自動模式通常發完就斷，省電)
      await targetDevice!.disconnect();
      print("[AutoBLE] 🔌 已斷線");

    } catch (e) {
      print("[AutoBLE] ❌ 發生錯誤: $e");
    }
  }

  static Future<String> sendBluetoothdistance(String messageToSend) async {
    StringBuffer log = StringBuffer();
    
    // 輔助函數：同時輸出到日誌和 terminal
    void logMessage(String message) {
      log.writeln(message);
      print(message);  // 輸出到 terminal
    }
    
    try {
      logMessage("1. 正在檢查藍牙狀態...");
      
      // 檢查藍牙是否開啟
      if (await FlutterBluePlus.isSupported == false) {
        logMessage("❌ 此設備不支援藍牙");
        return log.toString();
      }

      // 等待藍牙開啟
      var subscription = FlutterBluePlus.adapterState.listen((state) {
        logMessage("藍牙狀態: $state");
      });

      // 檢查當前藍牙狀態
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        logMessage("⚠️ 請開啟藍牙");
        // 在 Android 上可以嘗試開啟藍牙
        if (await FlutterBluePlus.isSupported) {
          await FlutterBluePlus.turnOn();
        }
        await subscription.cancel();
        return log.toString();
      }

      logMessage("2. 正在掃描藍牙設備...");
      
      BluetoothDevice? targetDevice;
      
      // 設定掃描監聽器
      var scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult r in results) {
          // 比對地址(不區分大小寫)
          if (r.device.remoteId.toString().toUpperCase() == 
              targetAddress.toUpperCase()) {
            targetDevice = r.device;
            logMessage("✅ 找到設備: ${r.device.platformName} (${r.device.remoteId})");
          }
        }
      });

      // 開始掃描(掃描 5 秒)
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 5),
        androidUsesFineLocation: true,
      );

      // 等待掃描完成
      await FlutterBluePlus.isScanning.where((val) => val == false).first;
      
      await scanSubscription.cancel();

      if (targetDevice == null) {
        logMessage("❌ 找不到地址為 $targetAddress 的設備。請確認設備已開啟且在廣播。");
        await subscription.cancel();
        return log.toString();
      }

      logMessage("3. 正在連接到設備...");
      
      // 連接到設備
      await targetDevice!.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );

      logMessage("✅ 成功連接到設備");

      // 監聽連接狀態
      targetDevice!.connectionState.listen((state) {
        logMessage("連接狀態: $state");
      });

      // 發現服務
      logMessage("4. 正在發現服務...");
      List<BluetoothService> services = await targetDevice!.discoverServices();

      // 列出所有服務和特性 (用於除錯)
      logMessage("\n=== 設備上所有可用的服務和特性 ===");
      for (var service in services) {
        logMessage("服務 UUID: ${service.uuid}");
        for (var char in service.characteristics) {
          List<String> properties = [];
          if (char.properties.read) properties.add("READ");
          if (char.properties.write) properties.add("WRITE");
          if (char.properties.writeWithoutResponse) properties.add("WRITE_NO_RESPONSE");
          if (char.properties.notify) properties.add("NOTIFY");
          if (char.properties.indicate) properties.add("INDICATE");
          
          logMessage("  └─ 特性 UUID: ${char.uuid}");
          logMessage("     屬性: ${properties.join(', ')}");
        }
      }
      logMessage("=====================================\n");

      BluetoothCharacteristic? writeCharacteristic;

      // 尋找目標特性 (不區分大小寫,且移除可能的 0000 前綴)
      for (var service in services) {
        String serviceUuidStr = service.uuid.toString().toLowerCase();
        String targetServiceUuid = serviceUuid.toLowerCase();
        
        // 移除可能的 0000 前綴和後綴,只比對核心部分
        String extractCore(String uuid) {
          // 提取 UUID 的核心部分 (例如: 6e400001)
          return uuid.replaceAll('-', '').substring(0, 8);
        }
        
        if (serviceUuidStr.contains(extractCore(targetServiceUuid)) || 
            serviceUuidStr == targetServiceUuid) {
          logMessage("✅ 找到目標服務: ${service.uuid}");
          
          for (BluetoothCharacteristic char in service.characteristics) {
            String charUuidStr = char.uuid.toString().toLowerCase();
            String targetCharUuid = writeCharUuid.toLowerCase();
            
            if (charUuidStr.contains(extractCore(targetCharUuid)) || 
                charUuidStr == targetCharUuid) {
              writeCharacteristic = char;
              logMessage("✅ 找到寫入特性: ${char.uuid}");
              logMessage("   特性屬性: WRITE=${char.properties.write}, WRITE_NO_RESPONSE=${char.properties.writeWithoutResponse}");
              break;
            }
          }
        }
      }

      if (writeCharacteristic == null) {
        logMessage("❌ 找不到寫入特性 UUID: $writeCharUuid");
        logMessage("提示: 請檢查上方列出的所有特性,確認正確的 UUID");
        await targetDevice!.disconnect();
        await subscription.cancel();
        return log.toString();
      }

      // 發送訊息
      logMessage("\n5. 嘗試發送訊息...");
      
      List<int> dataBytes = utf8.encode(messageToSend);
      
      // 根據特性的屬性選擇寫入方式
      bool withResponse = writeCharacteristic.properties.write;
      bool withoutResponse = writeCharacteristic.properties.writeWithoutResponse;
      
      logMessage("使用寫入模式: ${withResponse ? 'WITH_RESPONSE' : 'WITHOUT_RESPONSE'}");
      
      await writeCharacteristic.write(
        dataBytes,
        withoutResponse: !withResponse && withoutResponse, // 如果支援 write 就用 response,否則用 no response
      );

      logMessage("✅ 訊息發送成功！數據 '$messageToSend' 已發送到特性 $writeCharUuid");

      // 等待一下再斷開連接
      await Future.delayed(const Duration(seconds: 1));

      // 斷開連接
      logMessage("\n6. 正在斷開連接...");
      await targetDevice!.disconnect();
      logMessage("✅ 已斷開連接");

      await subscription.cancel();

    } catch (e) {
      logMessage("❌ 發生錯誤: $e");
      logMessage("請檢查：");
      logMessage("1. MAC 地址是否正確？");
      logMessage("2. Service 和 Characteristic UUID 是否正確？");
      logMessage("3. ESP32 是否在監聽？");
      logMessage("4. 是否已授予藍牙權限？");
    }
    
    return log.toString();
  }
}
