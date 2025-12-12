import 'dart:async';
import 'dart:math';
import 'dart:convert'; // Added
import 'package:http/http.dart' as http; // Added
import 'package:google_maps_flutter/google_maps_flutter.dart'; // Added for LatLng
import 'package:sensors_plus/sensors_plus.dart';

class SafetyService {
  // Singleton pattern
  static final SafetyService _instance = SafetyService._internal();
  factory SafetyService() => _instance;
  SafetyService._internal();

  // Settings
  bool isDetectionEnabled = false;
  String? emergencyContact = "0912345678"; // Default contact
  
  // Stream for fall events
  final _fallController = StreamController<bool>.broadcast();
  Stream<bool> get onFallDetected => _fallController.stream;

  // Internal state
  StreamSubscription? _accelerometerSubscription;
  DateTime? _lastFallTime;

  // Thresholds (Adjust based on testing)
  // Lowered to 15.0 for easier manual testing (approx 1.5g)
  static const double IMPACT_THRESHOLD = 15.0; // m/s^2

  void startMonitoring() {
    if (_accelerometerSubscription != null) return;
    
    isDetectionEnabled = true;
    _accelerometerSubscription = userAccelerometerEvents.listen((UserAccelerometerEvent event) {
      if (!isDetectionEnabled) return;

      // Calculate total acceleration (G-force magnitude)
      double gForce = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      if (gForce > IMPACT_THRESHOLD) {
        // Prevent multiple triggers in short succession
        if (_lastFallTime == null || DateTime.now().difference(_lastFallTime!) > const Duration(seconds: 5)) {
          _lastFallTime = DateTime.now();
          _fallController.add(true); // Trigger fall event
        }
      }
    });
  }

  void stopMonitoring() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    isDetectionEnabled = false;
  }

  void dispose() {
    stopMonitoring();
    _fallController.close();
  }

  // Allow manual triggering for testing
  void simulateFall() {
    _fallController.add(true);
  }

  // ---------------------------------------------------------------------------
  // SPEED CAMERA LOGIC (OSM API)
  // ---------------------------------------------------------------------------
  
  List<LatLng> _cachedCameras = [];
  DateTime? _lastFetchTime;
  LatLng? _lastFetchLocation;

  // 1. Fetch cameras from Overpass API (2km radius)
  Future<void> fetchSpeedCameras(double lat, double lon) async {
    // Avoid frequent fetching: Only fetch if moved > 1km or never fetched
    if (_lastFetchLocation != null) {
      double dist = calculateDistance(lat, lon, _lastFetchLocation!.latitude, _lastFetchLocation!.longitude);
      if (dist < 1000) return; // Less than 1km movement, skip
    }

    try {
      final query = '''
        [out:json];
        node["highway"="speed_camera"](around:2000, $lat, $lon);
        out;
      ''';

      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      final response = await http.post(url, body: query);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final elements = data['elements'] as List;

        _cachedCameras = elements.map((e) => LatLng(e['lat'], e['lon'])).toList();
        _lastFetchLocation = LatLng(lat, lon);
        _lastFetchTime = DateTime.now();
        print('SafetyService: Fetched \${_cachedCameras.length} cameras.');
      }
    } catch (e) {
      print('SafetyService: Error fetching cameras: $e');
    }
  }

  // 2. Check if any camera is nearby (<500m) and return distance
  double? checkForCameras(LatLng currentPos) {
    if (_cachedCameras.isEmpty) return null;

    double nearestDist = double.infinity;
    for (final camera in _cachedCameras) {
      double dist = calculateDistance(currentPos.latitude, currentPos.longitude, camera.latitude, camera.longitude);
      if (dist < nearestDist) nearestDist = dist;
    }
    
    // Only return distance if within 500m
    return (nearestDist < 500) ? nearestDist : null;
  }

  // Haversine formula (meters) - public for BLE service
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295;
    const c = cos;
    final a = 0.5 - c((lat2 - lat1) * p) / 2 + 
        c(lat1 * p) * c(lat2 * p) * 
        (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a)) * 1000;
  }

  // 3. Manually inject a demo camera for testing
  void injectDemoCamera(double lat, double lon) {
    _cachedCameras = [LatLng(lat, lon)];
    print('SafetyService: Demo camera injected at ($lat, $lon)');
  }
}
