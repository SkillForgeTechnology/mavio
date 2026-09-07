import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/toast_utils.dart';
import '../student/student_dashboard.dart';
import '../driver/driver_dashboard.dart';
import '../management/admin_dashboard.dart';
import 'role_select_screen.dart';

class LoginScreen extends StatefulWidget {
  final String role; // 'student' | 'driver' | 'management'

  const LoginScreen({super.key, required this.role});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _performLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    String emailInput = _emailController.text.trim();
    if (widget.role == 'student' && !emailInput.contains('@')) {
      emailInput = '$emailInput@mavio.student';
    } else if (widget.role == 'driver' && !emailInput.contains('@')) {
      final cleanDigits = emailInput.replaceAll(RegExp(r'[^\d]'), '');
      emailInput = '$cleanDigits@mavio.driver';
    }

    final success = await auth.login(
      emailInput,
      _passwordController.text,
      widget.role,
    );

    if (!mounted) return;

    if (success) {
      Widget dashboard;
      if (widget.role == 'student') {
        dashboard = const StudentDashboard();
      } else if (widget.role == 'driver') {
        dashboard = const DriverDashboard();
      } else {
        dashboard = const AdminDashboard();
      }

      Navigator.of(context).pushAndRemoveUntil(
        FadeSlidePageRoute(child: dashboard),
        (route) => false,
      );
    } else {
      AppToast.show(
        context,
        auth.error ?? 'Authentication failed',
        isError: true,
      );
    }
  }

  Widget _buildAnimatedItem({
    required Widget child,
    required double startVal,
    required double endVal,
  }) {
    return AnimatedBuilder(
      animation: _animController,
      builder: (context, childWidget) {
        final double value = CurvedAnimation(
          parent: _animController,
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
    final auth = Provider.of<AuthProvider>(context);
    final mediaQuery = MediaQuery.of(context);
    final bottomPadding = mediaQuery.padding.bottom;
    final screenHeight = mediaQuery.size.height;

    final isTall = screenHeight >= 820;

    String roleTitle = 'Student';
    IconData roleIcon = Icons.school_rounded;
    Color roleBgColor = const Color(0xFFFFF0E6);
    Color roleAccentColor = const Color(0xFFFF6A2A);

    if (widget.role == 'driver') {
      roleTitle = 'Driver';
      roleIcon = Icons.directions_bus_rounded;
      roleBgColor = const Color(0xFFE0F2FE);
      roleAccentColor = const Color(0xFF0284C7);
    } else if (widget.role == 'management') {
      roleTitle = 'Management';
      roleIcon = Icons.groups_rounded;
      roleBgColor = const Color(0xFFDCFCE7);
      roleAccentColor = const Color(0xFF16A34A);
    }

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
                    // 1. TOP CURVED GRADIENT HEADER WITH BACK BUTTON & LOGO
                    _buildTopHeader(context),

                    // 2. MAIN LOGIN FORM CONTAINER
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
                                const SizedBox(height: 8),

                                // Role Badge & Header
                                _buildAnimatedItem(
                                  startVal: 0.0,
                                  endVal: 0.45,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Role Badge Pill
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: roleBgColor,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: roleAccentColor.withValues(alpha: 0.25),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              roleIcon,
                                              size: 16,
                                              color: roleAccentColor,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$roleTitle Portal',
                                              style: TextStyle(
                                                color: roleAccentColor,
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(height: 10),

                                      // Title
                                      Text(
                                        '$roleTitle Login',
                                        style: TextStyle(
                                          fontSize: isTall ? 28 : 25,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF0F172A),
                                          letterSpacing: -0.6,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Enter your credentials to continue',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 18),

                                // Form Card
                                _buildAnimatedItem(
                                  startVal: 0.2,
                                  endVal: 0.7,
                                  child: Container(
                                    padding: const EdgeInsets.all(22),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(22),
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
                                      ],
                                    ),
                                    child: Form(
                                      key: _formKey,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Email / Roll Number Field
                                          Text(
                                            widget.role == 'student'
                                                ? 'Roll Number'
                                                : widget.role == 'driver'
                                                    ? 'Mobile Number'
                                                    : 'Email Address',
                                            style: const TextStyle(
                                              color: Color(0xFF334155),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _emailController,
                                            keyboardType: widget.role == 'student'
                                                ? TextInputType.text
                                                : widget.role == 'driver'
                                                    ? TextInputType.phone
                                                    : TextInputType.emailAddress,
                                            textInputAction: TextInputAction.next,
                                            onFieldSubmitted: (_) {
                                              FocusScope.of(context).requestFocus(_passwordFocusNode);
                                            },
                                            validator: (val) {
                                              if (val == null || val.trim().isEmpty) {
                                                return widget.role == 'student'
                                                    ? 'Please enter your roll number'
                                                    : widget.role == 'driver'
                                                        ? 'Please enter your mobile number'
                                                        : 'Please enter your email';
                                              }
                                              return null;
                                            },
                                            decoration: InputDecoration(
                                              hintText: widget.role == 'student'
                                                  ? 'Enter your roll number'
                                                  : widget.role == 'driver'
                                                      ? 'Enter registered mobile number'
                                                      : 'Enter your email address',
                                              hintStyle: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 14,
                                              ),
                                              prefixIcon: Icon(
                                                widget.role == 'student'
                                                    ? Icons.badge_rounded
                                                    : widget.role == 'driver'
                                                        ? Icons.phone_rounded
                                                        : Icons.email_rounded,
                                                color: const Color(0xFFFF6A2A),
                                                size: 20,
                                              ),
                                              filled: true,
                                              fillColor: const Color(0xFFF8FAFC),
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFFF6A2A),
                                                  width: 1.8,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 16),

                                          // Password / DOB / 6-Digit PIN Field
                                          Text(
                                            widget.role == 'student'
                                                ? 'Date of Birth (DDMMYYYY)'
                                                : widget.role == 'driver'
                                                    ? '6-Digit PIN'
                                                    : 'Password',
                                            style: const TextStyle(
                                              color: Color(0xFF334155),
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _passwordController,
                                            obscureText: _obscurePassword,
                                            keyboardType: (widget.role == 'student' || widget.role == 'driver')
                                                ? TextInputType.number
                                                : TextInputType.text,
                                            focusNode: _passwordFocusNode,
                                            textInputAction: TextInputAction.done,
                                            onFieldSubmitted: (_) => _performLogin(),
                                            validator: (val) {
                                              if (val == null || val.isEmpty) {
                                                return widget.role == 'student'
                                                    ? 'Please enter your date of birth'
                                                    : widget.role == 'driver'
                                                        ? 'Please enter your 6-digit PIN'
                                                        : 'Please enter your password';
                                              }
                                              return null;
                                            },
                                            decoration: InputDecoration(
                                              hintText: widget.role == 'student'
                                                  ? 'Enter Date of Birth (DDMMYYYY)'
                                                  : widget.role == 'driver'
                                                      ? 'Enter 6-digit PIN'
                                                      : 'Enter your password',
                                              hintStyle: const TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 14,
                                              ),
                                              prefixIcon: Icon(
                                                widget.role == 'student'
                                                    ? Icons.calendar_today_rounded
                                                    : widget.role == 'driver'
                                                        ? Icons.pin_rounded
                                                        : Icons.lock_rounded,
                                                color: const Color(0xFFFF6A2A),
                                                size: 20,
                                              ),
                                              suffixIcon: IconButton(
                                                icon: Icon(
                                                  _obscurePassword
                                                    ? Icons.visibility_off_rounded
                                                    : Icons.visibility_rounded,
                                                  color: const Color(0xFF94A3B8),
                                                  size: 20,
                                                ),
                                                onPressed: () {
                                                  setState(() {
                                                    _obscurePassword = !_obscurePassword;
                                                  });
                                                },
                                              ),
                                              filled: true,
                                              fillColor: const Color(0xFFF8FAFC),
                                              contentPadding: const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 14,
                                              ),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFE2E8F0),
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(14),
                                                borderSide: const BorderSide(
                                                  color: Color(0xFFFF6A2A),
                                                  width: 1.8,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 22),

                                          // Action Button (Login)
                                          auth.isLoading
                                              ? const Center(
                                                  child: Padding(
                                                    padding: EdgeInsets.symmetric(vertical: 12),
                                                    child: CircularProgressIndicator(
                                                      valueColor: AlwaysStoppedAnimation<Color>(
                                                        Color(0xFFFF521B),
                                                      ),
                                                    ),
                                                  ),
                                                )
                                              : Container(
                                                  width: double.infinity,
                                                  height: 52,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(14),
                                                    gradient: const LinearGradient(
                                                      colors: [
                                                        Color(0xFFFF521B),
                                                        Color(0xFFFF7E26),
                                                      ],
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: const Color(0xFFFF521B).withValues(alpha: 0.35),
                                                        blurRadius: 14,
                                                        offset: const Offset(0, 6),
                                                      ),
                                                    ],
                                                  ),
                                                  child: ElevatedButton(
                                                    onPressed: _performLogin,
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: Colors.transparent,
                                                      shadowColor: Colors.transparent,
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius: BorderRadius.circular(14),
                                                      ),
                                                    ),
                                                    child: const Text(
                                                      'Sign In',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w800,
                                                        color: Colors.white,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    // 3. BOTTOM CAMPUS ILLUSTRATION & TAGLINE
                    _buildAnimatedItem(
                      startVal: 0.5,
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
  // TOP CURVED GRADIENT HEADER (With Back Button + Brand Logo)
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

          // Header Content
          Positioned(
            top: topPadding + 12,
            left: 12,
            right: 24,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Sleek Back Button
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else {
                      Navigator.of(context).pushReplacement(
                        FadeSlidePageRoute(child: const RoleSelectScreen()),
                      );
                    }
                  },
                ),
                const SizedBox(width: 4),

                // Mavio App Logo
                Image.asset(
                  'logo.png',
                  width: 52,
                  height: 52,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.location_on_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
                const SizedBox(width: 12),

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
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.8,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your Journey, Always in Sight.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 13.5,
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
  // BOTTOM CAMPUS SECTION (Anchored at bottom)
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
    mainWavePath.cubicTo(
      w * 0.25,
      h + 8,
      w * 0.55,
      h - 32,
      w * 0.82,
      h - 44,
    );
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
