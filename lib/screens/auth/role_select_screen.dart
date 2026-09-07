import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/theme/theme.dart';
import 'login_screen.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToLogin(BuildContext context, String role) {
    Navigator.of(context).push(
      FadeSlidePageRoute(
        child: LoginScreen(role: role),
      ),
    );
  }

  Widget _buildAnimatedItem({
    required Widget child,
    required double startVal,
    required double endVal,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, childWidget) {
        final double value = CurvedAnimation(
          parent: _controller,
          curve: Interval(startVal, endVal, curve: Curves.easeOutCubic),
        ).value;
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: childWidget,
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final screenHeight = mediaQuery.size.height;

    final isTall = screenHeight >= 820;
    final isMedium = screenHeight >= 700 && screenHeight < 820;

    final cardVerticalPadding = isTall ? 19.0 : (isMedium ? 16.0 : 13.0);
    final cardSpacing = isTall ? 16.0 : (isMedium ? 13.0 : 10.0);
    final welcomeBottomSpacing = isTall ? 24.0 : (isMedium ? 18.0 : 12.0);
    final iconCircleSize = isTall ? 56.0 : 50.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 1. TOP PREMIUM CURVED GRADIENT HEADER
                    _buildTopHeader(context),

                    // 2. MAIN ROLE SELECTION CONTENT (Centered & Evenly Proportioned)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 10),

                                // Welcome Header
                                _buildAnimatedItem(
                                  startVal: 0.0,
                                  endVal: 0.45,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome!',
                                        style: TextStyle(
                                          fontSize: isTall ? 29 : 26,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF111827),
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Choose your role to continue',
                                        style: TextStyle(
                                          fontSize: isTall ? 15.5 : 14.5,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: welcomeBottomSpacing),

                                // Card 1: Student
                                _buildAnimatedItem(
                                  startVal: 0.15,
                                  endVal: 0.6,
                                  child: _buildRoleCard(
                                    title: 'Student',
                                    subtitle: 'Track your bus and stay informed',
                                    icon: Icons.school_rounded,
                                    iconBgColor: const Color(0xFFFFF0E6),
                                    iconColor: const Color(0xFFFF6A2A),
                                    verticalPadding: cardVerticalPadding,
                                    iconCircleSize: iconCircleSize,
                                    onTap: () => _navigateToLogin(context, 'student'),
                                  ),
                                ),
                                SizedBox(height: cardSpacing),

                                // Card 2: Driver
                                if (!kIsWeb) ...[
                                  _buildAnimatedItem(
                                    startVal: 0.3,
                                    endVal: 0.75,
                                    child: _buildRoleCard(
                                      title: 'Driver',
                                      subtitle: 'Share your location and manage trip',
                                      icon: Icons.directions_bus_rounded,
                                      iconCustomWidget: _SteeringWheelIcon(
                                        color: const Color(0xFF0284C7),
                                        size: isTall ? 28 : 25,
                                      ),
                                      iconBgColor: const Color(0xFFE0F2FE),
                                      iconColor: const Color(0xFF0284C7),
                                      verticalPadding: cardVerticalPadding,
                                      iconCircleSize: iconCircleSize,
                                      onTap: () => _navigateToLogin(context, 'driver'),
                                    ),
                                  ),
                                  SizedBox(height: cardSpacing),
                                ],

                                // Card 3: Management
                                _buildAnimatedItem(
                                  startVal: 0.45,
                                  endVal: 0.9,
                                  child: _buildRoleCard(
                                    title: 'Management',
                                    subtitle: 'Monitor and manage the fleet',
                                    icon: Icons.groups_rounded,
                                    iconBgColor: const Color(0xFFDCFCE7),
                                    iconColor: const Color(0xFF16A34A),
                                    verticalPadding: cardVerticalPadding,
                                    iconCircleSize: iconCircleSize,
                                    onTap: () => _navigateToLogin(context, 'management'),
                                  ),
                                ),

                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. BOTTOM CAMPUS ILLUSTRATION & TAGLINE (Anchored flush to bottom)
                    _buildAnimatedItem(
                      startVal: 0.55,
                      endVal: 1.0,
                      child: _buildBottomCampusSection(bottomPadding, isTall),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================================
  // TOP PREMIUM CURVED GRADIENT HEADER
  // =========================================================================
  Widget _buildTopHeader(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final headerHeight = topPadding + 155.0;

    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Stack(
        children: [
          // Background Multi-Wave Canvas
          Positioned.fill(
            child: CustomPaint(
              painter: _HeaderLayeredWavePainter(),
            ),
          ),

          // Header Content (Brand Logo + Title)
          // Header Content (Brand Logo + Title)
          Positioned(
            top: topPadding + 14,
            left: 22,
            right: 22,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Mavio App Logo
                Image.asset(
                  'logo.png',
                  width: 58,
                  height: 58,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
                const SizedBox(width: 14),

                // Brand Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'MAVIO',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.8,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Your Journey, Always in Sight.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // MODERN ROLE CARD
  // =========================================================================
  Widget _buildRoleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? iconCustomWidget,
    required Color iconBgColor,
    required Color iconColor,
    required double verticalPadding,
    required double iconCircleSize,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFF1F5F9),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.02),
            blurRadius: 4,
            spreadRadius: 0,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          splashColor: iconColor.withValues(alpha: 0.08),
          highlightColor: iconColor.withValues(alpha: 0.04),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: verticalPadding),
            child: Row(
              children: [
                // Circular Icon Box
                Container(
                  width: iconCircleSize,
                  height: iconCircleSize,
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: iconCustomWidget ??
                        Icon(
                          icon,
                          color: iconColor,
                          size: iconCircleSize * 0.52,
                        ),
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),

                // Right Chevron
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================================
  // BOTTOM CAMPUS SECTION (High-Fidelity University Illustration)
  // =========================================================================
  Widget _buildBottomCampusSection(double bottomPadding, bool isTall) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: isTall ? 145 : 125,
          width: double.infinity,
          child: CustomPaint(
            painter: _CampusIllustrationPainter(),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -26),
          child: Column(
            children: const [
              Text(
                'Safer Campuses',
                style: TextStyle(
                  color: Color(0xFFFF521B),
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Brighter Futures',
                style: TextStyle(
                  color: Color(0xFF475569),
                  fontSize: 17.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: math.max(bottomPadding, 10.0)),
      ],
    );
  }
}

// =========================================================================
// CUSTOM PAINTER: MULTI-LAYERED FLOWING LIQUID HEADER WAVES
// =========================================================================
class _HeaderLayeredWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Base Gradient Fill
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: const [
        Color(0xFFFF4910), // Deep vibrant orange
        Color(0xFFFF721D), // Warm radiant orange
        Color(0xFFFF9D4D), // Soft amber peach
      ],
      stops: const [0.0, 0.52, 1.0],
    );

    // Primary Main Wave Path
    final mainWavePath = Path();
    mainWavePath.lineTo(0, h - 38);
    // Left crest down to trough
    mainWavePath.cubicTo(
      w * 0.25,
      h + 8,
      w * 0.55,
      h - 32,
      w * 0.82,
      h - 44,
    );
    // Soft sweep up to right edge
    mainWavePath.quadraticBezierTo(w * 0.94, h - 50, w, h - 32);
    mainWavePath.lineTo(w, 0);
    mainWavePath.close();

    final mainPaint = Paint()
      ..shader = baseGradient.createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.fill;

    // 2. Layer 2: Ambient Translucent Background Flow
    final layer2Path = Path();
    layer2Path.moveTo(0, h - 18);
    layer2Path.cubicTo(
      w * 0.35,
      h - 52,
      w * 0.65,
      h - 8,
      w,
      h - 18,
    );
    layer2Path.lineTo(w, 0);
    layer2Path.lineTo(0, 0);
    layer2Path.close();

    final layer2Paint = Paint()
      ..color = const Color(0xFFFFB67A).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    // 3. Layer 3: Soft Highlight Under-Wave
    final layer3Path = Path();
    layer3Path.moveTo(0, h - 45);
    layer3Path.cubicTo(
      w * 0.30,
      h + 12,
      w * 0.62,
      h - 22,
      w,
      h - 28,
    );
    layer3Path.lineTo(w, h);
    layer3Path.lineTo(0, h);
    layer3Path.close();

    final layer3Paint = Paint()
      ..color = const Color(0xFFFFA05C).withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;

    // Draw layers in order
    canvas.drawPath(layer2Path, layer2Paint);
    canvas.drawPath(mainWavePath, mainPaint);
    canvas.drawPath(layer3Path, layer3Paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// =========================================================================
// CUSTOM PAINTER: HIGH-FIDELITY CAMPUS UNIVERSITY & TREES ILLUSTRATION
// =========================================================================
class _CampusIllustrationPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centerX = w * 0.5;

    // Colors matching reference
    const peachBgHillColor = Color(0xFFFFF2E9);
    const buildingBodyColor = Color(0xFFFFE8D6);
    const buildingContourColor = Color(0xFFFFCCAA);
    const treeFoliageColor = Color(0xFFFFDFC9);
    const treeContourColor = Color(0xFFF6C3A6);
    const columnColor = Color(0xFFFFF7F0);
    const windowWhite = Colors.white;

    // 1. Background Soft Hill Arc
    final bgHillPath = Path();
    bgHillPath.moveTo(0, h - 30);
    bgHillPath.quadraticBezierTo(centerX, h - 75, w, h - 30);
    bgHillPath.lineTo(w, h);
    bgHillPath.lineTo(0, h);
    bgHillPath.close();

    final bgHillPaint = Paint()
      ..color = peachBgHillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(bgHillPath, bgHillPaint);

    final groundLineY = h - 48.0;

    // 2. Trees on Left & Right
    void drawDetailedTree(double x, double groundY, double radius, double trunkH) {
      final treePaint = Paint()
        ..color = treeFoliageColor
        ..style = PaintingStyle.fill;
      final contourPaint = Paint()
        ..color = treeContourColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;

      // Trunk
      canvas.drawLine(
        Offset(x, groundY),
        Offset(x, groundY - trunkH),
        Paint()
          ..color = treeContourColor
          ..strokeWidth = 2.0
          ..strokeCap = StrokeCap.round,
      );

      // Spherical foliage cluster
      final centerFoliage = Offset(x, groundY - trunkH - radius * 0.7);
      canvas.drawCircle(centerFoliage, radius, treePaint);
      canvas.drawCircle(centerFoliage, radius, contourPaint);

      // Subtle inner detail shadow
      canvas.drawCircle(
        Offset(x - radius * 0.2, centerFoliage.dy - radius * 0.2),
        radius * 0.6,
        Paint()..color = const Color(0xFFFFEFE4),
      );
    }

    // Left Trees
    drawDetailedTree(centerX - 138, groundLineY + 6, 14, 18);
    drawDetailedTree(centerX - 108, groundLineY + 2, 17, 22);
    drawDetailedTree(centerX - 80, groundLineY - 2, 13, 17);

    // Right Trees
    drawDetailedTree(centerX + 80, groundLineY - 2, 13, 17);
    drawDetailedTree(centerX + 108, groundLineY + 2, 17, 22);
    drawDetailedTree(centerX + 138, groundLineY + 6, 14, 18);

    // 3. Central Classical Campus Building
    const buildingWidth = 124.0;
    const buildingHeight = 58.0;
    final bLeft = centerX - buildingWidth / 2;
    final bTop = groundLineY - buildingHeight;

    final bodyPaint = Paint()
      ..color = buildingBodyColor
      ..style = PaintingStyle.fill;

    final contourPaint = Paint()
      ..color = buildingContourColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;

    // Main horizontal base block
    final mainRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(bLeft, bTop + 14, buildingWidth, buildingHeight - 14),
      const Radius.circular(2),
    );
    canvas.drawRRect(mainRect, bodyPaint);
    canvas.drawRRect(mainRect, contourPaint);

    // Central Portico / Tower Pavilion
    const porticoWidth = 54.0;
    final pLeft = centerX - porticoWidth / 2;
    final pTop = bTop;

    final porticoRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(pLeft, pTop + 12, porticoWidth, buildingHeight - 12),
      const Radius.circular(2),
    );
    canvas.drawRRect(porticoRect, bodyPaint);
    canvas.drawRRect(porticoRect, contourPaint);

    // Triangular Pediment (Classic University Roof)
    final pedimentPath = Path();
    pedimentPath.moveTo(pLeft - 5, pTop + 12);
    pedimentPath.lineTo(centerX, pTop - 4);
    pedimentPath.lineTo(pLeft + porticoWidth + 5, pTop + 12);
    pedimentPath.close();

    canvas.drawPath(pedimentPath, bodyPaint);
    canvas.drawPath(pedimentPath, contourPaint);

    // Round Medallion / Clock in Pediment
    canvas.drawCircle(
      Offset(centerX, pTop + 5),
      3.5,
      Paint()..color = windowWhite,
    );
    canvas.drawCircle(
      Offset(centerX, pTop + 5),
      3.5,
      contourPaint,
    );

    // Classical Columns in Portico
    for (int i = 0; i < 4; i++) {
      final colX = pLeft + 6 + (i * 14.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(colX, pTop + 14, 4, buildingHeight - 16),
          const Radius.circular(1),
        ),
        Paint()..color = columnColor,
      );
    }

    // Windows & Entrances
    // Arched Grand Entry Door
    final doorRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(centerX - 6.5, groundLineY - 17, 13, 17),
      topLeft: const Radius.circular(6.5),
      topRight: const Radius.circular(6.5),
    );
    canvas.drawRRect(doorRect, Paint()..color = windowWhite);
    canvas.drawRRect(doorRect, contourPaint);

    // Multi-pane Sash Windows on Wings
    void drawSashWindow(double wx, double wy) {
      final wRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(wx, wy, 8, 10),
        const Radius.circular(1.5),
      );
      canvas.drawRRect(wRect, Paint()..color = windowWhite);
      canvas.drawRRect(wRect, contourPaint);
    }

    // Left Wing (Upper & Lower Windows)
    drawSashWindow(bLeft + 9, bTop + 18);
    drawSashWindow(bLeft + 22, bTop + 18);
    drawSashWindow(bLeft + 9, bTop + 34);
    drawSashWindow(bLeft + 22, bTop + 34);

    // Center Portico Upper Windows
    drawSashWindow(centerX - 16, pTop + 18);
    drawSashWindow(centerX + 8, pTop + 18);

    // Right Wing (Upper & Lower Windows)
    drawSashWindow(bLeft + buildingWidth - 30, bTop + 18);
    drawSashWindow(bLeft + buildingWidth - 17, bTop + 18);
    drawSashWindow(bLeft + buildingWidth - 30, bTop + 34);
    drawSashWindow(bLeft + buildingWidth - 17, bTop + 34);

    // 4. Foreground White Curved Dome Hill (Where the Tagline Rests)
    final fgDomePath = Path();
    fgDomePath.moveTo(0, h - 22);
    fgDomePath.quadraticBezierTo(centerX, h - 56, w, h - 22);
    fgDomePath.lineTo(w, h);
    fgDomePath.lineTo(0, h);
    fgDomePath.close();

    final fgDomePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawPath(fgDomePath, fgDomePaint);

    // Subtle edge highlight for the white dome
    final fgEdgePaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final fgEdgePath = Path();
    fgEdgePath.moveTo(0, h - 22);
    fgEdgePath.quadraticBezierTo(centerX, h - 56, w, h - 22);
    canvas.drawPath(fgEdgePath, fgEdgePaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

// =========================================================================
// CUSTOM WIDGET: STEERING WHEEL ICON
// =========================================================================
class _SteeringWheelIcon extends StatelessWidget {
  final Color color;
  final double size;

  const _SteeringWheelIcon({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size),
      painter: _SteeringWheelPainter(color: color),
    );
  }
}

class _SteeringWheelPainter extends CustomPainter {
  final Color color;
  _SteeringWheelPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final radius = (w / 2) - 1.5;

    final rimPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;

    final hubPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final spokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Outer Rim
    canvas.drawCircle(center, radius, rimPaint);

    // Center Hub
    canvas.drawCircle(center, radius * 0.32, hubPaint);

    // Spokes (3-spoke steering wheel)
    canvas.drawLine(center, Offset(center.dx - radius * 0.85, center.dy), spokePaint);
    canvas.drawLine(center, Offset(center.dx + radius * 0.85, center.dy), spokePaint);
    canvas.drawLine(center, Offset(center.dx, center.dy + radius * 0.88), spokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
