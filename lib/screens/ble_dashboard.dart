import 'dart:async';
import 'package:flutter/material.dart';

class BleDashboard extends StatefulWidget {
  const BleDashboard({super.key});

  @override
  State<BleDashboard> createState() => _BleDashboardState();
}

class _BleDashboardState extends State<BleDashboard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  bool _isScanning = false;
  bool _isConnected = false;
  String _connectionStatus = 'Disconnected';
  
  // Mock Devices
  final List<Map<String, dynamic>> _foundDevices = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startScan() {
    setState(() {
      _isScanning = true;
      _foundDevices.clear();
      _connectionStatus = 'Scanning nearby...';
    });
    _animationController.repeat();

    // Mock scanning process
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _foundDevices.add({
            'name': 'Smart Glove Left',
            'rssi': -65,
            'id': 'AA:BB:CC:11:22:33',
          });
        });
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _stopScan();
      }
    });
  }

  void _stopScan() {
    setState(() {
      _isScanning = false;
      _connectionStatus = _isConnected ? 'Connected' : 'Scan Complete';
    });
    _animationController.stop();
  }

  void _connectToDevice(Map<String, dynamic> device) {
    setState(() {
      _connectionStatus = 'Connecting...';
    });

    // Mock connection delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isConnected = true;
          _connectionStatus = 'Connected to ${device['name']}';
        });
      }
    });
  }

  void _disconnect() {
    setState(() {
      _isConnected = false;
      _connectionStatus = 'Disconnected';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // For gradient full screen effect if needed
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
            // 1. Radar / Status Section (Gradient Background)
            Container(
              height: 360, // Increased from 320 to prevent overflow
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF42A5F5)], // Tech Blue Gradient
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
                        // Radar Rings
                        if (_isScanning)
                          RotationTransition(
                            turns: _animationController,
                            child: Container(
                              width: 160, // Reduced from 200
                              height: 160, // Reduced from 200
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [Colors.white.withOpacity(0.0), Colors.white.withOpacity(0.2)],
                                  stops: const [0.5, 1.0],
                                ),
                              ),
                            ),
                          ),
                        // Static Ring
                        Container(
                          width: 110, // Reduced from 140
                          height: 110, // Reduced from 140
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                        ),
                        // Central Icon
                        Container(
                          width: 80, // Reduced from 100
                          height: 80, // Reduced from 100
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withOpacity(0.15),
                            boxShadow: [
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
              : _buildDeviceList(),
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
                  onPressed: _isScanning || _isConnected ? null : _startScan,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  child: Text(
                    _isScanning ? 'SCANNING...' : 'SCAN FOR DEVICES',
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

  Widget _buildDeviceList() {
    if (_foundDevices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.devices_other, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              _isScanning ? 'Searching frequency...' : 'No devices found',
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
        final device = _foundDevices[index];
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
              device['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text('ID: ${device['id']}', style: const TextStyle(fontSize: 12)),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.signal_cellular_alt, color: Colors.green, size: 20),
                Text('${device['rssi']} dBm', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
              ],
            ),
            onTap: () => _connectToDevice(device),
          ),
        );
      },
    );
  }

  Widget _buildConnectedDashboard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          _buildInfoCard(Icons.battery_charging_full, 'Battery Level', '85%', Colors.green),
          const SizedBox(height: 16),
          _buildInfoCard(Icons.bluetooth_audio, 'Signal Strength', '-65 dBm', Colors.blue),
          const SizedBox(height: 40), // Replaced Spacer with fixed space to allow scrolling
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

  Widget _buildInfoCard(IconData icon, String title, String value, Color color) {
    return Container(
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
        ],
      ),
    );
  }
}
