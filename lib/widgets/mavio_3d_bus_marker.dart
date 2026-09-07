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

          // 2. Headlights & Sleek 3D Google Maps Style Bus Model
          Transform.rotate(
            angle: widget.headingDegrees * (math.pi / 180.0),
            child: SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Headlight beam casting forward onto road
                  Positioned(
                    top: 0,
                    child: CustomPaint(
                      size: const Size(60, 40),
                      painter: _HeadlightBeamPainter(isMoving: !isStopped),
                    ),
                  ),
                  // High-Definition 3D Model Asset with Fallback
                  Image.asset(
                    'assets/mavio_3d_bus.png',
                    width: 66,
                    height: 66,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    errorBuilder: (context, error, stackTrace) {
                      return Image.asset(
                        'mavio_bus.png',
                        width: 66,
                        height: 66,
                        fit: BoxFit.contain,
                        errorBuilder: (context, err, stack) {
                          return CustomPaint(
                            size: const Size(70, 70),
                            painter: _LuxuryWhiteOrangeBusPainter(
                              isMoving: !isStopped,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
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

/// Headlight beam projecting onto the road ahead of the 3D bus
class _HeadlightBeamPainter extends CustomPainter {
  final bool isMoving;

  _HeadlightBeamPainter({required this.isMoving});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height;

    final headlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFEF3C7).withOpacity(isMoving ? 0.65 : 0.30),
          const Color(0xFFFFFBEB).withOpacity(isMoving ? 0.30 : 0.12),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, 0), radius: 36));

    final headlightPath = Path()
      ..moveTo(cx - 10, cy)
      ..lineTo(cx - 24, 0)
      ..lineTo(cx + 24, 0)
      ..lineTo(cx + 10, cy)
      ..close();
    canvas.drawPath(headlightPath, headlightPaint);
  }

  @override
  bool shouldRepaint(covariant _HeadlightBeamPainter oldDelegate) =>
      oldDelegate.isMoving != isMoving;
}

/// Ultra-Premium White & Orange 3D Coach/Bus Painter
class _LuxuryWhiteOrangeBusPainter extends CustomPainter {
  final bool isMoving;

  _LuxuryWhiteOrangeBusPainter({
    required this.isMoving,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 1. Sleek Modern Headlight Beam (Crisp Soft Glow)
    final headlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFEF3C7).withOpacity(isMoving ? 0.60 : 0.25),
          const Color(0xFFFFFBEB).withOpacity(isMoving ? 0.25 : 0.10),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy - 28), radius: 36));

    final headlightPath = Path()
      ..moveTo(cx - 8, cy - 20)
      ..lineTo(cx - 20, cy - 42)
      ..lineTo(cx + 20, cy - 42)
      ..lineTo(cx + 8, cy - 20)
      ..close();
    canvas.drawPath(headlightPath, headlightPaint);

    // 2. Realistic 3D Elevated Ambient Ground Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);

    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 3.5), width: 22, height: 50),
      const Radius.circular(9),
    );
    canvas.drawRRect(shadowRect, shadowPaint);

    // 3. Streamlined Underbody / Tire Arches (Subtle Dark Chassis)
    final chassisPaint = Paint()..color = const Color(0xFF1E293B);
    final chassisRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 1), width: 22, height: 48),
      const Radius.circular(7),
    );
    canvas.drawRRect(chassisRect, chassisPaint);

    // 4. Main Coach Body: Pearl White with Sleek 3D Shading
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFFFFFF), // Pure White Front
          Color(0xFFF8FAFC), // Pearl White Mid
          Color(0xFFE2E8F0), // Subtle Slate Shading Rear
        ],
      ).createShader(Rect.fromLTWH(cx - 10, cy - 23, 20, 46));

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 20, height: 46),
      const Radius.circular(7),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // 5. Dynamic Mavio Orange Racing & Aero Stripes on Sides
    final orangeStripePaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFFB923C), // Light Orange
          Color(0xFFEA580C), // Vibrant Mavio Orange
          Color(0xFFC2410C), // Deep Orange
        ],
      ).createShader(Rect.fromLTWH(cx - 10, cy - 15, 20, 36));

    // Left Aero Stripe
    final leftStripe = Path()
      ..moveTo(cx - 9.5, cy - 12)
      ..lineTo(cx - 7.5, cy - 12)
      ..lineTo(cx - 7.5, cy + 20)
      ..lineTo(cx - 9.5, cy + 20)
      ..close();
    canvas.drawPath(leftStripe, orangeStripePaint);

    // Right Aero Stripe
    final rightStripe = Path()
      ..moveTo(cx + 7.5, cy - 12)
      ..lineTo(cx + 9.5, cy - 12)
      ..lineTo(cx + 9.5, cy + 20)
      ..lineTo(cx + 7.5, cy + 20)
      ..close();
    canvas.drawPath(rightStripe, orangeStripePaint);

    // 6. Panoramic Tinted Windshield & Sunroof (High-End Dark Glass)
    final windshieldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF0F172A), // Deep Obsidian Tint
          Color(0xFF1E293B), // Dark Slate Glass
        ],
      ).createShader(Rect.fromLTWH(cx - 8, cy - 21, 16, 9));

    final windshieldRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - 16), width: 16, height: 8.5),
      const Radius.circular(4),
    );
    canvas.drawRRect(windshieldRect, windshieldPaint);

    // Windshield Reflection Streak
    final glassGlarePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx - 5, cy - 18), Offset(cx + 3, cy - 14), glassGlarePaint);

    // 7. Low-Profile Streamlined Rooftop AC Pod (White with Orange Center Fin)
    final acPodPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFE2E8F0),
        ],
      ).createShader(Rect.fromLTWH(cx - 5, cy - 4, 10, 16));

    final acPodRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 3), width: 10, height: 16),
      const Radius.circular(3),
    );
    canvas.drawRRect(acPodRect, acPodPaint);

    // AC Pod Center Orange Stripe
    final acOrangeFin = Paint()..color = const Color(0xFFEA580C);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy + 3), width: 2.5, height: 12),
        const Radius.circular(1),
      ),
      acOrangeFin,
    );

    // 8. Sleek LED DRL Headlight Strips (Modern Automotive Blade Lights)
    final ledPaint = Paint()
      ..color = const Color(0xFFFEF08A)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    // Left LED Blade
    canvas.drawLine(Offset(cx - 8, cy - 21), Offset(cx - 3, cy - 22), ledPaint);
    // Right LED Blade
    canvas.drawLine(Offset(cx + 8, cy - 21), Offset(cx + 3, cy - 22), ledPaint);

    // 9. Rear Modern LED Tail Light Strip (Continuous Red Neon Bar)
    final tailLightPaint = Paint()
      ..color = const Color(0xFFDC2626)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(Offset(cx - 7, cy + 22), Offset(cx + 7, cy + 22), tailLightPaint);

    // 10. Crisp Outer Border / Bevel
    final bevelPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    canvas.drawRRect(bodyRect, bevelPaint);
  }

  @override
  bool shouldRepaint(covariant _LuxuryWhiteOrangeBusPainter oldDelegate) {
    return oldDelegate.isMoving != isMoving;
  }
}
