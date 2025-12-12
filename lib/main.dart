import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui; // Added for Custom Marker
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart'; // Compass Support
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:math'; // Added for random string generation
import 'services/safety_service.dart';
import 'services/ble_service.dart'; // BLE Glove Control
import 'models/turn_point.dart'; // Turn detection
import 'screens/ble_dashboard.dart';
import 'screens/safety_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/global_safety_overlay.dart';
import 'widgets/biker_hud.dart'; // Added
import 'package:geolocator/geolocator.dart'; // Ensure geolocator is imported
import 'utils/map_style.dart'; // Added Night Mode style

import 'ble_sender_screen.dart';
import 'ble_sender_distance.dart';

// -----------------------------------------------------------------------------
// CONFIGURATION
// -----------------------------------------------------------------------------

// Hardcoded API Key
const String GOOGLE_MAPS_API_KEY = 'AIzaSyBw-R6jNY-JsJ9cR61QXnN6y1eOKD6UX2U';

void main() {
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  runApp(const MyApp());
}

// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------

class PlaceSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  PlaceSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    final structuredFormatting = json['structured_formatting'] ?? {};
    return PlaceSuggestion(
      placeId: json['place_id'] ?? '',
      description: json['description'] ?? '',
      mainText: structuredFormatting['main_text'] ?? '',
      secondaryText: structuredFormatting['secondary_text'] ?? '',
    );
  }
}

/// 當導航成功開始時觸發此函式
  void _onNavigationStarted(List steps) {
    debugPrint("🚀 [Event Trigger] Navigation has started!");

    debugPrint("✅🚀✅✅🚀✅✅🚀✅✅🚀✅");
    // DistanceBLEService.sendAuto(1);
    
String firstTurnDirection = "straight"; // 預設直行
    String? instruction;

    // 遍歷所有步驟，尋找第一個有明確轉彎指示的步驟
    for (var step in steps) {
      // maneuver 是 Google API 提供的標準轉彎指令 (例如: turn-left, turn-right)
      String? maneuver = step['maneuver']; 
      
      if (maneuver != null && maneuver.isNotEmpty) {
        if (maneuver.contains('left')) {
          firstTurnDirection = "left";
          instruction = step['html_instructions'];
          break; // 找到第一個轉彎就停止
        } else if (maneuver.contains('right')) {
          firstTurnDirection = "right";
          instruction = step['html_instructions'];
          break; // 找到第一個轉彎就停止
        }
      }
    }

    // --- 觸發對應事件 ---
    debugPrint("🔍 Detected First Turn: $firstTurnDirection");
    
    if (firstTurnDirection == "left") {
      // TODO: 這裡呼叫左轉的 BLE 指令
      // BLEService().sendVibrateCommand(2); // 假設 2 是左轉
      debugPrint("⬅️ 準備發送：左轉訊號");
      debugPrint("即將左轉"); // 測試用 Toast
      DistanceBLEService.sendAuto(4);
    } else if (firstTurnDirection == "right") {
      // TODO: 這裡呼叫右轉的 BLE 指令
      // BLEService().sendVibrateCommand(1); // 假設 1 是右轉
      debugPrint("➡️ 準備發送：右轉訊號");
      debugPrint("即將右轉"); // 測試用 Toast
      DistanceBLEService.sendAuto(2);
    } else {
      debugPrint("⬆️ 目前沒有急轉彎，保持直行");
    }
  }

// -----------------------------------------------------------------------------
// MAIN APP
// -----------------------------------------------------------------------------

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartGlove Maps',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto', // Or relevant font if available, default otherwise
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1976D2), // Tech Blue
          brightness: Brightness.light,
          primary: const Color(0xFF1976D2),
          secondary: const Color(0xFF00BFA5), // Teal Accent
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA), // Light grey background

        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          hintStyle: TextStyle(color: Colors.grey[400]),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
        ),
      ),
      // Wrap the entire app with GlobalSafetyOverlay
      builder: (context, child) {
        return GlobalSafetyOverlay(child: child!);
      },
      home: const MapScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// MAP SCREEN
// -----------------------------------------------------------------------------

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Controllers & Keys
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Completer<GoogleMapController> _controller = Completer();
  final TextEditingController _searchController = TextEditingController();
  
  // State
  MapType _currentMapType = MapType.normal; // Settings
  bool _isNightMode = false; // Night Mode
  Position? _currentPosition;
  String? _sessionToken;
  List<PlaceSuggestion> _placeSuggestions = [];
  Timer? _debounce;
  bool _isSearching = false;
  bool _isLoadingRoute = false;
  
  // Map Data
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  LatLng? _selectedLocation;
  String? _selectedPlaceName;
  
  // Navigation State
  bool _isNavigating = false;
  bool _showCameraWarning = false;
  double? _cameraDistance; // Distance to nearest camera in meters
  bool _isCameraLocked = true; // Auto-follow by default
  String? _currentInstruction;
  String? _distance;
  double _currentSpeed = 0.0;
  StreamSubscription<Position>? _speedStreamSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription; // Added
  double? _deviceHeading; // Added magnetic heading
  String? _duration;

  // BLE Vibration Control
  List<TurnPoint> _turnPoints = []; // Parsed turn points from route
  int _lastSent50mTurnIndex = -1; // Prevent duplicate 50m commands
  int _lastSent5mTurnIndex = -1; // Prevent duplicate 5m commands


  // Custom Marker
  BitmapDescriptor? _arrowIcon;

  // Default Location (Taipei)
  static const CameraPosition _defaultCamera = CameraPosition(
    target: LatLng(25.0330, 121.5654),
    zoom: 14.4746,
  );

  @override
  void initState() {
    super.initState();
    _checkLocationPermission(); // Triggers _startLocationUpdates if granted
    _loadCustomMarker();
    _startLocationUpdates(); // Start listening immediately
    _startCompassListener(); // Start compass
    BLEService().startScan(); // Start scanning for SmartGlove
  }

  void _startLocationUpdates() {
    _speedStreamSubscription?.cancel(); // Cancel existing if any
    _speedStreamSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 10),
    ).listen(_onLocationUpdate);
  }

  void _startCompassListener() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      final double? heading = event.heading;
      if (heading != null) {
        setState(() {
          _deviceHeading = heading;
          
          // Update arrow marker immediately when compass changes (especially when stationary)
          if (_arrowIcon != null && _currentPosition != null && _currentSpeed < 10) {
            // Use compass heading for low speeds
            _markers.removeWhere((m) => m.markerId.value == 'user_arrow');
            _markers.add(Marker(
              markerId: const MarkerId('user_arrow'),
              position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              icon: _arrowIcon!,
              rotation: heading, // Use compass heading directly
              anchor: const Offset(0.5, 0.5),
              flat: true,
              zIndex: 100,
            ));
          }
        });
      }
    });
  }

  Future<void> _loadCustomMarker() async {
      final icon = await _createCustomMarkerBitmap();
      setState(() {
          _arrowIcon = icon;
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LOCATION & MAP SETUP
  // ---------------------------------------------------------------------------

  Future<void> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    if (permission == LocationPermission.deniedForever) return;

    final position = await Geolocator.getCurrentPosition();
    setState(() {
      _currentPosition = position;
    });

    final controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(position.latitude, position.longitude),
        zoom: 16,
      ),
    ));
  }

  // ---------------------------------------------------------------------------
  // PLACES API (AUTOCOMPLETE)
  // ---------------------------------------------------------------------------

  void _onSearchChanged(String input, {bool strictBounds = false}) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (input.isEmpty) {
      setState(() {
        _placeSuggestions = [];
        _isSearching = false;
      });
      return;
    }

    // Generate a new session token if needed
    _sessionToken ??= _generateRandomString(20);

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchSuggestions(input, strictBounds: strictBounds);
    });
  }

  Future<void> _fetchSuggestions(String input, {bool strictBounds = false}) async {
    String requestUrl =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=$input'
        '&key=$GOOGLE_MAPS_API_KEY'
        '&sessiontoken=$_sessionToken'
        '&language=zh-TW';

    if (_currentPosition != null) {
      // Always bias to location
      requestUrl += '&location=${_currentPosition!.latitude},${_currentPosition!.longitude}&radius=50000';
      // Only restrict if requested (e.g. Quick Chips)
      if (strictBounds) {
        requestUrl += '&radius=5000&strictbounds=true'; // Tighter radius for strict
      }
    }

    try {
      final response = await http.get(Uri.parse(requestUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final predictions = data['predictions'] as List;
          setState(() {
            _placeSuggestions = predictions
                .map((p) => PlaceSuggestion.fromJson(p))
                .toList();
            _isSearching = true;
          });
        }
      }
    } catch (e) {
      debugPrint('Autocomplete Error: $e');
    }
  }

  Future<void> _onSuggestionSelected(PlaceSuggestion suggestion) async {
    // 1. Clear search focus
    FocusScope.of(context).unfocus();
    _searchController.text = suggestion.mainText;
    
    setState(() {
      _isSearching = false;
      _placeSuggestions = [];
    });

    // 2. Get Place Details (Coordinates)
    final String detailsUrl =
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=${suggestion.placeId}'
        '&fields=geometry,name'
        '&key=$GOOGLE_MAPS_API_KEY'
        '&sessiontoken=$_sessionToken';

    try {
      final response = await http.get(Uri.parse(detailsUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final result = data['result'];
          final location = result['geometry']['location'];
          final lat = location['lat'];
          final lng = location['lng'];
          
          final target = LatLng(lat, lng);

          // 3. Update Map
          _updateMapSelection(target, suggestion.mainText);
          
          // Clear session token after transaction complete
          _sessionToken = null;
        }
      }
    } catch (e) {
      _showError('Failed to get place details');
    }
  }

  void _updateMapSelection(LatLng target, String name) async {
    final controller = await _controller.future;
    
    setState(() {
      _selectedLocation = target;
      _selectedPlaceName = name;
      
      _markers = {
        Marker(
          markerId: const MarkerId('selected'),
          position: target,
          infoWindow: InfoWindow(title: name),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      };
    });

    controller.animateCamera(CameraUpdate.newLatLngZoom(target, 16));
  }

  // ---------------------------------------------------------------------------
  // DIRECTIONS API
  // ---------------------------------------------------------------------------

  Future<void> _startNavigation() async {
    if (_currentPosition == null || _selectedLocation == null) {
      _showError('Waiting for location...');
      return;
    }

    setState(() {
      _isLoadingRoute = true;
    });

    final origin = '${_currentPosition!.latitude},${_currentPosition!.longitude}';
    final destination = '${_selectedLocation!.latitude},${_selectedLocation!.longitude}';

    final url = 'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$origin'
        '&destination=$destination'
        '&key=$GOOGLE_MAPS_API_KEY'
        '&mode=driving'
        '&language=zh-TW';

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          final route = data['routes'][0];
          final leg = route['legs'][0];
          
          // Decode Polyline
          final points = _decodePolyline(route['overview_polyline']['points']);
          
          // Initial instruction
          String? initialInstruction;
          if (leg['steps'] != null && leg['steps'].isNotEmpty) {
            initialInstruction = _cleanHtml(leg['steps'][0]['html_instructions']);
          }

          setState(() {
            _polylines = {
              // 1. Outline (Background)
              Polyline(
                polylineId: const PolylineId('route_outline'),
                points: points,
                color: Colors.blue.shade900,
                width: 10,
                zIndex: 1, // Draw below main
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
              // 2. Main Route (Foreground)
              Polyline(
                polylineId: const PolylineId('route'),
                points: points,
                color: Colors.blue.shade400,
                width: 6,
                zIndex: 2, // Draw above outline
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
              ),
            };
            
            _distance = leg['distance']['text'];
            _duration = leg['duration']['text'];
            _currentInstruction = initialInstruction;
            _isNavigating = true;
            _isLoadingRoute = false;
            
            // Ensure stream is active (if not already)
            if (_speedStreamSubscription == null) {
              _startLocationUpdates();
            }

            // Parse turn points for BLE vibration
            _parseTurnPoints(leg['steps']);
            _lastSent50mTurnIndex = -1; // Reset
            _lastSent5mTurnIndex = -1; // Reset
          });

          _onNavigationStarted(leg['steps']);

          // Initial camera: Focus on USER's current position (not route start)
          final controller = await _controller.future;
          final initialTarget = _currentPosition != null 
              ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
              : points.first; // Fallback to route start if no position yet
          
          controller.animateCamera(CameraUpdate.newCameraPosition(
            CameraPosition(
              target: initialTarget, // Focus on user, not route start
              zoom: 20.0,           // Ultra Zoom
              tilt: 50.0,           // 3D perspective
              bearing: _deviceHeading ?? _currentPosition?.heading ?? 0.0, // Start with correct heading
            ),
          ));

          _onNavigationStarted(leg['steps']);

          // Force arrow marker creation immediately
          if (_currentPosition != null) {
            _onLocationUpdate(_currentPosition!);
          }


        } else {
          _showError('Unable to find route');
        }
      }
    } catch (e) {
      _showError('Navigation Error: $e');
    } finally {
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _stopNavigation() {
    setState(() {
      _isNavigating = false;
      _polylines.clear();
      _selectedLocation = null;
      _selectedPlaceName = null;
      _markers.clear();
      _searchController.clear();
      _speedStreamSubscription?.cancel();
      _speedStreamSubscription = null;
      _currentSpeed = 0.0;
    });
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _cleanHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Parse turn points from Google Directions API steps
  void _parseTurnPoints(List steps) {
    _turnPoints.clear();
    double accumulatedDistance = 0.0;

    for (var step in steps) {
      // Accumulate distance
      double stepDistance = (step['distance']['value'] as num).toDouble();
      accumulatedDistance += stepDistance;

      // Check if this step has a maneuver (turn)
      String? maneuver = step['maneuver'];
      if (maneuver != null && maneuver.isNotEmpty) {
        int turnType = TurnPoint.parseManeuverType(maneuver);
        
        if (turnType > 0) { // Only store actual turns
          LatLng position = LatLng(
            step['start_location']['lat'],
            step['start_location']['lng'],
          );

          _turnPoints.add(TurnPoint(
            position: position,
            instruction: _cleanHtml(step['html_instructions']),
            type: turnType,
            distanceFromStart: accumulatedDistance,
          ));
        }
      }
    }

    print('[NAV] Parsed ${_turnPoints.length} turn points');
    for (int i = 0; i < _turnPoints.length; i++) {
      print('[NAV] Turn $i: ${_turnPoints[i]}');
    }
  }


  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> polyline = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      polyline.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return polyline;
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (var point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }

  // ---------------------------------------------------------------------------
  // UI BUILDERS
  // ---------------------------------------------------------------------------

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1565C0), Color(0xFF42A5F5)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.navigation, color: Colors.white, size: 32),
                ),
                const SizedBox(height: 8), // Reduced from 16
                const Text(
                  'Smart Glove',
                  style: TextStyle(
                    color: Colors.white, 
                    fontSize: 24, // Reduced from 26
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const Text(
                  'Navigation Assistant',
                  style: TextStyle(color: Colors.white70, fontSize: 13), // Reduced from 14
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.map),
            title: const Text('Navigation'),
            selected: true,
            onTap: () {
              Navigator.pop(context); // Close drawer
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.bluetooth),
            title: const Text('Bluetooth Devices'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BleDashboard()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.send_to_mobile), // 換個圖示區隔
            title: const Text('ESP32 訊息發送測試'), // 新功能的按鈕
            onTap: () {
              Navigator.pop(context); // 關閉側邊欄
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BluetoothSenderScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.send_to_mobile), // 換個圖示區隔
            title: const Text('ESP32 傳送距離'), // 新功能的按鈕
            onTap: () {
              Navigator.pop(context); // 關閉側邊欄
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BluetoothSenderScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Safety Center'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SafetyScreen()),
              );
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    currentMapType: _currentMapType,
                    onMapTypeChanged: (MapType type) {
                      setState(() {
                        _currentMapType = type;
                      });
                    },
                    isNightMode: _isNightMode,
                    onNightModeChanged: (bool isNight) async {
                      setState(() {
                        _isNightMode = isNight;
                      });
                      final controller = await _controller.future;
                      controller.setMapStyle(isNight ? darkMapStyle : null);
                    },
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          // 1. Map Layer
          GoogleMap(
            mapType: _currentMapType,
            initialCameraPosition: _defaultCamera,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              if (_isNightMode) {
                controller.setMapStyle(darkMapStyle);
              }
            },
            myLocationEnabled: false, // Use custom arrow marker instead
            myLocationButtonEnabled: false, // We'll build a custom one
            zoomControlsEnabled: false, // Clean UI
            markers: _markers,
            polylines: _polylines,
            compassEnabled: true, // Re-enable compass
            trafficEnabled: true, // 1. Real-time Traffic
            mapToolbarEnabled: false, // Hide "Navigate" arrow in corner
            
            
            /* 
            // POI Click NOT supported in google_maps_flutter 2.14.0
            // This feature requires native platform updates
            onPoiClick: (PointOfInterest poi) {
               if (!_isNavigating) {
                 setState(() {
                   _selectedLocation = poi.position;
                   _selectedPlaceName = poi.name;
                   _markers = {
                     Marker(
                       markerId: MarkerId(poi.placeId),
                       position: poi.position,
                       icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                     ),
                     // Keep arrow marker
                     ..._markers.where((m) => m.markerId.value == 'user_arrow'),
                   };
                   _isSearching = false;
                 });
               }
            },
            */
            padding: EdgeInsets.only(
              top: 100, // Avoid Top Search Bar
              bottom: _isNavigating ? 300 : 0, // 2. Shift logo up when HUD is open
            ),
            // Handle map taps to select locations
            onTap: (LatLng location) {
              if (!_isNavigating) {
                setState(() {
                  _selectedLocation = location;
                  _selectedPlaceName = '選取的地點'; // Generic name
                  _markers = {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: location,
                      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                    ),
                    // Keep arrow marker if exists
                    ..._markers.where((m) => m.markerId.value == 'user_arrow'),
                  };
                  _isSearching = false;
                });
              }
            },
            // Detect user interaction to unlock camera
            onCameraMoveStarted: () {
               if (_isCameraLocked) {
                 setState(() => _isCameraLocked = false); 
               }
            },
          ),

          // 2. Safe Area for UI
          SafeArea(
            child: Column(
              children: [
                // Top Search Bar (Only show when not navigating)
                if (!_isNavigating) ...[
                  _buildSearchBar(),
                  const SizedBox(height: 8),
                  if (!_isSearching) _buildQuickSearchChips(),
                ],
                
                // Suggestions List
                if (_isSearching && _placeSuggestions.isNotEmpty)
                  Flexible(child: _buildSuggestionsList()),
              ],
            ),
          ),

          // 3. Navigation Info / Place Details Bottom Sheet
          if (_selectedLocation != null && !_isSearching)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _isNavigating 
                  ? BikerHUD(
                      instruction: _currentInstruction ?? 'Proceed to route',
                      distance: _distance ?? '0 m',
                      duration: _duration ?? '0 min',
                      speed: _currentSpeed,
                      onStopNavigation: _stopNavigation,
                      simulateCamera: _showCameraWarning, // Real API status
                      cameraDistance: _cameraDistance, // Pass distance
                    )
                  : _buildBottomPanel(),
            ),

          // 4. Custom My Location Button
          if (!_isSearching)
            Positioned(
              right: 16,
              bottom: _isNavigating ? 280 : 100, // Adjust position when HUD is active
              child: Column(
                children: [
                   FloatingActionButton(
                    mini: true,
                    heroTag: 'my_loc',
                    backgroundColor: _isCameraLocked && _isNavigating ? Colors.blue : Colors.white, // Visual feedback
                    onPressed: () {
                      if (_isNavigating) {
                        // In navigation mode: just re-lock and re-center WITHOUT changing zoom
                        setState(() {
                          _isCameraLocked = true;
                        });
                        // Immediately trigger camera update with current position
                        if (_currentPosition != null) {
                          _onLocationUpdate(_currentPosition!);
                        }
                      } else {
                        // Not navigating: normal behavior (zoom to 16)
                        _checkLocationPermission();
                      }
                    },
                    child: Icon(Icons.my_location, color: _isCameraLocked && _isNavigating ? Colors.white : Colors.blue),
                  ),
                  const SizedBox(height: 12),
                   FloatingActionButton(
                    mini: true,
                    heroTag: 'demo_btn',
                    backgroundColor: Colors.redAccent,
                    onPressed: _triggerDemoMode,
                    child: const Icon(Icons.flash_on, color: Colors.white),
                  ),
                ],
              ),
            ),

          // 5. Back Button (During Navigation)
          if (_isNavigating)
            Positioned(
              top: 50,
              left: 16,
              child: CircleAvatar(
                backgroundColor: Colors.white,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.black),
                  onPressed: _stopNavigation,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: InputDecoration(
            hintText: 'Search here...',
            hintStyle: TextStyle(color: Colors.grey[600]),
            prefixIcon: IconButton(
              icon: const Icon(Icons.menu, color: Colors.black54),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                  )
                : const Icon(Icons.mic, color: Colors.blue), // Aesthetic only
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _placeSuggestions.length,
        separatorBuilder: (ctx, i) => const Divider(height: 1, indent: 50),
        itemBuilder: (context, index) {
          final suggestion = _placeSuggestions[index];
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFF1F3F4),
              child: Icon(Icons.location_on, color: Colors.grey),
            ),
            title: Text(
              suggestion.mainText,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              suggestion.secondaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _onSuggestionSelected(suggestion),
          );
        },
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          
          if (!_isNavigating) ...[
            // Place Details State
            Text(
              _selectedPlaceName ?? 'Selected Location',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            // Mock rating/type info
            Row(
              children: [
                const Text('4.5', style: TextStyle(fontWeight: FontWeight.bold)),
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const Icon(Icons.star_half, size: 16, color: Colors.amber),
                Text(' (128) • Destination', style: TextStyle(color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingRoute ? null : _startNavigation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    icon: _isLoadingRoute 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.directions),
                    label: const Text('Directions'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedLocation = null;
                      _markers.clear();
                      _searchController.clear();
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ] else ...[
            // Navigation State
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.turn_right, color: Colors.green, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentInstruction ?? 'Proceed to route',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_distance != null) 
                            Text(_distance!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                          if (_duration != null) ...[
                            const SizedBox(width: 8),
                            Text('($_duration)', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                          ]
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildQuickSearchChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildChip('加油站', Icons.local_gas_station, Colors.orange, '加油站'),
          const SizedBox(width: 12),
          _buildChip('便利商店', Icons.storefront, Colors.blue, '便利商店'),
          const SizedBox(width: 12),
          _buildChip('機車停車', Icons.local_parking, Colors.grey, '機車停車'), // Broadened keyword
        ],
      ),
    );
  }

  Widget _buildChip(String label, IconData icon, Color color, String query) {
    return ActionChip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
      onPressed: () {
        _searchController.text = query;
        _onSearchChanged(query, strictBounds: true); // Enforce nearby results for chips
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HELPER METHODS
  // ---------------------------------------------------------------------------

  void _onLocationUpdate(Position position) {
      // 1. Fetch Cameras (Async, non-blocking for UI)
      SafetyService().fetchSpeedCameras(position.latitude, position.longitude);

      // 2. Check for immediate danger (Sync check against cache)
      double? cameraDistance = SafetyService().checkForCameras(LatLng(position.latitude, position.longitude));


      // Determine Heading: Compass (Low Speed) vs GPS (High Speed)
      double heading = (position.speed * 3.6 > 5) ? position.heading : (_deviceHeading ?? position.heading);

      setState(() {
          _currentSpeed = position.speed * 3.6; // Convert m/s to km/h
          _cameraDistance = cameraDistance; // Store distance
          _showCameraWarning = (cameraDistance != null); 
          _currentPosition = position; // Maintain bias

          // Update Custom Arrow Marker
          if (_arrowIcon != null) {
            _markers.removeWhere((m) => m.markerId.value == 'user_arrow');
            _markers.add(Marker(
              markerId: const MarkerId('user_arrow'),
              position: LatLng(position.latitude, position.longitude),
              icon: _arrowIcon!,
              rotation: heading, // Use smart heading
              anchor: const Offset(0.5, 0.5), // Center rotation
              flat: true, // Lie flat on map
              zIndex: 100, // Always on top
            ));
          }
      });

      // 3. BLE Vibration: Check distance to next turn
      if (_isNavigating && _turnPoints.isNotEmpty) {
        _checkAndSendVibration(position);
      }

      // 4. Move Camera (Navigation Mode) - Follow User (OUTSIDE setState!)
      if (_isNavigating && _controller.isCompleted && _isCameraLocked) {
          _controller.future.then((c) {
              c.animateCamera(CameraUpdate.newCameraPosition(
                  CameraPosition(
                      target: LatLng(position.latitude, position.longitude),
                      zoom: 20.0, // Ultra Zoom - always maintain during navigation
                      tilt: 50.0,
                      bearing: heading, // Use smart heading
                  )
              ));
          });
      }
  }

  /// Check distance to turns and send vibration if close
  void _checkAndSendVibration(Position position) {
    LatLng currentPos = LatLng(position.latitude, position.longitude);

    for (int i = 0; i < _turnPoints.length; i++) {
      TurnPoint turn = _turnPoints[i];
      double distance = SafetyService().calculateDistance(
        currentPos.latitude, currentPos.longitude,
        turn.position.latitude, turn.position.longitude,
      );

      // --- 5 Meter Check (Imminent Turn) ---
      // Has the 5m signal for this turn been sent? If not, check distance.
      if (i > _lastSent5mTurnIndex) {
        if (distance < 5) {
          BLEService().sendVibrateCommand(turn.type); // 1=Right, 2=Left
          _lastSent5mTurnIndex = i;
          print('[BLE] 📳 Sent IMMINENT (5m) vibration for turn $i: ${turn.instruction}');
          
          // Also mark 50m as sent to prevent it from sending after the 5m one.
          if (i > _lastSent50mTurnIndex) {
            _lastSent50mTurnIndex = i;
          }
          continue; // Done with this turn, check next one
        }
      }

      // --- 50 Meter Check (Approaching Turn) ---
      // Has the 50m signal for this turn been sent? If not, check distance.
      if (i > _lastSent50mTurnIndex) {
        if (distance < 50) {
          BLEService().sendVibrateCommand(4); // 4 = Imminent Turn Signal
          _lastSent50mTurnIndex = i;
          print('[BLE] 📳 Sent APPROACHING (50m) vibration for turn $i: ${turn.instruction}');
          continue; // Done with this turn, check next one
        }
      }
    }
  }

  void _triggerDemoMode() {
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請先等待 GPS 定位完成')),
      );
      return;
    }

    // Calculate position ~250m north of current location
    final cameraLat = _currentPosition!.latitude + 0.00225;
    final cameraLng = _currentPosition!.longitude;

    // Inject fake camera
    SafetyService().injectDemoCamera(cameraLat, cameraLng);

    // Trigger check
    _onLocationUpdate(_currentPosition!);
    
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('🚨 測速照相 Demo: 已在前方 250m 設置假的測速點'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
        )
    );
  }

  // Helper to generate a random session token without external dependencies
  String _generateRandomString(int length) {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    Random rnd = Random();
    return String.fromCharCodes(Iterable.generate(
        length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))));
  }

  Future<BitmapDescriptor> _createCustomMarkerBitmap() async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    const Size size = Size(120, 120); // Large size for "Big Arrow"

    final Paint paint = Paint()..color = Colors.blueAccent;
    final Paint shadowPaint = Paint()..color = Colors.black.withOpacity(0.5)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    // Draw Arrow Shape (Triangle)
    final Path path = Path();
    path.moveTo(size.width / 2, 0); // Top tip
    path.lineTo(size.width, size.height); // Bottom right
    path.lineTo(size.width / 2, size.height * 0.8); // Bottom notch
    path.lineTo(0, size.height); // Bottom left
    path.close();

    // Draw Shadow
    canvas.save();
    canvas.translate(2, 4);
    canvas.drawPath(path, shadowPaint);
    canvas.restore();

    // Draw Main Arrow
    canvas.drawPath(path, paint);
    
    // Draw Outline
    final Paint outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawPath(path, outlinePaint);

    final ui.Image image = await pictureRecorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
    final ByteData? data = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
}
