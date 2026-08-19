import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/theme.dart';
import 'login_screen.dart';
import 'org_code_screen.dart';

class RoleSelectScreen extends StatefulWidget {
  const RoleSelectScreen({super.key});

  @override
  State<RoleSelectScreen> createState() => _RoleSelectScreenState();
}

class _RoleSelectScreenState extends State<RoleSelectScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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
      MaterialPageRoute(
        builder: (_) => LoginScreen(role: role),
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
            offset: Offset(0, 30 * (1 - value)),
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
    final collegeName = auth.verifiedOrg?.name ?? 'your college';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const OrgCodeScreen()),
              );
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // Slow liquid aura background
          const Positioned.fill(child: _LiquidAuraBackground()),

          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      
                      // Welcome text section
                      _buildAnimatedItem(
                        startVal: 0.0,
                        endVal: 0.5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome to',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: 16,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              collegeName,
                              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Choose how you want to continue',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // 1. Student Card
                      _buildAnimatedItem(
                        startVal: 0.2,
                        endVal: 0.7,
                        child: _buildRoleCard(
                          context: context,
                          title: 'Student',
                          subtitle: 'Track your bus',
                          icon: Icons.school_rounded,
                          onTap: () => _navigateToLogin(context, 'student'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 2. Driver Card
                      if (!kIsWeb) ...[
                        _buildAnimatedItem(
                          startVal: 0.4,
                          endVal: 0.8,
                          child: _buildRoleCard(
                            context: context,
                            title: 'Driver',
                            subtitle: 'Start your trip and keep moving',
                            icon: Icons.directions_car_rounded,
                            onTap: () => _navigateToLogin(context, 'driver'),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // 3. Management Card
                      _buildAnimatedItem(
                        startVal: 0.6,
                        endVal: 0.9,
                        child: _buildRoleCard(
                          context: context,
                          title: 'Management',
                          subtitle: 'Manage buses, drivers and students',
                          icon: Icons.supervised_user_circle_rounded,
                          onTap: () => _navigateToLogin(context, 'management'),
                        ),
                      ),
                      const SizedBox(height: 60),

                      // Sub-footer tagline
                      _buildAnimatedItem(
                        startVal: 0.8,
                        endVal: 1.0,
                        child: const Center(
                          child: Text(
                            'Safe Buses Build Brighter Futures',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
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

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight, width: 1.5),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          splashColor: AppColors.primaryLight.withOpacity(0.4),
          highlightColor: AppColors.primaryLight.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Icon Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 20),
                // Text details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: AppColors.textSecondary,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// WIDGET: SLOW DRIFTING LIQUID AURA GRADIENTS BACKGROUND
// =========================================================================
class _LiquidAuraBackground extends StatefulWidget {
  const _LiquidAuraBackground();

  @override
  State<_LiquidAuraBackground> createState() => _LiquidAuraBackgroundState();
}

class _LiquidAuraBackgroundState extends State<_LiquidAuraBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
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
        final progress = _controller.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.background,
                Color.lerp(AppColors.background, AppColors.primaryLight, progress)!,
                Color.lerp(AppColors.background, const Color(0xFFFFF7F2), 1.0 - progress)!,
              ],
            ),
          ),
          child: Stack(
            children: [
              // Peach blob 1
              Positioned(
                top: -60 + (120 * progress),
                left: -60 + (60 * progress),
                child: Container(
                  width: 320,
                  height: 320,
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
              // Amber blob 2
              Positioned(
                bottom: -90 + (130 * progress),
                right: -70 + (90 * progress),
                child: Container(
                  width: 360,
                  height: 360,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFFFD59E).withOpacity(0.07),
                        const Color(0xFFFFD59E).withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

