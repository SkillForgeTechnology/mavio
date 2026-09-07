import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/theme/theme.dart';

class Mavio3DBusMarker extends StatefulWidget {
  final String busName;
  final double speedKmH;
  final double headingDegrees;
  final bool isLive;
  final bool showBadge;

  const Mavio3DBusMarker({
    super.key,
    required this.busName,
    required this.speedKmH,
    required this.headingDegrees,
    this.isLive = true,
    this.showBadge = true,
  });

  @override
  State<Mavio3DBusMarker> createState() => _Mavio3DBusMarkerState();
}

class _Mavio3DBusMarkerState extends State<Mavio3DBusMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // GPS Stationary Filter: if speed < 3.0 km/h, treat as stopped
    final effectiveSpeed = widget.speedKmH < 3.0 ? 0.0 : widget.speedKmH;
    final isStopped = effectiveSpeed == 0.0;

    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Subtle Radar Pulse when active
          if (widget.isLive)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final val = _pulseController.value;
                return Container(
                  width: 56 + (val * 42),
                  height: 56 + (val * 42),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFF97316).withOpacity((1.0 - val) * 0.4),
                      width: 1.5,
                    ),
                  ),
                );
              },
            ),

          // 2. Headlights & Sleek Google Maps Style 3D Navigation Bus Model
          Transform.rotate(
            angle: widget.headingDegrees * (math.pi / 180.0),
            child: CustomPaint(
              size: const Size(76, 76),
              painter: _GoogleMaps3DBusPainter(
                isMoving: !isStopped,
              ),
            ),
          ),

          // 3. Floating Premium Glassmorphism Badge
          if (widget.showBadge)
            Positioned(
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.96),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isStopped ? const Color(0xFFE2E8F0) : const Color(0xFFF97316).withOpacity(0.4),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isStopped ? const Color(0xFFF59E0B) : const Color(0xFFEA580C),
                        boxShadow: [
                          BoxShadow(
                            color: (isStopped ? const Color(0xFFF59E0B) : const Color(0xFFEA580C)).withOpacity(0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isStopped
                          ? 'Stopped'
                          : '${effectiveSpeed.toStringAsFixed(0)} km/h',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isStopped ? const Color(0xFFB45309) : const Color(0xFFEA580C),
                      ),
                    ),
                    if (widget.busName.isNotEmpty && widget.busName != 'Not Assigned') ...[
                      const SizedBox(width: 4),
                      Text(
                        '• ${widget.busName}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// High-End Google Maps Style 3D Vector Coach/Bus Painter
class _GoogleMaps3DBusPainter extends CustomPainter {
  final bool isMoving;

  _GoogleMaps3DBusPainter({
    required this.isMoving,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 1. Dynamic Forward LED Headlight Beams (Illuminates road ahead)
    final headlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFEF3C7).withOpacity(isMoving ? 0.70 : 0.28),
          const Color(0xFFFFFBEB).withOpacity(isMoving ? 0.30 : 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.60, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy - 30), radius: 38));

    final headlightPath = Path()
      ..moveTo(cx - 9, cy - 22)
      ..lineTo(cx - 24, cy - 44)
      ..lineTo(cx + 24, cy - 44)
      ..lineTo(cx + 9, cy - 22)
      ..close();
    canvas.drawPath(headlightPath, headlightPaint);

    // 2. Realistic 3D Elevated Ground Drop Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 3.5), width: 24, height: 52),
        const Radius.circular(10),
      ),
      shadowPaint,
    );

    // 3. Dark Underbody Chassis & Wheels Base
    final chassisPaint = Paint()..color = const Color(0xFF0F172A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 0.5), width: 24, height: 49),
        const Radius.circular(8),
      ),
      chassisPaint,
    );

    // 4. Aerodynamic Side Mirrors (Left & Right)
    final mirrorPaint = Paint()..color = const Color(0xFFEA580C);
    // Left Mirror
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 13.5, cy - 16), width: 3.5, height: 8),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );
    // Right Mirror
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 13.5, cy - 16), width: 3.5, height: 8),
        const Radius.circular(2),
      ),
      mirrorPaint,
    );

    // 5. Main Coach Body: Metallic Pearl White with 3D Bevel Lighting
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF), // Pure White Front
          Color(0xFFF1F5F9), // Pearl White Mid
          Color(0xFFCBD5E1), // 3D Shading Rear
        ],
      ).createShader(Rect.fromLTWH(cx - 11, cy - 24, 22, 48));

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 22, height: 48),
      const Radius.circular(8),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // 6. Dynamic Mavio Orange Racing Side Accents
    final orangeStripePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFB923C),
          Color(0xFFEA580C),
          Color(0xFFC2410C),
        ],
      ).createShader(Rect.fromLTWH(cx - 11, cy - 14, 22, 36));

    // Left Stripe
    final leftStripe = Path()
      ..moveTo(cx - 10.5, cy - 12)
      ..lineTo(cx - 8.0, cy - 12)
      ..lineTo(cx - 8.0, cy + 20)
      ..lineTo(cx - 10.5, cy + 20)
      ..close();
    canvas.drawPath(leftStripe, orangeStripePaint);

    // Right Stripe
    final rightStripe = Path()
      ..moveTo(cx + 8.0, cy - 12)
      ..lineTo(cx + 10.5, cy - 12)
      ..lineTo(cx + 10.5, cy + 20)
      ..lineTo(cx + 8.0, cy + 20)
      ..close();
    canvas.drawPath(rightStripe, orangeStripePaint);

    // 7. Panoramic Curved Windshield (Deep Obsidian Glass with 3D Glare)
    final windshieldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0F172A),
          Color(0xFF1E293B),
        ],
      ).createShader(Rect.fromLTWH(cx - 9, cy - 22, 18, 10));

    final windshieldRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - 17), width: 18, height: 9.5),
      const Radius.circular(5),
    );
    canvas.drawRRect(windshieldRect, windshieldPaint);

    // 3D Glass Sun Reflection
    final glassGlarePaint = Paint()
      ..color = Colors.white.withOpacity(0.40)
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(cx - 6, cy - 19), Offset(cx + 3, cy - 15), glassGlarePaint);

    // 8. Streamlined Rooftop AC Pod with Orange Winglets
    final acPodPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFE2E8F0),
        ],
      ).createShader(Rect.fromLTWH(cx - 5.5, cy - 5, 11, 18));

    final acPodRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 3), width: 11, height: 18),
      const Radius.circular(3.5),
    );
    canvas.drawRRect(acPodRect, acPodPaint);

    // AC Center Spine & Dual Vent Fans
    final fanPaint = Paint()..color = const Color(0xFF94A3B8);
    canvas.drawCircle(Offset(cx, cy - 1), 2.2, fanPaint);
    canvas.drawCircle(Offset(cx, cy + 7), 2.2, fanPaint);

    // AC Orange Accent Fin
    final acFinPaint = Paint()..color = const Color(0xFFEA580C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 3), width: 2.0, height: 14),
        const Radius.circular(1),
      ),
      acFinPaint,
    );

    // 9. Modern LED Headlight Blades
    final ledPaint = Paint()
      ..color = const Color(0xFFFEF08A)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx - 9, cy - 22), Offset(cx - 4, cy - 23.5), ledPaint);
    canvas.drawLine(Offset(cx + 9, cy - 22), Offset(cx + 4, cy - 23.5), ledPaint);

    // 10. Rear LED Neon Tail-Light Bar
    final tailLightPaint = Paint()
      ..color = const Color(0xFFEF4444)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx - 8, cy + 23), Offset(cx + 8, cy + 23), tailLightPaint);

    // 11. Crisp Outer Metallic Edge / 3D Bevel
    final bevelPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.9;
    canvas.drawRRect(bodyRect, bevelPaint);
  }

  @override
  bool shouldRepaint(covariant _GoogleMaps3DBusPainter oldDelegate) {
    return oldDelegate.isMoving != isMoving;
  }
}
