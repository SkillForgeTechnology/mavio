import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'PRIVACY POLICY',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.0,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.of(context).pushReplacementNamed('/');
            }
          },
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: AppColors.borderLight,
            height: 1.0,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? screenWidth * 0.2 : 24,
            vertical: 48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              const Text(
                'MAVIO Privacy Policy',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Last Updated: August 19, 2026',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 24),
              const Divider(color: AppColors.borderLight),
              const SizedBox(height: 24),

              _buildSectionTitle('1. Introduction'),
              _buildSectionBody(
                'MAVIO ("the App") is a proprietary product developed and owned by SkillForge Technology. '
                'We respect your privacy and are committed to protecting the personal data of our users, '
                'including students, drivers, and organization administrators. This Privacy Policy details '
                'how we collect, use, store, and share your information when using the MAVIO platform.',
              ),

              _buildSectionTitle('2. Location Data Collection (Important)'),
              _buildSectionBody(
                'To fulfill its primary service of real-time campus transit tracking, MAVIO collects and transmits '
                'precise location data of the campus transit buses. \n\n'
                '• **For Drivers**: The App collects location data (latitude, longitude, speed, and bearing) in '
                'the background and foreground while a trip is active. Background location collection is active '
                'even when the App is closed or cleared from recent tasks, allowing continuous tracking for the '
                'safety of student riders. Background location tracking begins only when the driver starts a trip '
                'manually and ends immediately when the driver completes the trip.\n'
                '• **For Students**: The App requests location access to display the student\'s location relative '
                'to the live bus on the map. Student location data is processed locally on the device and is '
                'never uploaded to our servers.',
              ),

              _buildSectionTitle('3. Personal and Account Data We Collect'),
              _buildSectionBody(
                'We collect personal data required to authenticate user accounts and manage transit assignments:\n\n'
                '• **Account Metadata**: Student Roll Numbers, Date of Birth (used for login authentication), '
                'Mobile Numbers, Email Addresses, and Profile Names.\n'
                '• **Vehicle Data**: Vehicle assignment identifiers, registration plates, and route details.\n'
                '• **Telemetry Data**: Speed metrics, location updates, transmission times, and upload counts.'
              ),

              _buildSectionTitle('4. How We Use Your Information'),
              _buildSectionBody(
                'We use the collected information for transit orchestration and system operations:\n\n'
                '• To show real-time bus locations to authorized student riders.\n'
                '• To estimate arrival times and optimize route selection.\n'
                '• To generate logs for administrators to review trip history.\n'
                '• To ensure the stability, performance, and security of the platform.'
              ),

              _buildSectionTitle('5. Data Sharing & Disclosure'),
              _buildSectionBody(
                'Your data privacy is our priority. SkillForge Technology does not sell, trade, or share your '
                'personal information or live location tracks with third-party advertising companies. Data is '
                'stored securely in encrypted cloud databases on Supabase and is only accessible by administrators '
                'of your registered organization.'
              ),

              _buildSectionTitle('6. Data Security and Deletion'),
              _buildSectionBody(
                'We implement industry-standard encryption protocols (SSL/TLS) for data in transit and database-level '
                'encryption at rest. If an administrator deletes a profile, all linked location updates and authentication '
                'logs are deleted immediately via a cascading database cascade system. Users may request account '
                'deletion at any time by contacting their organization or emailing support@skillforgetechnology.app.'
              ),

              _buildSectionTitle('7. Contact and Inquiries'),
              _buildSectionBody(
                'If you have any questions or concerns regarding this Privacy Policy, please contact our product '
                'operations team:\n\n'
                '• **SkillForge Technology Support**\n'
                '• Email: support@skillforgetechnology.app\n'
                '• Website: https://skillforgetechnology.app/'
              ),

              const SizedBox(height: 48),
              const Divider(color: AppColors.borderLight),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '© 2026 MAVIO by SkillForge Technology. All Rights Reserved.',
                  style: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSectionBody(String body) {
    return Text(
      body,
      style: const TextStyle(
        fontSize: 15,
        color: AppColors.textSecondary,
        height: 1.6,
      ),
    );
  }
}
