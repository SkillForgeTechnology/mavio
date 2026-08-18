import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/theme/theme.dart';
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
        MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.error ?? 'Invalid organization code'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
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
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 40),
                                
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Enter College Code',
                                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                          fontSize: 30,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Your college. Our network.',
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
                                    child: const Text('Can\'t find your code? Contact your college'),
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

