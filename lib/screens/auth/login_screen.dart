import 'dart:math';
import 'dart:ui';
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

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _performLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    String emailInput = _emailController.text.trim();
    if (widget.role == 'student' && !emailInput.contains('@')) {
      emailInput = '$emailInput@mavio.student';
    }

    final success = await auth.login(
      emailInput,
      _passwordController.text,
      widget.role,
    );

    if (!mounted) return;

    if (success) {
      // Navigate to correct dashboard and clear routing stack
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

  void _performRegister() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    String emailInput = _emailController.text.trim();
    if (widget.role == 'student' && !emailInput.contains('@')) {
      emailInput = '$emailInput@mavio.student';
    }

    final success = await auth.register(
      emailInput,
      _passwordController.text,
      widget.role,
    );

    if (!mounted) return;

    if (success) {
      AppToast.show(
        context,
        'Account created successfully! Logging in...',
        isError: false,
      );
      _performLogin();
    } else {
      AppToast.show(
        context,
        auth.error ?? 'Registration failed',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    String roleTitle = 'Student';
    if (widget.role == 'driver') roleTitle = 'Driver';
    if (widget.role == 'management') roleTitle = 'Management';

    return Scaffold(
      backgroundColor: AppColors.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
          ),
          child: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppColors.textPrimary,
              size: 20,
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
        ),
      ),
      body: Stack(
        children: [
          // Slow moving background gradients
          const Positioned.fill(child: _LiquidBackground()),

          // Looping soft network nodes background
          const Positioned.fill(child: _MavioNetworkBg()),

          // Main Login Content
          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16.0,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Floating glowing app logo
                      const _FadeIn(delayMs: 100, child: _GlowingLogo()),
                      const SizedBox(height: 32),

                      // Glassmorphism form container card
                      _FadeIn(
                        delayMs: 200,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 32,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 32,
                                offset: const Offset(0, 16),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Title Header
                                Text(
                                  '$roleTitle Login',
                                  style: const TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Enter your credentials to continue to MAVIO.',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Email/Roll Number Input field
                                Text(
                                  widget.role == 'student'
                                      ? 'Roll Number'
                                      : 'Email Address',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _emailController,
                                  keyboardType: widget.role == 'student'
                                      ? TextInputType.text
                                      : TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  onFieldSubmitted: (_) {
                                    FocusScope.of(context).requestFocus(_passwordFocusNode);
                                  },
                                  validator: (val) {
                                    if (val == null || val.trim().isEmpty) {
                                      return widget.role == 'student'
                                          ? 'Please enter your roll number'
                                          : 'Please enter your email';
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: widget.role == 'student'
                                        ? 'Enter your roll number'
                                        : 'Enter your email address',
                                    prefixIcon: Icon(
                                      widget.role == 'student'
                                          ? Icons.badge_rounded
                                          : Icons.email_rounded,
                                      color: AppColors.primary,
                                    ),
                                    fillColor: Colors.white.withOpacity(0.5),
                                    filled: true,
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Password/DOB Input field
                                Text(
                                  widget.role == 'student'
                                      ? 'Date of Birth'
                                      : 'Password',
                                  style: const TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  focusNode: _passwordFocusNode,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => _performLogin(),
                                  validator: (val) {
                                    if (val == null || val.isEmpty) {
                                      return widget.role == 'student'
                                          ? 'Please enter your date of birth'
                                          : 'Please enter your password';
                                    }
                                    return null;
                                  },
                                  decoration: InputDecoration(
                                    hintText: widget.role == 'student'
                                        ? 'Enter Date of Birth (DDMMYYYY)'
                                        : 'Enter your password',
                                    prefixIcon: Icon(
                                      widget.role == 'student'
                                          ? Icons.calendar_today_rounded
                                          : Icons.lock_rounded,
                                      color: AppColors.primary,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    fillColor: Colors.white.withOpacity(0.5),
                                    filled: true,
                                  ),
                                ),
                                const SizedBox(height: 20),



                                // Action Buttons
                                auth.isLoading
                                    ? const Center(
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                          child: CircularProgressIndicator(
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  AppColors.primary,
                                                ),
                                          ),
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          ElevatedButton(
                                            onPressed: _performLogin,
                                            style: ElevatedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 16,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                              ),
                                              backgroundColor:
                                                  AppColors.primary,
                                              elevation: 4,
                                              shadowColor: AppColors.primary
                                                  .withOpacity(0.3),
                                            ),
                                            child: const Text(
                                              'Login',
                                              style: TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),

                                        ],
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
        ],
      ),
    );
  }
}

// =========================================================================
// WIDGET: LIQUID ANIMATED BACKGROUND
// =========================================================================
class _LiquidBackground extends StatefulWidget {
  const _LiquidBackground();

  @override
  State<_LiquidBackground> createState() => _LiquidBackgroundState();
}

class _LiquidBackgroundState extends State<_LiquidBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Stack(
      children: [
        // Background color fill
        Positioned.fill(child: Container(color: Colors.white)),

        // Floating Blob 1
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double anim = _controller.value * 2 * pi;
            return Positioned(
              top: size.height * 0.1 + 80 * sin(anim),
              left: -50 + 60 * cos(anim),
              child: child!,
            );
          },
          child: Container(
            width: size.width * 0.7,
            height: size.width * 0.7,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Floating Blob 2
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double anim = _controller.value * 2 * pi;
            return Positioned(
              bottom: size.height * 0.15 + 90 * cos(anim + 1.8),
              right: -80 + 70 * sin(anim + 1.8),
              child: child!,
            );
          },
          child: Container(
            width: size.width * 0.8,
            height: size.width * 0.8,
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Floating Blob 3
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final double anim = _controller.value * 2 * pi;
            return Positioned(
              top: size.height * 0.45 + 100 * sin(anim * 0.8 + 2.5),
              right: size.width * 0.2 + 80 * cos(anim * 0.8 + 2.5),
              child: child!,
            );
          },
          child: Container(
            width: size.width * 0.5,
            height: size.width * 0.5,
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
          ),
        ),

        // Heavy Blur BackdropFilter
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
            child: Container(color: Colors.transparent),
          ),
        ),
      ],
    );
  }
}

// =========================================================================
// WIDGET: FLOATING LOGO
// =========================================================================
class _GlowingLogo extends StatefulWidget {
  const _GlowingLogo();

  @override
  State<_GlowingLogo> createState() => _GlowingLogoState();
}

class _GlowingLogoState extends State<_GlowingLogo>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, -6 + 12 * _controller.value),
          child: child,
        );
      },
      child: Center(
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.18),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(
            Icons.directions_bus_rounded,
            color: AppColors.primary,
            size: 34,
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// WIDGET: FADE-IN WRAPPER
// =========================================================================
class _FadeIn extends StatefulWidget {
  final Widget child;
  final int delayMs;

  const _FadeIn({required this.child, required this.delayMs});

  @override
  State<_FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<_FadeIn> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _slide = Tween<double>(
      begin: 24.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _slide.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// =========================================================================
// WIDGET: SLOW FLOAT/PULSE MAVIO NETWORK BACKGROUND LAYER
// =========================================================================
class _MavioNetworkBg extends StatefulWidget {
  const _MavioNetworkBg();

  @override
  State<_MavioNetworkBg> createState() => _MavioNetworkBgState();
}

class _MavioNetworkBgState extends State<_MavioNetworkBg> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _NetworkPainter(_controller.value),
          child: Container(),
        );
      },
    );
  }
}

class _NetworkPainter extends CustomPainter {
  final double progress;

  _NetworkPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // Define 6 nodes representing coordinates on a map
    final List<Offset> nodes = [
      Offset(width * 0.15, height * 0.25 + (20 * progress)),
      Offset(width * 0.85, height * 0.15 - (15 * progress)),
      Offset(width * 0.35, height * 0.75 + (25 * progress)),
      Offset(width * 0.75, height * 0.65 - (20 * progress)),
      Offset(width * 0.50, height * 0.45 + (10 * progress)),
      Offset(width * 0.25, height * 0.55 - (30 * progress)),
    ];

    // Paint for lines
    final linePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.04)
      ..strokeWidth = 1.2;

    // Paint for nodes
    final nodePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.07)
      ..style = PaintingStyle.fill;

    // Draw lines between nearby nodes
    for (int i = 0; i < nodes.length; i++) {
      for (int j = i + 1; j < nodes.length; j++) {
        canvas.drawLine(nodes[i], nodes[j], linePaint);
      }
    }

    // Draw nodes
    for (final node in nodes) {
      canvas.drawCircle(node, 6, nodePaint);
      canvas.drawCircle(node, 14, Paint()..color = AppColors.primary.withOpacity(0.02)..style = PaintingStyle.fill);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
