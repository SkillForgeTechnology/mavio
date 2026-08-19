import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';

class AccountDeletionPage extends StatelessWidget {
  const AccountDeletionPage({super.key});

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
          'ACCOUNT DELETION REQUEST',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 16,
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
            horizontal: isDesktop ? screenWidth * 0.22 : 24,
            vertical: 48,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              const Text(
                'Delete your Mavio Account & Data',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Mavio is a product of SkillForge Technology. We provide clear, simple mechanisms to delete your user account and all associated transit telemetry tracking logs.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),
              const Divider(color: AppColors.borderLight),
              const SizedBox(height: 32),

              // Steps Section
              const Text(
                'How to request account deletion',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              
              _buildStepRow(
                '1',
                'Contact your Organization or Support',
                'Since student and driver accounts are managed directly by your educational institution or company, you can request account deletion by contacting your organization\'s administrator directly, or by emailing our support team at: support@skillforgetechnology.app.',
              ),
              const SizedBox(height: 20),
              _buildStepRow(
                '2',
                'Identity Verification',
                'For security purposes, our support team or your organization administrator will verify your identity (using your Roll Number/Email and Date of Birth) before executing the deletion to prevent unauthorized account removals.',
              ),
              const SizedBox(height: 20),
              _buildStepRow(
                '3',
                'Permanent Data Purging',
                'Once verified, your account and all associated records are permanently purged from our databases. Deletions are processed within 48 hours of verification.',
              ),
              
              const SizedBox(height: 40),
              const Divider(color: AppColors.borderLight),
              const SizedBox(height: 32),

              // Data Status
              const Text(
                'What data is deleted or kept?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'When you request account deletion, all personal data is permanently wiped. We do not retain any of your location history.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              _buildDataStatusRow(Icons.check_circle_outline_rounded, Colors.green, 'Authentication Profile', 'All account metadata (Roll number, Phone, Email, and Name) is permanently deleted.'),
              const SizedBox(height: 16),
              _buildDataStatusRow(Icons.check_circle_outline_rounded, Colors.green, 'Location Telemetry Logs', 'All historical GPS tracking coordinates associated with your device or bus trips are permanently purged.'),
              const SizedBox(height: 16),
              _buildDataStatusRow(Icons.remove_circle_outline_rounded, Colors.grey, 'Data Retention Period', 'No personal data is kept on active servers. Backup logs are completely overwritten within 14 days.'),

              const SizedBox(height: 48),
              const Divider(color: AppColors.borderLight),
              const SizedBox(height: 32),

              // CTA button
              Center(
                child: Column(
                  children: [
                    const Text(
                      'Ready to submit a deletion request?',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.email_rounded, size: 18),
                      label: const Text('Email support@skillforgetechnology.app'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepRow(String number, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: AppColors.primary.withOpacity(0.1),
          foregroundColor: AppColors.primary,
          child: Text(
            number,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDataStatusRow(IconData icon, Color color, String title, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
