import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/theme.dart';
import '../../providers/auth_provider.dart';
import 'auth/org_code_screen.dart';
import 'student/student_dashboard.dart';
import 'driver/driver_dashboard.dart';
import 'management/admin_dashboard.dart';

class MavioLandingPage extends StatefulWidget {
  const MavioLandingPage({super.key});

  @override
  State<MavioLandingPage> createState() => _MavioLandingPageState();
}

class _MavioLandingPageState extends State<MavioLandingPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _techKey = GlobalKey();

  double _scrollOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      setState(() {
        _scrollOffset = _scrollController.offset;
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSection(GlobalKey key) {
    final context = key.currentContext;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        duration: const Duration(seconds: 1),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _navigateToLogin() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      final role = auth.currentProfile?.role;
      if (role == 'student') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StudentDashboard()),
        );
      } else if (role == 'driver') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DriverDashboard()),
        );
      } else if (role == 'management') {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AdminDashboard()),
        );
      }
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const OrgCodeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Background Decorative Gradients
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.04),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          Positioned(
            top: 400,
            right: -200,
            child: Container(
              width: 600,
              height: 600,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF8A65).withOpacity(0.03),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Scrollable Content
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  // Space to account for fixed/sticky navbar
                  SizedBox(height: isDesktop ? 90 : 76),

                  // 1. Hero Section
                  _buildHero(isDesktop, screenWidth),

                  // 2. Metrics Section
                  _buildMetricsSection(isDesktop),

                  // 3. Main Pillars Showcase (Alternate Rows)
                  Container(
                    key: _featuresKey,
                    child: _buildShowcaseSection(isDesktop, screenWidth),
                  ),

                  // 4. Highlight Highlights (Core features grid)
                  _buildCoreHighlights(isDesktop),

                  // 5. Technology Architecture Section
                  Container(
                    key: _techKey,
                    child: _buildTechSection(isDesktop, screenWidth),
                  ),

                  // 6. Footer Section
                  _buildFooter(),
                ],
              ),
            ),
          ),

          // Sticky Glassmorphic Navbar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildNavBar(isDesktop),
          ),
        ],
      ),
    );
  }

  // Navigation Bar Widget (Glassmorphic)
  Widget _buildNavBar(bool isDesktop) {
    final bool isScrolled = _scrollOffset > 20;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: isScrolled ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isScrolled ? 0.8 : 1.0),
        border: Border(
          bottom: BorderSide(
            color: isScrolled ? AppColors.borderLight.withOpacity(0.5) : AppColors.borderLight,
            width: 0.8,
          ),
        ),
        boxShadow: isScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: isScrolled ? 15.0 : 0.0,
            sigmaY: isScrolled ? 15.0 : 0.0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Logo
              Row(
                children: [
                  Image.asset('logo.png', height: 38),
                  const SizedBox(width: 12),
                  const Text(
                    'MAVIO',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w955,
                      color: AppColors.primary,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),

              // Nav items (Desktop)
              if (isDesktop)
                Row(
                  children: [
                    _buildNavLink('Overview', () => _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeInOut)),
                    _buildNavLink('Features', () => _scrollToSection(_featuresKey)),
                    _buildNavLink('Architecture', () => _scrollToSection(_techKey)),
                  ],
                ),

              // Launch Button
              ElevatedButton(
                onPressed: _navigateToLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: isScrolled ? 2 : 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Row(
                  children: [
                    Text(
                      'Launch Portal',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavLink(String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // Hero Section
  Widget _buildHero(bool isDesktop, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: isDesktop ? 96 : 48,
      ),
      child: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Text Description
                Expanded(
                  flex: 12,
                  child: _EntranceAnimator(
                    child: _buildHeroTextContent(isDesktop),
                  ),
                ),
                const Spacer(flex: 1),

                // Floating Mockups Showcase
                Expanded(
                  flex: 14,
                  child: _EntranceAnimator(
                    delay: const Duration(milliseconds: 200),
                    child: SizedBox(
                      height: 520,
                      child: Stack(
                        alignment: Alignment.centerRight,
                        children: [
                          // Background design bubble
                          Positioned(
                            right: 40,
                            top: 40,
                            child: Container(
                              width: 320,
                              height: 320,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.primary.withOpacity(0.2),
                                    AppColors.primary.withOpacity(0.0),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          // Driver App mockup (Floats left/back)
                          Positioned(
                            left: 0,
                            bottom: 20,
                            child: _FloatingWidget(
                              duration: const Duration(milliseconds: 2800),
                              offset: 15.0,
                              child: _PhoneFrame(
                                assetPath: 'assets/driver.png',
                                height: 410,
                              ),
                            ),
                          ),

                          // Student App mockup (Floats right/foreground)
                          Positioned(
                            right: 30,
                            top: 20,
                            child: _FloatingWidget(
                              duration: const Duration(milliseconds: 2400),
                              offset: -12.0,
                              child: _PhoneFrame(
                                assetPath: 'assets/home.png',
                                height: 440,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                _EntranceAnimator(child: _buildHeroTextContent(isDesktop)),
                const SizedBox(height: 56),

                // Staggered stack for mobile layouts
                _EntranceAnimator(
                  delay: const Duration(milliseconds: 150),
                  child: SizedBox(
                    height: 380,
                    width: screenWidth,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned(
                          left: screenWidth * 0.05,
                          child: _FloatingWidget(
                            offset: 10.0,
                            child: _PhoneFrame(
                              assetPath: 'assets/driver.png',
                              height: 300,
                            ),
                          ),
                        ),
                        Positioned(
                          right: screenWidth * 0.05,
                          child: _FloatingWidget(
                            offset: -10.0,
                            child: _PhoneFrame(
                              assetPath: 'assets/home.png',
                              height: 320,
                            ),
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

  Widget _buildHeroTextContent(bool isDesktop) {
    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.stars_rounded, color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Text(
                'Proprietary Smart Transit Solution',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Smart Campus Transit\nReimagined.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 54 : 36,
            fontWeight: FontWeight.w950,
            color: AppColors.textPrimary,
            height: 1.15,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Mavio orchestrates live telemetry, background location streams, and secure route tracking onto interactive student and driver dashboards. Built for speed, precision, and privacy.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 36),
        Row(
          mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _navigateToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Enter Portal',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
            const SizedBox(width: 16),
            OutlinedButton(
              onPressed: () => _scrollToSection(_featuresKey),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Explore Features',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Metrics Section (Static/Premium blocks)
  Widget _buildMetricsSection(bool isDesktop) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 60),
      child: isDesktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetricItem('2.1s', 'Location Refresh Frequency', 'Instant coordinates updates sync via Supabase websockets.'),
                _buildMetricItem('99.9%', 'Telemetry Accuracy', 'Fine-grained location filters remove GPS noise instantly.'),
                _buildMetricItem('100%', 'Privacy Compliance', 'Profile deletions execute instant cascading purges of location logs.'),
              ],
            )
          : Column(
              children: [
                _buildMetricItem('2.1s', 'Location Refresh Frequency', 'Instant coordinates updates sync via Supabase websockets.'),
                const SizedBox(height: 32),
                _buildMetricItem('99.9%', 'Telemetry Accuracy', 'Fine-grained location filters remove GPS noise.'),
                const SizedBox(height: 32),
                _buildMetricItem('100%', 'Privacy Compliance', 'Profile deletions execute cascading log purges.'),
              ],
            ),
    );
  }

  Widget _buildMetricItem(String value, String title, String desc) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w950,
            color: AppColors.primary,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          width: 250,
          child: Text(
            desc,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // Alternating Pillars Showcase
  Widget _buildShowcaseSection(bool isDesktop, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 80),
      child: Column(
        children: [
          // Section Header
          Center(
            child: Column(
              children: [
                Text(
                  'SYSTEM PILLARS',
                  style: TextStyle(
                    color: AppColors.primary.withOpacity(0.8),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'End-to-End Transit Orchestration',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                const SizedBox(
                  width: 600,
                  child: Text(
                    'Mavio splits operations into targeted components optimized for drivers, students, and administration administrators.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.textSecondary, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),

          // Row 1: Student App (Mockup on Right)
          _buildShowcaseRow(
            isDesktop,
            '01',
            'Student Real-Time Tracking',
            'Plan commute routes precisely. Students check active map pins, view details on bus speed, and see vehicle registrations in custom split details modules.',
            'assets/home.png',
            true,
          ),
          const SizedBox(height: 100),

          // Row 2: Driver App (Mockup on Left)
          _buildShowcaseRow(
            isDesktop,
            '02',
            'Driver Background Telemetry',
            'Start live coordinates tracking with a single tap. The battery-optimized location isolate tracks positions in the background even if the app gets cleared from recents.',
            'assets/driver.png',
            false,
          ),
          const SizedBox(height: 100),

          // Row 3: Admin Console (Mockup on Right)
          _buildShowcaseRow(
            isDesktop,
            '03',
            'Administrative Orchestration',
            'Full management console: register fleets, audit driver assignments, inspect tracked stop schedules, and cascade deletion requests instantly.',
            'assets/3.png',
            true,
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseRow(
    bool isDesktop,
    String index,
    String title,
    String description,
    String assetPath,
    bool imageOnRight,
  ) {
    final textContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          index,
          style: TextStyle(
            fontSize: 48,
            fontWeight: FontWeight.w900,
            color: AppColors.primary.withOpacity(0.15),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          description,
          style: const TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );

    final imageContent = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(0, 15),
          )
        ],
      ),
      child: _PhoneFrame(
        assetPath: assetPath,
        height: 380,
      ),
    );

    if (!isDesktop) {
      return Column(
        children: [
          textContent,
          const SizedBox(height: 32),
          imageContent,
        ],
      );
    }

    return Row(
      children: [
        if (imageOnRight) ...[
          Expanded(flex: 5, child: textContent),
          const Spacer(flex: 1),
          Expanded(flex: 4, child: imageContent),
        ] else ...[
          Expanded(flex: 4, child: imageContent),
          const Spacer(flex: 1),
          Expanded(flex: 5, child: textContent),
        ],
      ],
    );
  }

  // Core Highlights (Feature Grid)
  Widget _buildCoreHighlights(bool isDesktop) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 80),
      child: Column(
        children: [
          const Text(
            'KEY ADVANTAGES',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Engineered for High Performance',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 56),

          isDesktop
              ? Row(
                  children: [
                    Expanded(child: _buildHighlightCard(Icons.offline_bolt_rounded, 'Speedy Data Sync', 'Supabase streaming keeps map pins moving live with latency under 100ms.')),
                    const SizedBox(width: 24),
                    Expanded(child: _buildHighlightCard(Icons.shield_rounded, 'Secure Credentials', 'Logins authenticated via encrypted client schemas keeping user profiles protected.')),
                    const SizedBox(width: 24),
                    Expanded(child: _buildHighlightCard(Icons.battery_saver_rounded, 'Isolate Telemetry', 'Separate dart task processing allows background GPS tracking without power drain.')),
                  ],
                )
              : Column(
                  children: [
                    _buildHighlightCard(Icons.offline_bolt_rounded, 'Speedy Data Sync', 'Supabase streaming keeps map pins moving live with latency under 100ms.'),
                    const SizedBox(height: 24),
                    _buildHighlightCard(Icons.shield_rounded, 'Secure Credentials', 'Logins authenticated via encrypted client schemas.'),
                    const SizedBox(height: 24),
                    _buildHighlightCard(Icons.battery_saver_rounded, 'Isolate Telemetry', 'Separate dart task processing allows background GPS tracking.'),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 0.8),
      ),
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
          const SizedBox(height: 24),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // Technology Architecture Section
  Widget _buildTechSection(bool isDesktop, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 64 : 24, vertical: 80),
      child: isDesktop
          ? Row(
              children: [
                Expanded(
                  flex: 5,
                  child: _buildTechText(),
                ),
                const Spacer(flex: 1),
                Expanded(
                  flex: 5,
                  child: _buildTechVisuals(),
                ),
              ],
            )
          : Column(
              children: [
                _buildTechText(),
                const SizedBox(height: 48),
                _buildTechVisuals(),
              ],
            ),
    );
  }

  Widget _buildTechText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'A PRODUCT OF SKILLFORGE TECHNOLOGY',
          style: TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.bold,
            fontSize: 12,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'MAVIO is a Product of SkillForge Technology',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'MAVIO is designed, engineered, and built by SkillForge Technology. '
          'By leveraging SkillForge\'s advanced enterprise telemetry servers, real-time sync systems, '
          'and location background isolates, Mavio ensures optimal tracking reliability for campuses of any size.',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Image.asset('company-logo.png', height: 26),
            const SizedBox(width: 16),
            TextButton(
              onPressed: () async {
                final url = Uri.parse('https://skillforgetechnology.app/');
                if (await canLaunchUrl(url)) {
                  await launchUrl(url);
                }
              },
              child: const Text(
                'Visit SkillForge Technology site',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTechVisuals() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.borderLight, width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTechStep('Isolate Streamer', 'Continuous background tracking isolate pushes JSON payloads.', Icons.alt_route_rounded),
          const SizedBox(height: 16),
          const Icon(Icons.arrow_downward_rounded, color: AppColors.primary, size: 24),
          const SizedBox(height: 16),
          _buildTechStep('Supabase Realtime', 'Dynamic channels broadcast live locations to active connections.', Icons.cloud_done_rounded),
          const SizedBox(height: 16),
          const Icon(Icons.arrow_downward_rounded, color: AppColors.primary, size: 24),
          const SizedBox(height: 16),
          _buildTechStep('Student Interactive Maps', 'Flutter Map displays smooth coordinates markers with minimal latency.', Icons.map_rounded),
        ],
      ),
    );
  }

  Widget _buildTechStep(String title, String desc, IconData icon) {
    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: AppColors.primary.withOpacity(0.08),
          foregroundColor: AppColors.primary,
          child: Icon(icon, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                desc,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Footer Widget
  Widget _buildFooter() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Image.asset('logo.png', height: 32),
                  const SizedBox(width: 12),
                  const Text(
                    'MAVIO',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              const Text(
                '© 2026 MAVIO by SkillForge Technology. All Rights Reserved.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(color: Colors.white10),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
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
              const SizedBox(width: 16),
              const Text(
                '•',
                style: TextStyle(color: Colors.white54, fontSize: 13),
              ),
              const SizedBox(width: 16),
              InkWell(
                onTap: () {
                  Navigator.of(context).pushNamed('/delete-account');
                },
                child: const Text(
                  'Delete Account',
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
        ],
      ),
    );
  }
}

// Repeating Floating Animation Widget
class _FloatingWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double offset;

  const _FloatingWidget({
    required this.child,
    this.duration = const Duration(milliseconds: 2500),
    this.offset = 12.0,
  });

  @override
  State<_FloatingWidget> createState() => _FloatingWidgetState();
}

class _FloatingWidgetState extends State<_FloatingWidget> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.0, end: widget.offset).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _animation.value),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

// Load-In Entrance Animator
class _EntranceAnimator extends StatefulWidget {
  final Widget child;
  final Duration delay;

  const _EntranceAnimator({
    required this.child,
    this.delay = Duration.zero,
  });

  @override
  State<_EntranceAnimator> createState() => _EntranceAnimatorState();
}

class _EntranceAnimatorState extends State<_EntranceAnimator> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    Future.delayed(widget.delay, () {
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
          opacity: _fadeAnimation.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// Phone Device Frame Wrapper
class _PhoneFrame extends StatefulWidget {
  final String assetPath;
  final double height;

  const _PhoneFrame({
    required this.assetPath,
    this.height = 420,
  });

  @override
  State<_PhoneFrame> createState() => _PhoneFrameState();
}

class _PhoneFrameState extends State<_PhoneFrame> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()
          ..translate(0.0, _isHovered ? -12.0 : 0.0, 0.0)
          ..scale(_isHovered ? 1.04 : 1.0),
        child: Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(38),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(_isHovered ? 0.22 : 0.14),
                blurRadius: _isHovered ? 45 : 25,
                offset: Offset(0, _isHovered ? 20 : 12),
              ),
              BoxShadow(
                color: AppColors.primary.withOpacity(_isHovered ? 0.22 : 0.0),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(38),
            child: Container(
              color: const Color(0xFF1E1E1E), // Matte Bezel
              padding: const EdgeInsets.all(9.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: Image.asset(
                  widget.assetPath,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
