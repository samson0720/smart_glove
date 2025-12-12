import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/ble_service.dart';

class BleDashboard extends StatefulWidget {
  const BleDashboard({super.key});

  @override
  State<BleDashboard> createState() => _BleDashboardState();
}

class _BleDashboardState extends State<BleDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final BLEService _bleService = BLEService();
  StreamSubscription<List<ScanResult>>? _scanSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;

  List<ScanResult> _foundDevices = [];
  BluetoothDevice? _connectedDevice;
  bool _isConnecting = false;

  String get _connectionStatus {
    if (_connectedDevice != null) {
      return 'Connected to ${_connectedDevice!.platformName.isNotEmpty ? _connectedDevice!.platformName : _connectedDevice!.remoteId}';
    }
    if (_isConnecting) return 'Connecting...';
    if (FlutterBluePlus.isScanningNow) return 'Scanning nearby...';
    return 'Disconnected';
  }

  bool get _isConnected => _connectedDevice != null;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    // Listen to connection state changes
    _connectionStateSubscription = _bleService.connectionState.listen((state) {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          if (state == BluetoothConnectionState.connected) {
            _connectedDevice = _bleService.connectedDevice;
          } else {
            _connectedDevice = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scanSubscription?.cancel();
    _connectionStateSubscription?.cancel();
    _bleService.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }
    // iOS permissions are handled by the flutter_blue_plus package automatically
  }

  void _startScan() async {
    await _requestPermissions();

    if (await Permission.bluetoothScan.isDenied) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bluetooth scan permission is required to find devices.')),
        );
      }
      return;
    }

    setState(() {
      _foundDevices.clear();
    });
    _animationController.repeat();

    _scanSubscription = _bleService.startScan().listen((results) {
      if (mounted) {
        setState(() {
          // Filter out devices with no name and sort by RSSI
          _foundDevices = results.where((r) => r.device.platformName.isNotEmpty).toList();
          _foundDevices.sort((a, b) => b.rssi.compareTo(a.rssi));
        });
      }
    }, onDone: _stopScan);

    // Stop scan after 10 seconds
    Future.delayed(const Duration(seconds: 10), _stopScan);
  }

  void _stopScan() {
    _bleService.stopScan();
    if (mounted) {
      _animationController.stop();
      setState(() {}); // Update status text
    }
  }

  void _connectToDevice(BluetoothDevice device) {
    _stopScan();
    setState(() {
      _isConnecting = true;
    });
    _bleService.connectToDevice(device);
  }

  void _disconnect() {
    _bleService.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final isScanning = FlutterBluePlus.isScanningNow;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Device Connection'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
        ),
        child: Column(
          children: [
            // 1. Radar / Status Section
            Container(
              height: 360,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4)),
                ],
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isScanning)
                          RotationTransition(
                            turns: _animationController,
                            child: Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.2)],
                                  stops: const [0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                        ),
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: 2)
                            ],
                          ),
                          child: Icon(
                            _isConnected ? Icons.bluetooth_connected : Icons.bluetooth,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _connectionStatus,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // 2. Device List / Dashboard
            Expanded(
              child: _isConnected
                  ? _buildConnectedDashboard()
                  : _buildDeviceList(isScanning),
            ),

            // 3. Scan Button Area
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4)),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isScanning || _isConnected ? null : _startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: Text(
                    isScanning ? 'SCANNING...' : 'SCAN FOR DEVICES',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList(bool isScanning) {
    if (_foundDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              isScanning ? 'Searching for devices...' : 'No devices found',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 16),
      itemCount: _foundDevices.length,
      itemBuilder: (context, index) {
        final result = _foundDevices[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2)),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.watch_outlined, color: Colors.blue),
            ),
            title: Text(
              result.device.platformName,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text('ID: ${result.device.remoteId}', style: const TextStyle(fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.signal_cellular_alt, color: Colors.green, size: 20),
                Text('${result.rssi} dBm', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
            onTap: () => _connectToDevice(result.device),
          ),
        );
      },
    );
  }

  Widget _buildConnectedDashboard() {
    // Example: Send a command when a button is pressed
    void sendTestCommand() {
      _bleService.sendVibrateCommand(4); // "Approaching turn"
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sent "Approaching turn" command!')),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildInfoCard(Icons.bluetooth_audio, 'Signal Strength', 'Good', Colors.blue),
          const SizedBox(height: 16),
          _buildInfoCard(Icons.vibration, 'Test Vibration', 'Send Command', Colors.purple, onTap: sendTestCommand),
          const SizedBox(height: 40),
          OutlinedButton.icon(
            onPressed: _disconnect,
            icon: const Icon(Icons.bluetooth_disabled),
            label: const Text('DISCONNECT DEVICE'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(IconData icon, String title, String value, Color color, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              ],
            ),
            if (onTap != null) ...[
              const Spacer(),
              const Icon(Icons.touch_app, color: Colors.grey),
            ]
          ],
        ),
      ),
    );
  }
}
