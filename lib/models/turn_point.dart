import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Represents a turn point in the navigation route
class TurnPoint {
  final LatLng position;
  final String instruction;
  final int type; // 1=右轉, 2=左轉, 3=直行, 0=其他
  final double distanceFromStart; // 從起點的距離（公尺）

  TurnPoint({
    required this.position,
    required this.instruction,
    required this.type,
    required this.distanceFromStart,
  });

  /// Parse maneuver from Google Directions API
  static int parseManeuverType(String? maneuver) {
    if (maneuver == null) return 0;
    
    if (maneuver.contains('right') || maneuver.contains('右')) {
      return 1; // 右轉
    } else if (maneuver.contains('left') || maneuver.contains('左')) {
      return 2; // 左轉
    } else if (maneuver.contains('straight') || maneuver.contains('直')) {
      return 3; // 直行
    }
    return 0; // 其他
  }

  @override
  String toString() {
    return 'TurnPoint(type: $type, instruction: $instruction, position: $position)';
  }
}
