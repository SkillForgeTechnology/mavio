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

          // 2. Directional Heading Cone & Beacon Circle
          Stack(
            alignment: Alignment.center,
            children: [
              // Directional Vision / Heading Cone
              Transform.rotate(
                angle: widget.headingDegrees * (math.pi / 180.0),
                child: CustomPaint(
                  size: const Size(64, 64),
                  painter: _HeadingConePainter(isMoving: !isStopped),
                ),
              ),

              // Elevated Core Circular Beacon with Directional Arrow
              Transform.rotate(
                angle: widget.headingDegrees * (math.pi / 180.0),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                      BoxShadow(
                        color: const Color(0xFFF97316).withOpacity(0.25),
                        blurRadius: 14,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFFB923C),
                            Color(0xFFEA580C),
                          ],
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Top Directional Pointer Triangle
                          Positioned(
                            top: 2,
                            child: Transform.rotate(
                              angle: 0,
                              child: const Icon(
                                Icons.arrow_drop_up_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Center Bus Icon
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.directions_bus_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
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

/// Translucent Directional Vision/Heading Arc
class _HeadingConePainter extends CustomPainter {
  final bool isMoving;

  _HeadingConePainter({required this.isMoving});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final conePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFFF97316).withOpacity(isMoving ? 0.40 : 0.20),
          const Color(0xFFFB923C).withOpacity(isMoving ? 0.18 : 0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 0.65, 1.0],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 36));

    final conePath = Path()
      ..moveTo(cx, cy)
      ..lineTo(cx - 18, cy - 32)
      ..arcToPoint(
        Offset(cx + 18, cy - 32),
        radius: const Radius.circular(22),
      )
      ..lineTo(cx, cy)
      ..close();

    canvas.drawPath(conePath, conePaint);
  }

  @override
  bool shouldRepaint(covariant _HeadingConePainter oldDelegate) =>
      oldDelegate.isMoving != isMoving;
}
