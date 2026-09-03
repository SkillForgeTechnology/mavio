import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';
import 'landing_page.dart';
import '../core/utils/not_found_art_data.dart';

class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isWeb = screenWidth > 900;
    final double horizontalPadding = isWeb
        ? (screenWidth > 1400 ? 180 : 140)
        : 24;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // 1. Right Side Full-Height Image Coverage (In-Memory Instant 0ms Load)
          Positioned(
            top: 100,
            bottom: -150,
            right: 0,
            width: isWeb ? screenWidth * 0.54 : screenWidth,
            child: Image.memory(
              k404ArtBytes,
              fit: BoxFit.contain,
              alignment: Alignment.centerRight,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => Image.asset(
                'assets/404_bus_signpost.png',
                fit: BoxFit.contain,
                alignment: Alignment.centerRight,
                gaplessPlayback: true,
              ),
            ),
          ),

          // 2. Bottom Left Orange Accent Wave
          Positioned(
            bottom: -40,
            left: -60,
            child: Container(
              width: 340,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(220),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFFF9A62).withOpacity(0.55),
                    const Color(0xFFFF5722).withOpacity(0.20),
                  ],
                ),
              ),
            ),
          ),

          // 3. Foreground Interactive UI
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Header: Logo + MAVIO
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 24,
                  ),
                  child: InkWell(
                    onTap: () => _goHome(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0E6),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFFD5C0),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.directions_bus_rounded,
                            color: Color(0xFFFF5722),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'MAVIO',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF1F2937),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Main Left Content Area
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                    ),
                    child: Align(
                      alignment: isWeb
                          ? Alignment.centerLeft
                          : Alignment.center,
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: isWeb ? 460 : double.infinity,
                          ),
                          child: Column(
                            crossAxisAlignment: isWeb
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 404 Bold Heading with decorative rays
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  const Text(
                                    '404',
                                    style: TextStyle(
                                      fontSize: 96,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFFFF5722),
                                      letterSpacing: -2,
                                      height: 0.95,
                                    ),
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -28,
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 3.5,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF9A62),
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Container(
                                          width: 16,
                                          height: 3.5,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF5722),
                                            borderRadius:
                                                BorderRadius.circular(2),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),

                              // Headline
                              RichText(
                                textAlign: isWeb
                                    ? TextAlign.start
                                    : TextAlign.center,
                                text: const TextSpan(
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.6,
                                    height: 1.2,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Oops! You took\n',
                                      style: TextStyle(
                                          color: Color(0xFF1F2937)),
                                    ),
                                    TextSpan(
                                      text: 'the wrong route.',
                                      style: TextStyle(
                                          color: Color(0xFFFF5722)),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),

                              // Subtitle
                              Text(
                                "The page you're looking for seems to have taken a different destination.",
                                style: const TextStyle(
                                  fontSize: 15,
                                  color: Color(0xFF6B7280),
                                  height: 1.5,
                                ),
                                textAlign: isWeb
                                    ? TextAlign.start
                                    : TextAlign.center,
                              ),
                              const SizedBox(height: 22),

                              // Comforting Quote Box
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF7F2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFFFE0D0),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: isWeb
                                      ? MainAxisSize.min
                                      : MainAxisSize.max,
                                  children: const [
                                    Icon(
                                      Icons.directions_bus_rounded,
                                      color: Color(0xFFFF5722),
                                      size: 20,
                                    ),
                                    SizedBox(width: 12),
                                    Flexible(
                                      child: Text(
                                        "Don't worry, even the best journeys have a wrong turn sometimes.",
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFD84315),
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Primary Action: Back to Home Button
                              SizedBox(
                                width: isWeb ? 260 : double.infinity,
                                height: 52,
                                child: ElevatedButton.icon(
                                  onPressed: () => _goHome(context),
                                  icon: const Icon(
                                    Icons.home_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                  label: const Text(
                                    'Back to Home',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF5722),
                                    elevation: 3,
                                    shadowColor: const Color(0xFFFF5722)
                                        .withOpacity(0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
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
                ),

                // Bottom Floating Support Pill
                Padding(
                  padding: EdgeInsets.only(
                    bottom: 28,
                    left: horizontalPadding,
                    right: 24,
                  ),
                  child: Align(
                    alignment: isWeb
                        ? Alignment.centerLeft
                        : Alignment.center,
                    child: _buildSupportBottomCard(context, isWeb),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportBottomCard(BuildContext context, bool isWeb) {
    return InkWell(
      onTap: () => _showContactDialog(context),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 540),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFFFE0D0), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: isWeb ? MainAxisSize.min : MainAxisSize.max,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0E6),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.headset_mic_rounded,
                color: Color(0xFFFF5722),
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Still need help?',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  Text(
                    'Our support team is always here for you.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            Row(
              children: const [
                Text(
                  'Contact Support',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFFF5722),
                  ),
                ),
                SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: Color(0xFFFF5722),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Exact Support Popup Dialog from Landing Page
  void _showContactDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
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
                  Image.asset('logo.png', height: 42),
                  const SizedBox(width: 18),
                  Container(
                    height: 28,
                    width: 1.5,
                    color: const Color(0xFFE5E7EB),
                  ),
                  const SizedBox(width: 18),
                  Image.asset('company-logo.png', height: 38),
                ],
              ),
              const SizedBox(height: 22),
              const Text(
                'Contact Our Sales & Setup Team',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF1F2937),
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Let us help you configure the real-time student visibility transit system for your institution.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF6B7280),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),

              // Email Item
              _buildContactItem(
                icon: Icons.email_outlined,
                title: 'Email Us',
                value: 'info@skillforgetechnology.app',
                onTap: () => launchUrl(
                  Uri.parse('mailto:info@skillforgetechnology.app'),
                ),
              ),
              const SizedBox(height: 12),

              // Phone Item
              _buildContactItem(
                icon: Icons.phone_android_outlined,
                title: 'Mobile / Phone',
                value: '+91 93455 18760',
                onTap: () => launchUrl(Uri.parse('tel:+919345518760')),
              ),
              const SizedBox(height: 22),

              // WhatsApp & Call Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => launchUrl(
                        Uri.parse(
                          'https://wa.me/919345518760?text=Hi%2C%20I\'m%20interested%20in%20Mavio%20Transit%20Service!',
                        ),
                        mode: LaunchMode.externalApplication,
                      ),
                      icon: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'WhatsApp',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
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
                      onPressed: () =>
                          launchUrl(Uri.parse('tel:+919345518760')),
                      icon: const Icon(
                        Icons.call_outlined,
                        size: 18,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Call Now',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
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
          color: const Color(0xFFF9FAFB),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFFF5722), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      color: Color(0xFF1F2937),
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

  void _goHome(BuildContext context) {
    if (kIsWeb) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MavioLandingPage()),
        (route) => false,
      );
    } else {
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      } else {
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    }
  }
}
