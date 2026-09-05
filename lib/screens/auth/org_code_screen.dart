import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/utils/toast_utils.dart';
import 'role_select_screen.dart';

class OrgCodeScreen extends StatefulWidget {
  const OrgCodeScreen({super.key});

  @override
  State<OrgCodeScreen> createState() => _OrgCodeScreenState();
}

class _OrgCodeScreenState extends State<OrgCodeScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _codeController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _submitCode() async {
    if (!_formKey.currentState!.validate()) return;
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.verifyOrganizationCode(_codeController.text);

    if (!mounted) return;

    if (success) {
      Navigator.of(context).push(
        FadeSlidePageRoute(child: const RoleSelectScreen()),
      );
    } else {
      AppToast.show(
        context,
        auth.error ?? 'Invalid organization code',
        isError: true,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Slow technical matrix particles background
          const Positioned.fill(child: _TechnicalMatrixBg()),

          // Premium corner waves background
          Positioned.fill(
            child: CustomPaint(
              painter: _WaveBackgroundPainter(
                color: AppColors.primary.withOpacity(0.04),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 460),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight - 48,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 20),
                            
                            // Form Card Content with Animations
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const SizedBox(height: 32),
                                
                                // App logo animation
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    final double val = CurvedAnimation(
                                      parent: _controller,
                                      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
                                    ).value;
                                    return Opacity(
                                      opacity: val.clamp(0.0, 1.0),
                                      child: Transform.scale(
                                        scale: 0.8 + (0.2 * val),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Image.asset(
                                      'logo.png',
                                      height: 110,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 28),
                                
                                // Slide down text
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    final double val = CurvedAnimation(
                                      parent: _controller,
                                      curve: const Interval(0.0, 0.6, curve: Curves.easeOutCubic),
                                    ).value;
                                    return Opacity(
                                      opacity: val.clamp(0.0, 1.0),
                                      child: Transform.translate(
                                        offset: Offset(0, -20 * (1 - val)),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Enter Organization Code',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                          fontSize: 30,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Your organization. Our network.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 48),
                                
                                // Scale up form and button
                                AnimatedBuilder(
                                  animation: _controller,
                                  builder: (context, child) {
                                    final double val = CurvedAnimation(
                                      parent: _controller,
                                      curve: const Interval(0.3, 0.9, curve: Curves.easeOutBack),
                                    ).value;
                                    return Opacity(
                                      opacity: val.clamp(0.0, 1.0),
                                      child: Transform.scale(
                                        scale: 0.9 + (0.1 * val),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Form(
                                        key: _formKey,
                                        child: TextFormField(
                                          controller: _codeController,
                                          autofocus: true,
                                          textCapitalization: TextCapitalization.characters,
                                          textInputAction: TextInputAction.done,
                                          onFieldSubmitted: (_) => _submitCode(),
                                          validator: (val) {
                                            if (val == null || val.trim().isEmpty) {
                                              return 'Please enter your organization code';
                                            }
                                            return null;
                                          },
                                          decoration: const InputDecoration(
                                            hintText: 'e.g. ABC123',
                                            prefixIcon: Icon(Icons.domain_rounded),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 32),
                                      
                                      auth.isLoading
                                          ? const Center(
                                              child: CircularProgressIndicator(
                                                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                                              ),
                                            )
                                          : ElevatedButton(
                                              onPressed: _submitCode,
                                              child: const Row(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                children: [
                                                  Text('Continue'),
                                                  SizedBox(width: 8),
                                                  Icon(Icons.arrow_forward_rounded, size: 20),
                                                ],
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Help footer
                            AnimatedBuilder(
                              animation: _controller,
                              builder: (context, child) {
                                final double val = CurvedAnimation(
                                  parent: _controller,
                                  curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
                                ).value;
                                return Opacity(
                                  opacity: val.clamp(0.0, 1.0),
                                  child: child,
                                );
                              },
                              child: Column(
                                children: [
                                  TextButton(
                                    onPressed: () {},
                                    child: const Text('Can\'t find your code? Contact your organization'),
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Company branding
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Text(
                                        'A product of ',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Image.asset(
                                        'company-logo.png',
                                        height: 32,
                                        fit: BoxFit.contain,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  const Text(
                                    'v2.4.0',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
// WIDGET: SLOW DRIFTING TECHNICAL MATRIX PARTICLES BACKGROUND
// =========================================================================
class _TechnicalMatrixBg extends StatefulWidget {
  const _TechnicalMatrixBg();

  @override
  State<_TechnicalMatrixBg> createState() => _TechnicalMatrixBgState();
}

class _TechnicalMatrixBgState extends State<_TechnicalMatrixBg> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = List.generate(18, (index) => _Particle());

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
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
          painter: _MatrixPainter(_particles, _controller.value),
          child: Container(),
        );
      },
    );
  }
}

class _Particle {
  late double xRatio;
  late double yRatio;
  late double size;
  late double speedX;
  late double speedY;

  _Particle() {
    final rand = math.Random();
    xRatio = rand.nextDouble();
    yRatio = rand.nextDouble();
    size = 2.0 + (3.0 * rand.nextDouble());
    speedX = (rand.nextDouble() - 0.5) * 0.05;
    speedY = (rand.nextDouble() - 0.5) * 0.05;
  }

  void update() {
    xRatio += speedX;
    yRatio += speedY;
    if (xRatio < 0 || xRatio > 1) speedX = -speedX;
    if (yRatio < 0 || yRatio > 1) speedY = -speedY;
  }
}

class _MatrixPainter extends CustomPainter {
  final List<_Particle> particles;
  final double animationVal;

  _MatrixPainter(this.particles, this.animationVal);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary.withOpacity(0.12)
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = AppColors.primary.withOpacity(0.04)
      ..strokeWidth = 1.0;

    for (final p in particles) {
      p.update();
      final offset = Offset(p.xRatio * size.width, p.yRatio * size.height);
      canvas.drawCircle(offset, p.size, paint);

      for (final other in particles) {
        if (p == other) continue;
        final otherOffset = Offset(other.xRatio * size.width, other.yRatio * size.height);
        final dist = (offset - otherOffset).distance;
        if (dist < 120.0) {
          linePaint.color = AppColors.primary.withOpacity(((1.0 - (dist / 120.0)) * 0.06).clamp(0.0, 1.0));
          canvas.drawLine(offset, otherOffset, linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _WaveBackgroundPainter extends CustomPainter {
  final Color color;
  _WaveBackgroundPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Top-right soft corner wave
    final path1 = Path();
    path1.moveTo(size.width, 0);
    path1.lineTo(size.width * 0.35, 0);
    path1.quadraticBezierTo(
      size.width * 0.65,
      size.height * 0.16,
      size.width,
      size.height * 0.24,
    );
    path1.close();
    canvas.drawPath(path1, paint);

    // Lighter top-right accent curve
    final paint2 = Paint()
      ..color = color.withOpacity(0.02)
      ..style = PaintingStyle.fill;
    final path2 = Path();
    path2.moveTo(size.width, 0);
    path2.lineTo(size.width * 0.2, 0);
    path2.quadraticBezierTo(
      size.width * 0.55,
      size.height * 0.24,
      size.width,
      size.height * 0.32,
    );
    path2.close();
    canvas.drawPath(path2, paint2);

    // Bottom-left soft corner wave
    final path3 = Path();
    path3.moveTo(0, size.height);
    path3.lineTo(0, size.height * 0.8);
    path3.quadraticBezierTo(
      size.width * 0.24,
      size.height * 0.84,
      size.width * 0.45,
      size.height,
    );
    path3.close();
    canvas.drawPath(path3, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

