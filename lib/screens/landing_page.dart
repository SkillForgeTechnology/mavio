import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/theme.dart';
import '../providers/auth_provider.dart';
import 'auth/org_code_screen.dart';
import 'student/student_dashboard.dart';
import 'driver/driver_dashboard.dart';
import 'management/admin_dashboard.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';

class MavioLandingPage extends StatefulWidget {
  const MavioLandingPage({super.key});

  @override
  State<MavioLandingPage> createState() => _MavioLandingPageState();
}

class _MavioLandingPageState extends State<MavioLandingPage> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _featuresKey = GlobalKey();
  final GlobalKey _techKey = GlobalKey();
  final GlobalKey _pricingKey = GlobalKey();
  final GlobalKey _faqKey = GlobalKey();

  final ValueNotifier<double> _scrollOffset = ValueNotifier<double>(0.0);
  VideoPlayerController? _videoController;
  bool _showSplash = true;
  bool _removeSplash = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      _scrollOffset.value = _scrollController.offset;
    });

    _initializeVideo();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final fragment = Uri.base.fragment.toLowerCase();
      if (fragment.isNotEmpty) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          if (fragment == 'features') {
            _scrollToSection(_featuresKey);
          } else if (fragment == 'architecture' || fragment == 'tech') {
            _scrollToSection(_techKey);
          } else if (fragment == 'pricing') {
            _scrollToSection(_pricingKey);
          } else if (fragment == 'faq') {
            _scrollToSection(_faqKey);
          }
        });
      }
    });
  }

  void _initializeVideo() {
    if (kIsWeb) {
      _videoController = VideoPlayerController.networkUrl(
        Uri.parse('hero-sec-video.mp4'),
      );
    } else {
      _videoController = VideoPlayerController.asset('assets/hero-sec-video.mp4');
    }

    // Set volume to 0.0 BEFORE initialization so browser autoplay policy doesn't block media buffering
    _videoController!.setVolume(0.0);

    _videoController!.initialize().then((_) {
      if (mounted) {
        setState(() {});
        _videoController?.setLooping(true);
        _videoController?.play().catchError((error) {
          debugPrint("Video play failed: $error");
        });
      }
    }).catchError((error) {
      debugPrint("Video initialization failed: $error");
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _scrollOffset.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('logo.png'), context);
    precacheImage(const AssetImage('company-logo.png'), context);
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

  void _showContactDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Logos Section
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('logo.png', height: 45),
                  const SizedBox(width: 20),
                  Container(
                    height: 30,
                    width: 1.5,
                    color: AppColors.border,
                  ),
                  const SizedBox(width: 20),
                  Image.asset('company-logo.png', height: 40),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Contact Our Sales & Setup Team',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Let us help you configure the real-time student visibility transit system for your institution.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              
              // Email Detail
              _buildContactItem(
                icon: Icons.email_outlined,
                title: 'Email Us',
                value: 'info@skillforgetechnology.app',
                onTap: () => launchUrl(Uri.parse('mailto:info@skillforgetechnology.app')),
              ),
              const SizedBox(height: 12),
              
              // Mobile Detail
              _buildContactItem(
                icon: Icons.phone_android_outlined,
                title: 'Mobile / Phone',
                value: '+91 93455 18760',
                onTap: () => launchUrl(Uri.parse('tel:+919345518760')),
              ),
              const SizedBox(height: 24),
              
              // Call & WhatsApp Action Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse('https://wa.me/919345518760?text=Hi%2C%20I\'m%20interested%20in%20Mavio%20Transit%20Service!'),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18, color: Colors.white),
                      label: const Text('WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:+919345518760')),
                      icon: const Icon(Icons.call_outlined, size: 18, color: Colors.white),
                      label: const Text('Call Now', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String title,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.background.withOpacity(0.04),
          border: Border.all(color: AppColors.border.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToLogin() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.isAuthenticated) {
      final role = auth.currentProfile?.role;
      if (role == 'student') {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const StudentDashboard()));
      } else if (role == 'driver') {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const DriverDashboard()));
      } else if (role == 'management') {
        Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: (_) => const AdminDashboard()));
      }
    } else {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => const OrgCodeScreen()));
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
          // Background Decorative Mesh Orbs (Gradients are hardware-accelerated and do not cause scroll lag)
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.08),
                    AppColors.primary.withOpacity(0.0),
                  ],
                ),
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
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFF8A65).withOpacity(0.06),
                    const Color(0xFFFF8A65).withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),

          // Scrollable Content
          Positioned.fill(
            child: SingleChildScrollView(
              controller: _scrollController,
              child: Column(
                children: [
                  SizedBox(height: isDesktop ? 90 : 76),

                  // 1. Redesigned Centered Hero Section (SaaS Header + Large Control Console Preview)
                  _buildHero(isDesktop, screenWidth),

                  // 2. Metrics Section
                  _buildMetricsSection(isDesktop),

                  // 3. Main Pillars Showcase (Alternate Rows with Scroll Reveal)
                  Container(
                    key: _featuresKey,
                    child: _buildShowcaseSection(isDesktop, screenWidth),
                  ),

                  // 4. Bento Feature Grid
                  _buildCoreHighlights(isDesktop),

                  // 5. Technology Architecture Section
                  Container(
                    key: _techKey,
                    child: _buildTechSection(isDesktop, screenWidth),
                  ),

                  // 6. Live Dashboard Preview Panel
                  _buildLiveOperationsPreview(isDesktop, screenWidth),

                  // 7. Pricing & Subscription Plans
                  Container(
                    key: _pricingKey,
                    child: _buildPricingSection(isDesktop),
                  ),

                  // 8. FAQ Section
                  Container(key: _faqKey, child: _buildFAQSection(isDesktop)),

                  // 9. Footer Section
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
            child: ValueListenableBuilder<double>(
              valueListenable: _scrollOffset,
              builder: (context, offset, child) {
                return _buildNavBar(isDesktop, offset);
              },
            ),
          ),

          // Premium Animated Splash Loader Overlay
          if (!_removeSplash)
            Positioned.fill(
              child: AnimatedOpacity(
                opacity: _showSplash ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
                onEnd: () {
                  if (!_showSplash) {
                    setState(() {
                      _removeSplash = true;
                    });
                  }
                },
                child: MavioSplashLoader(
                  onFinished: () {
                    setState(() {
                      _showSplash = false;
                    });
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Navigation Bar Widget (Glassmorphic)
  Widget _buildNavBar(bool isDesktop, double offset) {
    final bool isScrolled = offset > 20;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: isScrolled ? 16 : 24,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isScrolled ? 0.95 : 1.0),
        border: Border(
          bottom: BorderSide(
            color: isScrolled
                ? AppColors.borderLight.withOpacity(0.5)
                : AppColors.borderLight,
            width: 0.8,
          ),
        ),
        boxShadow: isScrolled
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : [],
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
                  fontWeight: FontWeight.w900,
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
                _buildNavLink(
                  'Overview',
                  () => _scrollController.animateTo(
                    0,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  ),
                ),
                _buildNavLink(
                  'Features',
                  () => _scrollToSection(_featuresKey),
                ),
                _buildNavLink(
                  'Architecture',
                  () => _scrollToSection(_techKey),
                ),
                _buildNavLink(
                  'Pricing',
                  () => _scrollToSection(_pricingKey),
                ),
                _buildNavLink('FAQ', () => _scrollToSection(_faqKey)),
              ],
            ),

          // Launch Button
          ElevatedButton(
            onPressed: _navigateToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 0),
              elevation: isScrolled ? 2 : 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 18,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Launch Portal',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward_rounded, size: 16),
              ],
            ),
          ),
        ],
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

  void _showAlertsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(
              Icons.notifications_active,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 10),
            const Text(
              'Mavio Live Alerts',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAlertDialogItem(
              icon: Icons.speed_rounded,
              color: Colors.orange,
              title: 'Speed Alert Cleared',
              subtitle: 'Bus 03 stabilized at 42 km/h',
              time: '2m ago',
            ),
            const Divider(height: 20),
            _buildAlertDialogItem(
              icon: Icons.route_rounded,
              color: Colors.green,
              title: 'Route Completion',
              subtitle: 'Trip #204 completed successfully',
              time: '15m ago',
            ),
            const Divider(height: 20),
            _buildAlertDialogItem(
              icon: Icons.emergency_rounded,
              color: Colors.red,
              title: 'SOS Check Resolved',
              subtitle: 'Driver verified check-in status ok',
              time: '1h ago',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Dismiss',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToLogin();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text('Launch Console'),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertDialogItem({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  // Redesigned Centered Hero Section (Full-Width Video Background)
  Widget _buildHero(bool isDesktop, double screenWidth) {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFAF6F2),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio:
                _videoController != null && _videoController!.value.isInitialized
                ? _videoController!.value.aspectRatio
                : 16 / 9,
            child: Stack(
              children: [
                 // Background Video Player
                Positioned.fill(
                  child: IgnorePointer(
                    child: _videoController != null &&
                            _videoController!.value.isInitialized
                        ? VideoPlayer(_videoController!)
                        : Container(
                            color: const Color(0xFFFAF6F2),
                          ),
                  ),
                ),
                // Dark glassmorphic gradient overlay to guarantee text and buttons readability
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withOpacity(0.0),
                            Colors.black.withOpacity(0.15),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                // Notification icon button positioned exactly over the Gemini watermark logo inside the right phone tab bar
                Align(
                  alignment: const Alignment(0.83, 0.70),
                  child: GestureDetector(
                    onTap: () => _showAlertsDialog(context),
                    child: Container(
                      width: 73,
                      height: 73,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.35),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.notifications_active_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // CTA Buttons Row placed below the video
          Padding(
            padding: EdgeInsets.symmetric(vertical: isDesktop ? 30 : 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: isDesktop ? 170 : 120,
                  height: isDesktop ? 52 : 38,
                  child: ElevatedButton(
                    onPressed: _navigateToLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      'Enter Portal',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 15 : 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: isDesktop ? 190 : 130,
                  height: isDesktop ? 52 : 38,
                  child: OutlinedButton(
                    onPressed: () => _scrollToSection(_featuresKey),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.textPrimary,
                      side: const BorderSide(
                        color: AppColors.border,
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      'Explore Features',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isDesktop ? 15 : 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Metrics Section (Static/Premium blocks)
  Widget _buildMetricsSection(bool isDesktop) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 64,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double blockWidth =
              (constraints.maxWidth - 48) / (isDesktop ? 3 : 1);
          return Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildMetricItem(
                '2.1s',
                'Location Refresh Frequency',
                'Instant coordinates updates sync via WebSockets mapping.',
                blockWidth,
              ),
              _buildMetricItem(
                '99.9%',
                'Telemetry Accuracy',
                'Fine-grained location filters remove GPS coordinate drifts.',
                blockWidth,
              ),
              _buildMetricItem(
                '100%',
                'Privacy Compliance',
                'Profile deletions execute instant database sweeps.',
                blockWidth,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMetricItem(
    String value,
    String title,
    String desc,
    double width,
  ) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderLight, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Showcase Sections (Alternating feature description rows, phone frames removed)
  Widget _buildShowcaseSection(bool isDesktop, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      child: Column(
        children: [
          // Row 1: Live Interactive Student Dashboard Map
          ScrollReveal(
            child: Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              children: [
                if (isDesktop)
                  Expanded(
                    flex: 13,
                    child: _buildShowcaseVisual(true, screenWidth),
                  ),
                if (isDesktop) const Spacer(flex: 2),
                Expanded(
                  flex: 11,
                  child: _buildShowcaseText(
                    'Live Student Dashboard',
                    'Interactive Mapping',
                    'Allows students to locate operating campus buses on clean maps. Real-time active updates prevent missing transit routes by providing instant delay notifications and driver coordinates.',
                    Icons.map_rounded,
                  ),
                ),
                if (!isDesktop) ...[
                  const SizedBox(height: 32),
                  _buildShowcaseVisual(true, screenWidth),
                ],
              ],
            ),
          ),
          const SizedBox(height: 120),

          // Row 2: Live Driver Telemetry Console Isolate
          ScrollReveal(
            child: Flex(
              direction: isDesktop ? Axis.horizontal : Axis.vertical,
              children: [
                Expanded(
                  flex: 11,
                  child: _buildShowcaseText(
                    'Dedicated Driver Console',
                    'Background GPS Streams',
                    'Optimized driver console uses isolates to push coordinates, route calculations, and network latency checks asynchronously, maintaining background updates even when minimized.',
                    Icons.navigation_rounded,
                  ),
                ),
                if (isDesktop) const Spacer(flex: 2),
                Expanded(
                  flex: 13,
                  child: _buildShowcaseVisual(false, screenWidth),
                ),
                if (!isDesktop) ...[
                  const SizedBox(height: 32),
                  _buildShowcaseVisual(false, screenWidth),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseText(
    String tag,
    String title,
    String description,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              tag,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          description,
          style: const TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildShowcaseVisual(bool isStudent, double screenWidth) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.03),
            ),
          ),
          // Clean glassmorphic analytics widget representing dashboard/driver screens natively
          Container(
            width: 360,
            height: 240,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF131317),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF2E2E33), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: isStudent
                ? _buildStudentFeatureVisual()
                : _buildDriverFeatureVisual(),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentFeatureVisual() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'LIVE SHUTTLE ARRIVAL',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'ON TIME',
                style: TextStyle(
                  color: AppColors.success,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Library stop approaching...',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Vehicle #042 is approx. 200m away.',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: const [
            Text(
              'ESTIMATED ARRIVAL',
              style: TextStyle(color: Colors.white24, fontSize: 11),
            ),
            Text(
              '3 mins',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDriverFeatureVisual() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'BACKGROUND ISOLATE STREAM',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
            Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: 14,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Asynchronous background isolate active.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'GPS signals continue broadcasting when backgrounded.',
          style: TextStyle(color: Colors.white54, fontSize: 11),
        ),
        const Spacer(),
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: const Text(
            'Isolate Running Normally',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  // Bento Features Grid Section
  Widget _buildCoreHighlights(bool isDesktop) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      child: Column(
        children: [
          const Text(
            'All-in-One Architecture',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Engineered for Scale',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 48),

          // Bento Layout
          LayoutBuilder(
            builder: (context, constraints) {
              final double colWidth =
                  (constraints.maxWidth - 32) / (isDesktop ? 3 : 1);
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: [
                  // Column 1
                  SizedBox(
                    width: colWidth,
                    child: Column(
                      children: [
                        _buildHighlightCard(
                          Icons.offline_bolt_rounded,
                          'Speedy Data Sync',
                          'Supabase stream sockets keep map pins moving live with latency under 100ms.',
                        ),
                        const SizedBox(height: 16),
                        _buildHighlightCard(
                          Icons.shield_rounded,
                          'Secure RLS Schemas',
                          'Database permissions restrict profiles and routes updates to logged in clients.',
                        ),
                      ],
                    ),
                  ),
                  // Column 2
                  SizedBox(
                    width: colWidth,
                    child: Column(
                      children: [
                        _buildHighlightCard(
                          Icons.battery_saver_rounded,
                          'Isolate Telemetry',
                          'Separate dart task processing allows background GPS tracking without rendering freezes.',
                        ),
                        const SizedBox(height: 16),
                        _buildHighlightCard(
                          Icons.history_rounded,
                          'Automatic Route Logs',
                          'Store historical logs of route speeds, stops, and passenger counts automatically.',
                        ),
                      ],
                    ),
                  ),
                  // Column 3
                  SizedBox(
                    width: colWidth,
                    child: Column(
                      children: [
                        _buildHighlightCard(
                          Icons.notifications_active_rounded,
                          'Live Delay Alerts',
                          'Asynchronous push broadcasts update students instantly if buses hit traffic.',
                        ),
                        const SizedBox(height: 16),
                        _buildHighlightCard(
                          Icons.qr_code_scanner_rounded,
                          'Unique Org Access Codes',
                          'Bypass credential bloat with short, direct alphanumeric codes for quick onboarding.',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHighlightCard(IconData icon, String title, String desc) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLight, width: 1.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            desc,
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

  // Technology Architecture Section
  Widget _buildTechSection(bool isDesktop, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      child: isDesktop
          ? Row(
              children: [
                Expanded(
                  flex: 11,
                  child: ScrollReveal(child: _buildTechText()),
                ),
                const Spacer(flex: 2),
                Expanded(
                  flex: 13,
                  child: ScrollReveal(child: _buildTechVisuals()),
                ),
              ],
            )
          : Column(
              children: [
                ScrollReveal(child: _buildTechText()),
                const SizedBox(height: 56),
                ScrollReveal(child: _buildTechVisuals()),
              ],
            ),
    );
  }

  Widget _buildTechText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.terminal_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Security and Pipelines',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text(
          'Solid Tech Foundation.',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w900,
            color: AppColors.textPrimary,
            letterSpacing: -1.0,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'MAVIO relies on Supabase Row Level Security (RLS), encrypted clients, and location streams isolation to prevent data leaks. Our background pipelines run completely separate from UI threads to guarantee zero stuttering.',
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 28),
        _buildTechPipelineStep(
          '1',
          'Supabase streaming pipelines keep sync under 100ms.',
        ),
        const SizedBox(height: 12),
        _buildTechPipelineStep(
          '2',
          'Encrypted local auth stores bypass standard passwords entry.',
        ),
        const SizedBox(height: 12),
        _buildTechPipelineStep(
          '3',
          'GPS updates continue seamlessly when device is locked.',
        ),
      ],
    );
  }

  Widget _buildTechPipelineStep(String num, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary.withOpacity(0.12),
          ),
          alignment: Alignment.center,
          child: Text(
            num,
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTechVisuals() {
    return Center(
      child: Container(
        width: 460,
        height: 300,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.border, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Telemetry Architecture Pipeline',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            _buildArchitectureNode(
              'Client UI',
              'Renders telemetry markers in map views',
              AppColors.primary,
            ),
            _buildArchitectureConnector(),
            _buildArchitectureNode(
              'Isolates Pipeline',
              'Decoupled background coordinates calculations',
              Colors.indigoAccent,
            ),
            _buildArchitectureConnector(),
            _buildArchitectureNode(
              'Supabase Channels',
              'WebSockets stream channels mapped under 100ms',
              AppColors.success,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArchitectureNode(String title, String desc, Color dotColor) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 13,
              ),
            ),
            Text(
              desc,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildArchitectureConnector() {
    return Container(
      margin: const EdgeInsets.only(left: 4.5, top: 4, bottom: 4),
      width: 1,
      height: 20,
      color: AppColors.border,
    );
  }

  // Live Operations Mock Telemetry Dashboard
  Widget _buildLiveOperationsPreview(bool isDesktop, double screenWidth) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      child: Column(
        children: [
          const Text(
            'Live Operations Console',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Active Network Performance',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 40),
          Container(
            width: 800,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF0F0F12),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.success,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Live Simulation Feed',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Ping: 42ms',
                      style: TextStyle(color: Colors.white30, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    _buildPreviewMetric(
                      'Active Vehicles',
                      '14 Buses',
                      AppColors.primary,
                    ),
                    _buildPreviewMetric(
                      'Daily Coordinates Pushes',
                      '1,429,820',
                      Colors.indigoAccent,
                    ),
                    _buildPreviewMetric(
                      'Avg Route Delay',
                      '0.4 mins',
                      AppColors.success,
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 16,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'All active university routes reporting normal telemetry speeds.',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
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

  Widget _buildPreviewMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white38, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 24,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  // Pricing & Subscription Plans
  Widget _buildPricingSection(bool isDesktop) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      child: Column(
        children: [
          const Text(
            'Subscription Plans',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Transparent Pricing Tiers',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 48),
          LayoutBuilder(
            builder: (context, constraints) {
              final double cardWidth =
                  (constraints.maxWidth - 48) / (isDesktop ? 3 : 1);
              return Wrap(
                spacing: 24,
                runSpacing: 24,
                alignment: WrapAlignment.center,
                children: [
                  _buildPricingCard(
                    title: 'Free Trial',
                    price: '\$0',
                    billing: '1-month evaluation (cancel anytime)',
                    features: [
                      'Register up to 15 active vehicles',
                      'Unlimited active drivers & students',
                      'Standard live WebSockets mapping',
                      'Self-service setup console',
                    ],
                    buttonText: 'Start Trial Now',
                    isPopular: false,
                    width: cardWidth,
                    onPressed: _showContactDialog,
                  ),
                  _buildPricingCard(
                    title: 'Premium Campus',
                    price: '\$389.99',
                    billing: 'Billed annually per site',
                    features: [
                      'Register up to 25 active vehicles',
                      'Unlimited active drivers & students',
                      'Separate Dart isolate GPS telemetry',
                      'Historical routes speeds analytics',
                      'Email & Priority SLA Support',
                    ],
                    buttonText: 'Upgrade to Premium',
                    isPopular: true,
                    width: cardWidth,
                    onPressed: _showContactDialog,
                  ),
                  _buildPricingCard(
                    title: 'Enterprise Custom',
                    price: 'Custom',
                    billing: 'Tailored limits & SSO',
                    features: [
                      'Unlimited active vehicles & drivers',
                      'Custom university subdomain & logo',
                      'API access to database telemetry',
                      'Dedicated account manager support',
                      'SSO integration (SAML/OAuth)',
                    ],
                    buttonText: 'Contact Sales',
                    isPopular: false,
                    width: cardWidth,
                    onPressed: _showContactDialog,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required String billing,
    required List<String> features,
    required String buttonText,
    required bool isPopular,
    required double width,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isPopular ? AppColors.primary : AppColors.border,
          width: isPopular ? 2.0 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isPopular ? 0.06 : 0.02),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isPopular) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Most Popular',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ],
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                price,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -1.0,
                ),
              ),
              if (price != 'Custom') ...[
                const SizedBox(width: 4),
                Text(
                  price.contains('389.99') ? '/year' : '/month',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          Text(
            billing,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 32),
          Divider(color: AppColors.border.withOpacity(0.6), height: 1),
          const SizedBox(height: 32),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check_circle_outline_rounded,
                    color: AppColors.success,
                    size: 16,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      feature,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textPrimary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: isPopular ? AppColors.primary : Colors.white,
              foregroundColor: isPopular ? Colors.white : AppColors.textPrimary,
              elevation: 0,
              minimumSize: const Size(0, 50),
              side: isPopular
                  ? null
                  : const BorderSide(color: AppColors.border, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // FAQ Section
  Widget _buildFAQSection(bool isDesktop) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: isDesktop ? 64 : 24,
        vertical: 80,
      ),
      child: Column(
        children: [
          const Text(
            'Got Questions?',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Frequently Answered Details',
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 48),
          Container(
            width: 800,
            child: Column(
              children: [
                _buildFAQTile(
                  'How does the background location telemetry work?',
                  'MAVIO runs GPS updates in a separate Dart isolate that runs Location Services inside a foreground process. This prevents coordinate updates from freezing when drivers minimize the app or lock their screens.',
                ),
                const SizedBox(height: 16),
                _buildFAQTile(
                  'Is student location data tracked or stored?',
                  'No, student privacy is fully protected. Student devices only request coordinate streams from active university buses during operating hours. We never track or save location details of student devices.',
                ),
                const SizedBox(height: 16),
                _buildFAQTile(
                  'What database stack guarantees the low latency?',
                  'We utilize Supabase WebSocket Channels which stream coordinate delta patches directly from database tables to client layouts. Latency averages under 100ms, ensuring real-time marker precision.',
                ),
                const SizedBox(height: 16),
                _buildFAQTile(
                  'How can our campus request custom enterprise limits?',
                  'School administrations can link their customized portals by reaching out to our team at admin@mavio.com. We configure custom subdomains, SAML SSO integration, and driver limits manually.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQTile(String question, String answer) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1.0),
      ),
      child: Theme(
        data: ThemeData().copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: AppColors.primary,
          textColor: AppColors.primary,
          title: Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
              fontSize: 15,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
              child: Text(
                answer,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
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
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const Text(
                '© 2026 MAVIO by SkillForge Technologies. All Rights Reserved.',
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
                  if (kIsWeb) {
                    launchUrl(Uri.parse('/privacy'), webOnlyWindowName: '_self');
                  } else {
                    Navigator.of(context).pushNamed('/privacy');
                  }
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
                  if (kIsWeb) {
                    launchUrl(Uri.parse('/delete-account'), webOnlyWindowName: '_self');
                  } else {
                    Navigator.of(context).pushNamed('/delete-account');
                  }
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

class _FloatingWidgetState extends State<_FloatingWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..repeat(reverse: true);
    _animation = Tween<double>(
      begin: 0.0,
      end: widget.offset,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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

// Programmatic High-Fidelity Phone Frame Mockup
class _MockPhoneFrame extends StatelessWidget {
  final Widget child;
  final double height;

  const _MockPhoneFrame({required this.child, required this.height});

  @override
  Widget build(BuildContext context) {
    final double width = height * 0.49;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F12),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFF2E2E33), width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Container(color: const Color(0xFF131317), child: child),
      ),
    );
  }
}

// Custom Background Grid Painter for Hero Section
class HeroBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.04)
      ..strokeWidth = 0.8;

    const double spacing = 45.0;
    // Draw vertical grid lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
    }
    // Draw horizontal grid lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
    }

    // Draw a glowing radial orange aura bubble centered behind the text
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.primary.withOpacity(0.12),
              AppColors.primary.withOpacity(0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height / 2.8),
              radius: size.width / 3.5,
            ),
          )
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2.8),
      size.width / 3.5,
      glowPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Custom Viewport-based Scroll Reveal Animator
class ScrollReveal extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final bool animateOnLoad;

  const ScrollReveal({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 700),
    this.animateOnLoad = false,
  });

  @override
  State<ScrollReveal> createState() => _ScrollRevealState();
}

class _ScrollRevealState extends State<ScrollReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacityAnimation;
  late final Animation<double> _slideAnimation;
  bool _hasRevealed = false;
  ScrollPosition? _scrollPosition;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _slideAnimation = Tween<double>(
      begin: 40.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    if (widget.animateOnLoad) {
      _hasRevealed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.forward();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newPosition = Scrollable.maybeOf(context)?.position;
    if (newPosition != _scrollPosition) {
      _scrollPosition?.removeListener(_checkVisibility);
      _scrollPosition = newPosition;
      _scrollPosition?.addListener(_checkVisibility);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkVisibility());
  }

  @override
  void dispose() {
    _scrollPosition?.removeListener(_checkVisibility);
    _controller.dispose();
    super.dispose();
  }

  void _checkVisibility() {
    if (widget.animateOnLoad) return;
    if (_hasRevealed || !mounted) return;

    try {
      final renderBox = context.findRenderObject() as RenderBox?;
      if (renderBox == null || !renderBox.hasSize) return;

      final position = renderBox.localToGlobal(Offset.zero);
      final viewportHeight = MediaQuery.of(context).size.height;

      if (position.dy < viewportHeight - 80) {
        setState(() {
          _hasRevealed = true;
        });
        _controller.forward();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
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

class MavioSplashLoader extends StatefulWidget {
  final VoidCallback onFinished;

  const MavioSplashLoader({super.key, required this.onFinished});

  @override
  State<MavioSplashLoader> createState() => _MavioSplashLoaderState();
}

class _MavioSplashLoaderState extends State<MavioSplashLoader>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _busPositionAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _wheelRotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Animates from 0.0 (left) to 1.0 (right)
    _busPositionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Wheel turns 15 full rotations over the course of 3 seconds
    _wheelRotationAnimation = Tween<double>(begin: 0.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );

    // Gently scale the logo
    _logoScaleAnimation = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.4, curve: Curves.easeOutBack),
      ),
    );

    _animationController.forward().then((_) {
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildWheel(Animation<double> rotation) {
    return RotationTransition(
      turns: rotation,
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: Center(
          child: Container(
            width: 2,
            height: 2,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF6F2), // Premium Light Cream Background
      body: Stack(
        children: [
          // Ambient Mesh Glow Orb 1 (Top Left)
          Positioned(
            top: -150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.04),
              ),
            ),
          ),
          // Ambient Mesh Glow Orb 2 (Bottom Right)
          Positioned(
            bottom: -200,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF8A65).withOpacity(0.03),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Premium Logo Entrance
                ScaleTransition(
                  scale: _logoScaleAnimation,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.borderLight,
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.06),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'logo.png',
                          height: 80,
                          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                            if (wasSynchronouslyLoaded) return child;
                            return Stack(
                              alignment: Alignment.center,
                              children: [
                                if (frame == null)
                                  const Icon(
                                    Icons.directions_bus_rounded,
                                    size: 80,
                                    color: AppColors.primary,
                                  ),
                                AnimatedOpacity(
                                  opacity: frame == null ? 0 : 1,
                                  duration: const Duration(milliseconds: 300),
                                  child: child,
                                ),
                              ],
                            );
                          },
                          errorBuilder: (context, error, stackTrace) => const Icon(
                            Icons.directions_bus_rounded,
                            size: 80,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'MAVIO',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 8.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your Journey, Always in Sight',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 80),
                // Premium Glowing Progress Bar with Rotating Custom Vector Bus
                SizedBox(
                  width: 300,
                  child: Column(
                    children: [
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          // Bouncing vibration to simulate road physics
                          final double roadVibration =
                              (1.0 - _animationController.value) *
                                  1.0 *
                                  (((DateTime.now().millisecondsSinceEpoch / 80)
                                                  .floor() %
                                              2 ==
                                          0)
                                      ? 1.0
                                      : -1.0);

                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Glowing Progress Track Background (Light Border style)
                              Container(
                                height: 6,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: AppColors.border.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              // Neon Orange Glow filled track
                              FractionallySizedBox(
                                widthFactor: _busPositionAnimation.value,
                                child: Container(
                                  height: 6,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        Color(0xFFFF8A65),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(0.25),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              // Custom Animated Vector Bus
                              Positioned(
                                left: _busPositionAnimation.value * 300 - 21,
                                top: -34 + roadVibration,
                                child: SizedBox(
                                  width: 42,
                                  height: 38,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      // Bus Main Body
                                      Container(
                                        width: 42,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(5),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.primary
                                                  .withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: const Offset(-2, 2),
                                            ),
                                          ],
                                        ),
                                        child: Stack(
                                          children: [
                                            // Glass windshield
                                            Positioned(
                                              right: 3,
                                              top: 4,
                                              child: Container(
                                                width: 7,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withOpacity(0.4),
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                    topRight: Radius.circular(2),
                                                    bottomRight:
                                                        Radius.circular(2),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            // Passenger Windows
                                            Positioned(
                                              left: 4,
                                              top: 4,
                                              child: Row(
                                                children: List.generate(
                                                  3,
                                                  (index) => Container(
                                                    margin: const EdgeInsets
                                                        .only(right: 3),
                                                    width: 6,
                                                    height: 7,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withOpacity(0.35),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              1),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Front wheel
                                      Positioned(
                                        bottom: 10,
                                        right: 6,
                                        child: _buildWheel(
                                            _wheelRotationAnimation),
                                      ),
                                      // Back wheel
                                      Positioned(
                                        bottom: 10,
                                        left: 6,
                                        child: _buildWheel(
                                            _wheelRotationAnimation),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      FadeTransition(
                        opacity: _pulseController,
                        child: const Text(
                          'Establishing Secure Connection...',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
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
}
