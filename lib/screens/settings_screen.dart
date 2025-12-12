import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SettingsScreen extends StatefulWidget {
  final MapType currentMapType;
  final Function(MapType) onMapTypeChanged;
  final bool isNightMode;
  final Function(bool) onNightModeChanged;

  const SettingsScreen({
    super.key,
    required this.currentMapType,
    required this.onMapTypeChanged,
    required this.isNightMode,
    required this.onNightModeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late MapType _selectedMapType;
  late bool _isNightMode;
  bool _voiceGuidance = true;
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _selectedMapType = widget.currentMapType;
    _isNightMode = widget.isNightMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Profile Section
            _buildSectionHeader('Profile'),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(Icons.person, size: 32, color: Theme.of(context).primaryColor),
                  ),
                  const SizedBox(width: 16),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Demo User',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Glove ID: SG-2025-X1',
                        style: TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // 2. Map Preferences
            _buildSectionHeader('Map Display'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  _buildMapTypeOption(MapType.normal, 'Normal View', Icons.map),
                  const Divider(height: 1),
                  _buildMapTypeOption(MapType.satellite, 'Satellite View', Icons.satellite_alt),
                  const Divider(height: 1),
                  _buildMapTypeOption(MapType.hybrid, 'Hybrid View', Icons.layers),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Night Mode'),
                    subtitle: const Text('High contrast dark map'),
                    secondary: Icon(Icons.nightlight_round, color: _isNightMode ? Colors.amber : Colors.grey),
                    value: _isNightMode,
                    onChanged: (val) {
                      setState(() => _isNightMode = val);
                      widget.onNightModeChanged(val);
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // 3. Navigation Settings
            _buildSectionHeader('Navigation'),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  SwitchListTile(
                    title: const Text('Voice Guidance'),
                    subtitle: const Text('Turn-by-turn voice instructions'),
                    secondary: const Icon(Icons.record_voice_over, color: Colors.blueGrey),
                    value: _voiceGuidance,
                    onChanged: (val) => setState(() => _voiceGuidance = val),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    title: const Text('Smart Notifications'),
                    subtitle: const Text('Vibrate glove on turns'),
                    secondary: const Icon(Icons.vibration, color: Colors.blueGrey),
                    value: _notifications,
                    onChanged: (val) => setState(() => _notifications = val),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 48),
            
            // 4. About
            Center(
              child: Column(
                children: [
                   Icon(Icons.code, color: Colors.grey[400]),
                   const SizedBox(height: 8),
                   Text(
                    'SmartGlove App v1.0.0',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14, 
          fontWeight: FontWeight.bold, 
          color: Colors.grey[600],
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildMapTypeOption(MapType type, String title, IconData icon) {
    final isSelected = _selectedMapType == type;
    return ListTile(
      leading: Icon(
        icon, 
        color: isSelected ? Theme.of(context).primaryColor : Colors.grey
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Theme.of(context).primaryColor : Colors.black87,
        ),
      ),
      trailing: isSelected 
        ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor)
        : null,
      onTap: () {
        setState(() {
          _selectedMapType = type;
        });
        widget.onMapTypeChanged(type);
      },
    );
  }
}
