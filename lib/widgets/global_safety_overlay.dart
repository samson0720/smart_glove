import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/safety_service.dart';

class GlobalSafetyOverlay extends StatefulWidget {
  final Widget child;

  const GlobalSafetyOverlay({super.key, required this.child});

  @override
  State<GlobalSafetyOverlay> createState() => _GlobalSafetyOverlayState();
}

class _GlobalSafetyOverlayState extends State<GlobalSafetyOverlay> {
  final SafetyService _safetyService = SafetyService();
  StreamSubscription? _fallSubscription;
  
  bool _isSosActive = false;
  int _countdown = 30;
  Timer? _countdownTimer;

  // Ideally this should be persisted in SharedPreferences
  // For now we default it or rely on what was typed in settings page (if we used state management)
  // Since we don't have complex state management, we'll assume a default or need a way to share data.
  // For this prototype, we'll hardcode or use a static variable in SafetyService for the contact.
  
  @override
  void initState() {
    super.initState();
    _fallSubscription = _safetyService.onFallDetected.listen((_) {
      _triggerSosSequence();
    });
  }

  @override
  void dispose() {
    _fallSubscription?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _triggerSosSequence() {
    if (_isSosActive) return;

    setState(() {
      _isSosActive = true;
      _countdown = 30; 
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _sendSos();
          _cancelSos();
        }
      });
    });
  }

  void _cancelSos() {
    _countdownTimer?.cancel();
    if (mounted) {
      setState(() {
        _isSosActive = false;
        _countdown = 30;
      });
    }
  }

  Future<void> _sendSos() async {
    // In a real app, retrieve this from shared_preferences
    final String number = SafetyService().emergencyContact ?? "110"; 
    String messageBody = 'HELP! Fall detected via SmartGlove App.';

    try {
      // 1. Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      // 2. Create a Google Maps link
      final String mapsLink = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      messageBody += '\nMy last known location is: $mapsLink';

    } catch (e) {
      messageBody += '\nCould not retrieve GPS location: $e';
      debugPrint('Error getting location for SOS: $e');
    }
    
    final Uri smsLaunchUri = Uri(
      scheme: 'sms',
      path: number,
      queryParameters: <String, String>{
        'body': messageBody,
      },
    );

    try {
      if (await canLaunchUrl(smsLaunchUri)) {
        await launchUrl(smsLaunchUri);
      }
    } catch (e) {
      debugPrint('Error sending SMS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      textDirection: TextDirection.ltr,
      children: [
        widget.child,
        
        // SOS Overlay
        if (_isSosActive)
          Positioned.fill(
            child: Material(
              color: Colors.red.withOpacity(0.95),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 80),
                  const SizedBox(height: 24),
                  const Text(
                    'FALL DETECTED!',
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Sending SOS in',
                    style: TextStyle(color: Colors.white70, fontSize: 18),
                  ),
                  Text(
                    '$_countdown',
                    style: const TextStyle(color: Colors.white, fontSize: 72, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 48),
                  ElevatedButton(
                    onPressed: _cancelSos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                    ),
                    child: const Text('I AM OKAY (CANCEL)', style: TextStyle(fontSize: 20)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
