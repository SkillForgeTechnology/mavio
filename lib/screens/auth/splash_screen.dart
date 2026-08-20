import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/theme.dart';
import '../landing_page.dart';
import 'org_code_screen.dart';
import '../student/student_dashboard.dart';
import '../driver/driver_dashboard.dart';
import '../management/admin_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSessionAndNavigate();
    });
  }

  Future<void> _checkSessionAndNavigate() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    await auth.initialize();
    
    if (!mounted) return;

    if (kIsWeb) {
      // If the web browser is requesting a deep-link path (like /admin or /privacy),
      // we bypass the landing page redirect so that the router resolves it correctly.
      final String path = Uri.base.path;
      if (path != '/' && path.isNotEmpty) {
        return;
      }
      
      // Web always lands on the Landing Page first, even if already logged in.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MavioLandingPage()),
      );
    } else {
      // Mobile automatically logs in and routes to dashboard if session exists.
      if (auth.isAuthenticated) {
        final role = auth.currentProfile?.role;
        if (role == 'student') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const StudentDashboard()),
          );
        } else if (role == 'driver') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const DriverDashboard()),
          );
        } else if (role == 'management') {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        }
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OrgCodeScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Bottom Soft Orange/Peach Waves
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomPaint(
              size: Size(MediaQuery.of(context).size.width, 240),
              painter: WavePainter(),
            ),
          ),
          
          // Centered branding elements
          Center(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo container
                  Image.asset(
                    'logo.png',
                    width: 120,
                    height: 120,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  // MAVIO Text
                  Text(
                    'MAVIO',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Tagline
                  Text(
                    'Your Journey, Always in Sight.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter to draw clean bottom waves
class WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primaryLight.withOpacity(0.5)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..quadraticBezierTo(
        size.width * 0.25, size.height * 0.35,
        size.width * 0.5, size.height * 0.5,
      )
      ..quadraticBezierTo(
        size.width * 0.75, size.height * 0.65,
        size.width, size.height * 0.45,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, paint);

    final paint2 = Paint()
      ..color = AppColors.primaryLight
      ..style = PaintingStyle.fill;

    final path2 = Path()
      ..moveTo(0, size.height * 0.6)
      ..quadraticBezierTo(
        size.width * 0.3, size.height * 0.5,
        size.width * 0.6, size.height * 0.65,
      )
      ..quadraticBezierTo(
        size.width * 0.85, size.height * 0.75,
        size.width, size.height * 0.6,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
