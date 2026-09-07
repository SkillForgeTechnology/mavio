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
      duration: const Duration(milliseconds: 2000),
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
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // 1. Radar Pulse Glow when live
          if (widget.isLive)
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final val = _pulseController.value;
                return Container(
                  width: 50 + (val * 45),
                  height: 50 + (val * 45),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (isStopped ? AppColors.primary : const Color(0xFF10B981))
                          .withOpacity((1.0 - val) * 0.5),
                      width: 2.0,
                    ),
                  ),
                );
              },
            ),

          // 2. Headlights Beam & 3D Bus Body (Rotated according to GPS Heading)
          Transform.rotate(
            angle: widget.headingDegrees * (math.pi / 180.0),
            child: CustomPaint(
              size: const Size(64, 64),
              painter: _Bus3DPainter(
                isMoving: !isStopped,
                primaryColor: AppColors.primary,
              ),
            ),
          ),

          // 3. Floating 3D Holographic Speed & Name Badge
          if (widget.showBadge)
            Positioned(
              bottom: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isStopped ? AppColors.borderLight : const Color(0xFF10B981).withOpacity(0.5),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isStopped ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isStopped
                          ? 'Stopped'
                          : '${effectiveSpeed.toStringAsFixed(0)} km/h',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: isStopped ? const Color(0xFFB45309) : const Color(0xFF065F46),
                      ),
                    ),
                    if (widget.busName.isNotEmpty && widget.busName != 'Not Assigned') ...[
                      const SizedBox(width: 4),
                      Text(
                        '• ${widget.busName}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
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

/// Custom 3D Isometric Bus Painter
class _Bus3DPainter extends CustomPainter {
  final bool isMoving;
  final Color primaryColor;

  _Bus3DPainter({
    required this.isMoving,
    required this.primaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Headlights Beam Projection (Fanning out forward / North)
    final headlightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFFEF08A).withOpacity(isMoving ? 0.75 : 0.35),
          const Color(0xFFFEF9C3).withOpacity(isMoving ? 0.40 : 0.15),
          Colors.transparent,
        ],
        stops: const [0.0, 0.6, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy - 26), radius: 34));

    final headlightPath = Path()
      ..moveTo(cx - 10, cy - 14)
      ..lineTo(cx - 24, cy - 38)
      ..lineTo(cx + 24, cy - 38)
      ..lineTo(cx + 10, cy - 14)
      ..close();
    canvas.drawPath(headlightPath, headlightPaint);

    // 1. 3D Elevation Drop Shadow beneath the bus body
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final shadowRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 3), width: 22, height: 44),
      const Radius.circular(8),
    );
    canvas.drawRRect(shadowRect, shadowPaint);

    // 2. Wheels / Side bevels (Metallic Gray/Black)
    final wheelPaint = Paint()..color = const Color(0xFF1E293B);
    // Front wheels
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 11, cy - 10), width: 4, height: 9),
        const Radius.circular(2),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 11, cy - 10), width: 4, height: 9),
        const Radius.circular(2),
      ),
      wheelPaint,
    );
    // Rear wheels
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 11, cy + 12), width: 4, height: 10),
        const Radius.circular(2),
      ),
      wheelPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 11, cy + 12), width: 4, height: 10),
        const Radius.circular(2),
      ),
      wheelPaint,
    );

    // 3. Bus Outer Shell / Main Body (3D Gradient: Primary Indigo to Deep Violet)
    final bodyPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF6366F1), // Bright Indigo front
          Color(0xFF4F46E5), // Base Indigo
          Color(0xFF3730A3), // Deep shadow rear
        ],
      ).createShader(Rect.fromLTWH(cx - 10, cy - 20, 20, 40));

    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 20, height: 40),
      const Radius.circular(6),
    );
    canvas.drawRRect(bodyRect, bodyPaint);

    // 4. Chrome Side Accents
    final chromePaint = Paint()
      ..color = Colors.white.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(bodyRect, chromePaint);

    // 5. Front Curved Windshield (Tinted Cyan/Sky Glass with reflection)
    final windshieldPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFE0F2FE),
          Color(0xFF38BDF8),
        ],
      ).createShader(Rect.fromLTWH(cx - 8, cy - 17, 16, 8));

    final windshieldRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - 13), width: 16, height: 7),
      const Radius.circular(3),
    );
    canvas.drawRRect(windshieldRect, windshieldPaint);

    // 6. Roof Air-Conditioner Unit / Ventilation Hatch (3D Raised Panel)
    final acPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFFFFFFF),
          Color(0xFFCBD5E1),
        ],
      ).createShader(Rect.fromLTWH(cx - 6, cy - 4, 12, 14));

    final acRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 2), width: 12, height: 12),
      const Radius.circular(3),
    );
    canvas.drawRRect(acRect, acPaint);

    // AC Vents Slits
    final ventPaint = Paint()
      ..color = const Color(0xFF64748B)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(cx - 4, cy - 1), Offset(cx + 4, cy - 1), ventPaint);
    canvas.drawLine(Offset(cx - 4, cy + 2), Offset(cx + 4, cy + 2), ventPaint);
    canvas.drawLine(Offset(cx - 4, cy + 5), Offset(cx + 4, cy + 5), ventPaint);

    // 7. Headlight Lenses (Bright Amber/White Luminous points)
    final lightLensPaint = Paint()..color = const Color(0xFFFEF08A);
    canvas.drawCircle(Offset(cx - 6.5, cy - 18.5), 1.8, lightLensPaint);
    canvas.drawCircle(Offset(cx + 6.5, cy - 18.5), 1.8, lightLensPaint);

    // 8. Rear Brake Lights (Crimson / Ruby Red Glow)
    final tailLightPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx - 6.5, cy + 18.5), width: 3.5, height: 2),
        const Radius.circular(1),
      ),
      tailLightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx + 6.5, cy + 18.5), width: 3.5, height: 2),
        const Radius.circular(1),
      ),
      tailLightPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _Bus3DPainter oldDelegate) {
    return oldDelegate.isMoving != isMoving || oldDelegate.primaryColor != primaryColor;
  }
}
