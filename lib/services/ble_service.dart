import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE Service for SmartGlove vibration control
class BLEService {
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;
  BLEService._internal();

  // BLE UUIDs
  static const String SERVICE_UUID = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  static const String CHARACTERISTIC_UUID = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _vibrateCharacteristic;
  StreamSubscription? _scanSubscription;

  bool get isConnected => _connectedDevice != null && _vibrateCharacteristic != null;

  /// Start scanning for SmartGlove device
  Future<void> startScan() async {
    print('[BLE] Starting scan...');
    
    // Cancel existing scan
    await FlutterBluePlus.stopScan();
    
    _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName.contains('SmartGlove')) {
          print('[BLE] Found SmartGlove: ${r.device.platformName}');
          _connectToDevice(r.device);
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));
  }

  /// Connect to the glove device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      print('[BLE] Connecting to ${device.platformName}...');
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      // Discover services
      List<BluetoothService> services = await device.discoverServices();
      
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              _vibrateCharacteristic = characteristic;
              print('[BLE] ✅ Connected and ready!');
              return;
            }
          }
        }
      }

      print('[BLE] ⚠️ Service/Characteristic not found');
    } catch (e) {
      print('[BLE] Connection error: $e');
    }
  }

  /// Send vibration command
  /// type: 1=右轉, 2=左轉, 3=直行, 0=停止, 4=即將轉彎
  Future<void> sendVibrateCommand(int type) async {
    if (_vibrateCharacteristic == null) {
      print('[BLE] ⚠️ Not connected, cannot send command');
      return;
    }

    try {
      await _vibrateCharacteristic!.write([type], withoutResponse: true);
      
      String commandName = ['停止', '右轉', '左轉', '直行', '即將轉彎'][type];
      print('[BLE] 📳 Sent command: $commandName ($type)');
    } catch (e) {
      print('[BLE] Send error: $e');
    }
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _vibrateCharacteristic = null;
    print('[BLE] Disconnected');
  }

  /// Cleanup
  void dispose() {
    _scanSubscription?.cancel();
    disconnect();
  }
}
