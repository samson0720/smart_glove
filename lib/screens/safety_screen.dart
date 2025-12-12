import 'package:flutter/material.dart';
import '../services/safety_service.dart';

class SafetyScreen extends StatefulWidget {
  const SafetyScreen({super.key});

  @override
  State<SafetyScreen> createState() => _SafetyScreenState();
}

class _SafetyScreenState extends State<SafetyScreen> {
  final TextEditingController _contactController = TextEditingController();
  final SafetyService _safetyService = SafetyService();

  @override
  void initState() {
    super.initState();
    _contactController.text = _safetyService.emergencyContact ?? "";
  }

  @override
  void dispose() {
    _safetyService.emergencyContact = _contactController.text;
    _contactController.dispose();
    super.dispose();
  }

  void _toggleMonitoring(bool value) {
    setState(() {
      if (value) {
        _safetyService.startMonitoring();
      } else {
        _safetyService.stopMonitoring();
      }
    });
  }

  void _simulateFall() {
    _safetyService.simulateFall();
  }

  @override
  Widget build(BuildContext context) {
    final bool isActive = _safetyService.isDetectionEnabled;
    final Color statusColor = isActive ? Colors.green : Colors.grey;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Command'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Hero Status Card
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive 
                        ? [Colors.greenAccent.shade700, Colors.teal] 
                        : [Colors.grey.shade400, Colors.grey.shade600],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: (isActive ? Colors.green : Colors.grey).withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isActive ? Icons.security : Icons.gpp_bad, 
                        size: 64, 
                        color: Colors.white
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      isActive ? 'System Active' : 'System Disabled',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isActive ? 'Fall detection is running in background' : 'Tap switch below to enable protection',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    Switch(
                      value: isActive,
                      onChanged: _toggleMonitoring,
                      activeTrackColor: Colors.white.withOpacity(0.5),
                      activeColor: Colors.white,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // 2. Emergency Contact Config
              const Text(
                'Emergency Configuration', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey)
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: TextField(
                    controller: _contactController,
                    keyboardType: TextInputType.phone,
                    onChanged: (val) => _safetyService.emergencyContact = val,
                    style: const TextStyle(fontSize: 18, letterSpacing: 1.0),
                    decoration: const InputDecoration(
                      icon: Icon(Icons.contact_emergency, color: Colors.redAccent),
                      border: InputBorder.none,
                      hintText: 'Emergency Number',
                      labelText: 'SOS Contact Number',
                      filled: false,
                      contentPadding: EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 40),
              
              // 3. Test Action
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _simulateFall,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.notifications_active_outlined),
                  label: const Text('TEST ALARM (SIMULATE)'),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Only use for testing purposes. This will trigger the countdown overlay.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
