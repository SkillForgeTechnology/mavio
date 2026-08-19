import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/theme.dart';
import 'auth/org_code_screen.dart';

class MavioLandingPage extends StatefulWidget {
  const MavioLandingPage({super.key});

  @override
  State<MavioLandingPage> createState() => _MavioLandingPageState();
}

class _MavioLandingPageState extends State<MavioLandingPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _featuresKey = GlobalKey();

  void _scrollToFeatures() {
    final context = _featuresKey.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    }
  }

  void _navigateToLogin() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OrgCodeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Column(
          children: [
            // 1. Navigation Bar
            _buildNavBar(isDesktop),

            // 2. Hero Section
            _buildHero(isDesktop, screenWidth),

            // 3. Features Section (Keyed for scrolling)
            Container(
              key: _featuresKey,
              child: _buildFeaturesSection(isDesktop),
            ),

            // 4. Performance Metrics Section
            _buildMetricsSection(isDesktop),

            // 5. How It Works Section
            _buildHowItWorksSection(isDesktop),

            // 5. Technology Partner Section
            _buildPartnerSection(isDesktop),

            // 6. Footer Section
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // Navigation Bar Widget
  Widget _buildNavBar(bool isDesktop) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: AppColors.borderLight, width: 0.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo & Branding
          Row(
            children: [
              Image.asset('logo.png', height: 40),
              const SizedBox(width: 12),
              const Text(
                'MAVIO',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),

          // Center menu links (Only on Desktop)
          if (isDesktop)
            Row(
              children: [
                _buildNavLink('Home', () {}),
                _buildNavLink('Features', _scrollToFeatures),
                _buildNavLink('About Campus', () {}),
              ],
            ),

          // CTA Action Button
          ElevatedButton(
            onPressed: _navigateToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              minimumSize: const Size(0, 48), // Overrides global double.infinity width
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 2,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Launch Portal',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavLink(String title, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InkWell(
        onTap: onTap,
        child: Text(
          title,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  // Hero Section
  Widget _buildHero(bool isDesktop, double screenWidth) {
    final double textWidth = isDesktop ? screenWidth * 0.45 : screenWidth;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withOpacity(0.03),
            Colors.white,
          ],
        ),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: isDesktop ? 80 : 40,
      ),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Text Column
                SizedBox(
                  width: textWidth,
                  child: _buildHeroTextContent(isDesktop),
                ),
                // Vector Graphic Container
                Expanded(
                  child: Stack(
                    alignment: Alignment.centerRight,
                    children: [
                      // Orange Wave background
                      CustomPaint(
                        size: const Size(500, 360),
                        painter: _HeroWavePainter(),
                      ),
                      // Floating Bus sticker
                      Positioned(
                        right: 20,
                        bottom: 40,
                        child: SizedBox(
                          width: 440,
                          height: 280,
                          child: Image.asset(
                            'mavio_bus.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _buildHeroTextContent(isDesktop),
                const SizedBox(height: 40),
                // Mobile layout graphic
                Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(screenWidth * 0.85, 240),
                      painter: _HeroWavePainter(),
                    ),
                    SizedBox(
                      width: screenWidth * 0.8,
                      height: 180,
                      child: Image.asset(
                        'mavio_bus.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _buildHeroTextContent(bool isDesktop) {
    return Column(
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.stars, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Next-Gen Transit Management System',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Smart College Transit,\nReimagined.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 54 : 36,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            height: 1.15,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Track campus buses in real-time, get immediate arrival notifications, and streamline driver assignments with our clean administrative web control panel.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment:
              isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _navigateToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 18,
                ),
                minimumSize: const Size(0, 56), // Overrides global double.infinity width
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Enter Portal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: _scrollToFeatures,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border, width: 1.5),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 18,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Learn More',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Features Grid
  Widget _buildFeaturesSection(bool isDesktop) {
    return Container(
      color: AppColors.surface,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      child: Column(
        children: [
          const Text(
            'App Highlights',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Core Operational Pillars',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 600,
            child: Text(
              'Mavio delivers reliable tracking, safety compliance, and streamlined schedules directly to administrative and student portals.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.6),
            ),
          ),
          const SizedBox(height: 56),

          // Features Cards Layout
          isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: _buildFeatureCard(
                        Icons.map_rounded,
                        'Live GPS Tracking',
                        'Never guess vehicle ETAs. Students see active map nodes, live speeds, and custom road/satellite configurations.',
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildFeatureCard(
                        Icons.notifications_active_rounded,
                        'Intelligent Alerts',
                        'Mavio notifies student devices automatically when a driver starts a route, maintaining secure transit communication.',
                      ),
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: _buildFeatureCard(
                        Icons.admin_panel_settings_rounded,
                        'Central Administration',
                        'Import registers dynamically, map drivers, manage schedules, and review logs inside a responsive dashboard.',
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildFeatureCard(
                      Icons.map_rounded,
                      'Live GPS Tracking',
                      'Never guess vehicle ETAs. Students see active map nodes, live speeds, and custom road/satellite configurations.',
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      Icons.notifications_active_rounded,
                      'Intelligent Alerts',
                      'Mavio notifies student devices automatically when a driver starts a route, maintaining secure transit communication.',
                    ),
                    const SizedBox(height: 20),
                    _buildFeatureCard(
                      Icons.admin_panel_settings_rounded,
                      'Central Administration',
                      'Import registers dynamically, map drivers, manage schedules, and review logs inside a responsive dashboard.',
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: 110,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 28),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  desc,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
        ],
      ),
    );
  }

  // How It Works
  Widget _buildHowItWorksSection(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      child: Column(
        children: [
          const Text(
            '3-Step Setup',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'How it Works',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 56),
          isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildStepItem(
                        '1',
                        'Organization Code',
                        'Launch portal and enter your designated organization verification code.',
                      ),
                    ),
                    Expanded(
                      child: _buildStepItem(
                        '2',
                        'Log In',
                        'Students and drivers authenticate securely using institutional profiles.',
                      ),
                    ),
                    Expanded(
                      child: _buildStepItem(
                        '3',
                        'Track & Drive',
                        'Drivers publish GPS telemetry with a click, and students lock onto live map locations.',
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildStepItem(
                      '1',
                      'Organization Code',
                      'Launch portal and enter your designated organization verification code.',
                    ),
                    const SizedBox(height: 32),
                    _buildStepItem(
                      '2',
                      'Log In',
                      'Students and drivers authenticate securely using institutional profiles.',
                    ),
                    const SizedBox(height: 32),
                    _buildStepItem(
                      '3',
                      'Track & Drive',
                      'Drivers publish GPS telemetry with a click, and students lock onto live map locations.',
                    ),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String step, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            child: Text(
              step,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
  }

  // Metrics Section
  Widget _buildMetricsSection(bool isDesktop) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      child: Column(
        children: [
          const Text(
            'PERFORMANCE METRICS',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Engineered for Scale and Latency',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 56),
          isDesktop
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(child: _buildMetricCard('99.9%', 'System Uptime', 'Cloud orchestration ensures 24/7 route discovery.')),
                    const SizedBox(width: 24),
                    Expanded(child: _buildMetricCard('< 3s', 'Telemetry Latency', 'Real-time database updates for active tracking.')),
                    const SizedBox(width: 24),
                    Expanded(child: _buildMetricCard('10k+', 'Daily Synchronizations', 'Providing high-concurrency bus locations.')),
                    const SizedBox(width: 24),
                    Expanded(child: _buildMetricCard('Zero', 'Hardware Overhead', 'Track location via smartphones without GPS boxes.')),
                  ],
                )
              : Column(
                  children: [
                    _buildMetricCard('99.9%', 'System Uptime', 'Cloud orchestration ensures 24/7 route discovery.'),
                    const SizedBox(height: 20),
                    _buildMetricCard('< 3s', 'Telemetry Latency', 'Real-time database updates for active tracking.'),
                    const SizedBox(height: 20),
                    _buildMetricCard('10k+', 'Daily Synchronizations', 'Providing high-concurrency bus locations.'),
                    const SizedBox(height: 20),
                    _buildMetricCard('Zero', 'Hardware Overhead', 'Track location via smartphones without GPS boxes.'),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildMetricCard(String value, String title, String desc) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFBFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.0),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Partner Branding Section
  Widget _buildPartnerSection(bool isDesktop) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFBFBFC),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 64,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'A PRODUCT OF SKILLFORGE TECHNOLOGY',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'MAVIO is a Product of SkillForge Technology',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 20),
          Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: const Text(
              'MAVIO is designed, engineered, and built by SkillForge Technology. '
              'By leveraging SkillForge\'s advanced enterprise telemetry servers, real-time sync systems, '
              'and location intelligence mapping engines, we provide colleges and organizations with reliable, '
              'high-accuracy bus tracking services that scale seamlessly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 36),
          Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.borderLight, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'company-logo.png',
                  height: 36,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),
                const Text(
                  'SkillForge Technology',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Building Next-Generation Digital Experiences',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    final url = Uri.parse('https://skillforgetechnology.app/');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    minimumSize: const Size(180, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Visit SkillForge site',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.open_in_new_rounded, size: 16),
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

  // Footer
  Widget _buildFooter() {
    return Container(
      color: AppColors.textPrimary,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      width: double.infinity,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('logo.png', height: 32),
              const SizedBox(width: 8),
              const Text(
                'MAVIO',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                '© 2026 MAVIO Smart College Transit. All Rights Reserved. A product of ',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              Image.asset(
                'company-logo.png',
                height: 14,
                fit: BoxFit.contain,
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              Navigator.of(context).pushNamed('/privacy');
            },
            child: const Text(
              'Privacy Policy',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Hero background custom painter to draw orange gradient curves
class _HeroWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final Paint paint1 = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withOpacity(0.15),
          AppColors.primary.withOpacity(0.01),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path1 = Path();
    path1.moveTo(w * 0.1, h * 0.5);
    path1.cubicTo(w * 0.3, h * 0.1, w * 0.7, h * 0.9, w * 0.9, h * 0.4);
    path1.cubicTo(w * 0.95, h * 0.25, w * 0.98, h * 0.1, w, 0);
    path1.lineTo(w, h);
    path1.lineTo(0, h);
    path1.close();
    canvas.drawPath(path1, paint1);

    final Paint paint2 = Paint()
      ..shader = LinearGradient(
        colors: [
          AppColors.primary.withOpacity(0.08),
          AppColors.primary.withOpacity(0.0),
        ],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path2 = Path();
    path2.moveTo(0, h * 0.7);
    path2.cubicTo(w * 0.2, h * 0.55, w * 0.4, h * 0.85, w * 0.7, h * 0.6);
    path2.lineTo(w, h);
    path2.lineTo(0, h);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
