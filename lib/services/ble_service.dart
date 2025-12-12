import 'dart:async';
import 'package:flutter/foundation.dart';
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
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  // Stream to notify UI about connection state changes
  final _connectionStateController = StreamController<BluetoothConnectionState>.broadcast();
  Stream<BluetoothConnectionState> get connectionState => _connectionStateController.stream;

  BluetoothDevice? get connectedDevice => _connectedDevice;
  bool get isConnected => _connectedDevice != null;

  /// Start scanning for BLE devices
  Stream<List<ScanResult>> startScan({int timeoutSeconds = 10}) {
    debugPrint('[BLE] Starting scan...');
    FlutterBluePlus.startScan(timeout: Duration(seconds: timeoutSeconds));
    return FlutterBluePlus.scanResults;
  }

  /// Stop scanning
  void stopScan() {
    debugPrint('[BLE] Stopping scan...');
    FlutterBluePlus.stopScan();
  }

  /// Connect to a device
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_connectedDevice != null) {
      debugPrint('[BLE] Already connected to a device. Disconnecting first.');
      await disconnect();
    }

    debugPrint('[BLE] Connecting to ${device.platformName}...');
    _connectionStateController.add(BluetoothConnectionState.connecting);

    try {
      // Cancel any previous connection subscription
      await _connectionStateSubscription?.cancel();
      
      // Listen to the connection state
      _connectionStateSubscription = device.connectionState.listen((state) async {
        _connectionStateController.add(state);
        if (state == BluetoothConnectionState.connected) {
          _connectedDevice = device;
          debugPrint('[BLE] ✅ Connected to ${device.platformName}');
          await _discoverServices();
        } else if (state == BluetoothConnectionState.disconnected) {
          debugPrint('[BLE] Disconnected from ${device.platformName}');
          _connectedDevice = null;
          _vibrateCharacteristic = null;
        }
      });

      await device.connect(timeout: const Duration(seconds: 15));

    } catch (e) {
      debugPrint('[BLE] Connection error: $e');
      _connectionStateController.add(BluetoothConnectionState.disconnected);
      disconnect(); // Clean up
    }
  }

  /// Discover services and characteristics for the connected device
  Future<void> _discoverServices() async {
    if (_connectedDevice == null) {
      debugPrint('[BLE] ⚠️ Cannot discover services, no device connected.');
      return;
    }

    debugPrint('[BLE] Discovering services...');
    try {
      List<BluetoothService> services = await _connectedDevice!.discoverServices();
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == SERVICE_UUID.toLowerCase()) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid.toString().toLowerCase() == CHARACTERISTIC_UUID.toLowerCase()) {
              _vibrateCharacteristic = characteristic;
              debugPrint('[BLE] ✅ Found vibrate characteristic!');
              return;
            }
          }
        }
      }
      debugPrint('[BLE] ⚠️ Vibrate characteristic not found');
    } catch (e) {
      debugPrint('[BLE] Service discovery error: $e');
    }
  }

  /// Send vibration command
  /// type: 1=右轉, 2=左轉, 3=直行, 0=停止, 4=即將轉彎
  Future<void> sendVibrateCommand(int type) async {
    if (_vibrateCharacteristic == null) {
      debugPrint('[BLE] ⚠️ Not connected or characteristic not found, cannot send command');
      return;
    }

    try {
      await _vibrateCharacteristic!.write([type], withoutResponse: true);
      
      String commandName = 'Unknown';
      const commands = {0: '停止', 1: '右轉', 2: '左轉', 3: '直行', 4: '即將轉彎'};
      commandName = commands[type] ?? 'Unknown';

      debugPrint('[BLE] 📳 Sent command: $commandName ($type)');
    } catch (e) {
      debugPrint('[BLE] Send error: $e');
    }
  }

  /// Disconnect from the current device
  Future<void> disconnect() async {
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    await _connectedDevice?.disconnect();
    _connectedDevice = null;
    _vibrateCharacteristic = null;
    _connectionStateController.add(BluetoothConnectionState.disconnected);
    debugPrint('[BLE] Disconnected');
  }

  /// Cleanup resources
  void dispose() {
    stopScan();
    disconnect();
    _connectionStateController.close();
    debugPrint('[BLE] Service disposed');
  }
}
