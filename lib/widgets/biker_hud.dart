import 'package:flutter/material.dart';

class BikerHUD extends StatelessWidget {
  final String instruction;
  final String distance;
  final String duration;
  final double speed;
  final VoidCallback onStopNavigation;
  final bool simulateCamera; // New property
  final double? cameraDistance; // Distance to camera in meters

  const BikerHUD({
    super.key,
    required this.instruction,
    required this.distance,
    required this.duration,
    required this.speed,
    required this.onStopNavigation,
    this.simulateCamera = false,
    this.cameraDistance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Next Turn Instruction (Neon Style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00FF00), width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.turn_right, color: Color(0xFF00FF00), size: 48),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      instruction,
                      style: const TextStyle(
                        color: Color(0xFF00FF00),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Roboto', 
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            // Speed Camera Warning (Conditional)
            if (simulateCamera) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.camera_alt, color: Colors.white, size: 32),
                    const SizedBox(width: 12),
                    Text(
                      cameraDistance != null 
                          ? '測速照相 ${cameraDistance!.toStringAsFixed(0)}m'
                          : 'SPEED CAMERA',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            
            // 2. Speedometer (LARGE)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  speed.toStringAsFixed(0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 100,
                    fontWeight: FontWeight.w900,
                    height: 0.9,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'km/h',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),

            // 3. Trip Info & Stop Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Distance & Time
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          duration,
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.flag, color: Colors.white70, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          distance,
                          style: const TextStyle(color: Colors.white70, fontSize: 18),
                        ),
                      ],
                    ),
                  ],
                ),

                // Stop Button
                FloatingActionButton.large(
                  onPressed: onStopNavigation,
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  child: const Icon(Icons.stop, size: 40),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
