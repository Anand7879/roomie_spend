import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../onboarding/onboarding_screen.dart';
import '../dashboard/home_screen.dart';
import '../auth/profile_setup/profile_setup_screen.dart';

/// A cinematic, interactive splash screen representing the premium entry
/// point for the "RoomieSpend" application. Performs initial session checks
/// and branches routes after a 2.5-second animation.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}


class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  // --- Controllers & Animations ---
  late AnimationController _entranceController;
  late Animation<double> _logoOpacityAnimation;
  late Animation<double> _logoScaleAnimation;
  late Animation<double> _glowIntensityAnimation;
  late Animation<double> _textOpacityAnimation;
  late Animation<double> _textSlideAnimation;
  late Animation<double> _textTrackingAnimation;

  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  late AnimationController _orbitController;
  late AnimationController _shimmerController;
  late AnimationController _particleController;

  late AnimationController _ambientController;
  late Animation<double> _ambientAnimation;

  // --- Navigation Race-Condition Fix (ISSUE-07) ---
  // Tracks whether both conditions are met before navigating:
  // 1. Minimum display time has elapsed (entrance + 1s)
  // 2. Auth state has resolved (no longer AuthInitial)
  bool _minTimeElapsed = false;
  bool _navigated = false;

  // --- Background Particles Data ---
  final List<_InteractiveParticle> _particles = [];
  final int _particleCount = 40;
  final math.Random _random = math.Random();
  Offset? _touchPosition;
  final double _touchRadius = 120.0;

  @override
  void initState() {
    super.initState();

    // Initialize the background particles
    _initializeParticles();

    // Trigger local session checks immediately on boot
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(authStateNotifierProvider.notifier).initializeSession();
      }
    });

    // --- 1. Entrance Animations (Duration: 1.5 seconds) ---
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _logoOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.45, curve: Curves.easeOut)),
    );

    _logoScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.0, 0.50, curve: Curves.easeOutBack)),
    );

    _glowIntensityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.35, 0.80, curve: Curves.easeInOut)),
    );

    _textOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.45, 0.80, curve: Curves.easeOut)),
    );

    _textSlideAnimation = Tween<double>(begin: 35.0, end: 0.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.45, 0.85, curve: Curves.easeOutCubic)),
    );

    _textTrackingAnimation = Tween<double>(begin: 18.0, end: 7.0).animate(
      CurvedAnimation(parent: _entranceController, curve: const Interval(0.45, 0.90, curve: Curves.easeOutCubic)),
    );

    // --- 2. Floating Animation (Continuous loop) ---
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _floatAnimation = Tween<double>(begin: -7.0, end: 7.0).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOutSine),
    );

    // --- 3. Orbit Ring Rotation ---
    _orbitController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    );

    // --- 4. Text Shimmer Animation (Continuous loop) ---
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // --- 5. Particle Animation Controller ---
    // ISSUE-24 fix: does NOT add a setState listener. Instead, the particle
    // CustomPaint is wrapped in an AnimatedBuilder that only rebuilds that layer.
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    );

    // --- 6. Ambient Light Breathing ---
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _ambientAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _ambientController, curve: Curves.easeInOutQuad),
    );

    // Run animations and schedule screen routing
    _startAnimationSequences();
  }

  void _initializeParticles() {
    for (int i = 0; i < _particleCount; i++) {
      _particles.add(
        _InteractiveParticle(
          x: _random.nextDouble(),
          y: _random.nextDouble(),
          radius: _random.nextDouble() * 2.8 + 0.8,
          speed: _random.nextDouble() * 0.03 + 0.012,
          opacity: _random.nextDouble() * 0.45 + 0.15,
          wobbleSpeed: _random.nextDouble() * 2.0 + 0.5,
          wobbleAmount: _random.nextDouble() * 0.005 + 0.002,
        ),
      );
    }
  }

  /// Updates particle positions without calling setState.
  /// Called directly inside the AnimatedBuilder for the particle layer —
  /// only that layer rebuilds, not the entire widget tree. (ISSUE-24)
  void _updateParticles(Size screenSize) {
    for (var particle in _particles) {
      particle.y -= particle.speed * 0.04;
      particle.wobblePhase += particle.wobbleSpeed * 0.025;
      particle.x += math.sin(particle.wobblePhase) * particle.wobbleAmount;

      if (_touchPosition != null) {
        final double pxX = particle.x * screenSize.width;
        final double pxY = particle.y * screenSize.height;
        final double dx = pxX - _touchPosition!.dx;
        final double dy = pxY - _touchPosition!.dy;
        final double distance = math.sqrt(dx * dx + dy * dy);

        if (distance < _touchRadius) {
          final double force = (1.0 - (distance / _touchRadius)) * 1.5;
          final double dirX = distance == 0 ? 0.0 : dx / distance;
          final double dirY = distance == 0 ? 0.0 : dy / distance;
          particle.x += (dirX * force * 15.0) / screenSize.width;
          particle.y += (dirY * force * 15.0) / screenSize.height;
        }
      }

      if (particle.y < -0.05) {
        particle.y = 1.05;
        particle.x = _random.nextDouble();
      }
      if (particle.y > 1.05) {
        particle.y = -0.05;
      }
      if (particle.x < -0.05) particle.x = 1.05;
      if (particle.x > 1.05) particle.x = -0.05;
    }
  }

  /// ISSUE-07: Navigation is only triggered when BOTH conditions are true:
  /// 1. Minimum display time has elapsed (prevents instant flash)
  /// 2. Auth state has resolved beyond AuthInitial/AuthLoading
  void _tryNavigate() {
    if (_navigated || !mounted) return;
    final authState = ref.read(authStateNotifierProvider);
    if (authState is AuthInitial || authState is AuthLoading) return;
    _navigated = true;
    _evaluateNavigation();
  }

  void _startAnimationSequences() async {
    _particleController.repeat();
    _shimmerController.repeat();
    _orbitController.repeat();
    _ambientController.repeat(reverse: true);

    HapticFeedback.lightImpact();
    await _entranceController.forward();
    HapticFeedback.mediumImpact();
    _floatController.repeat(reverse: true);

    // Minimum display window: wait 1s after entrance animation (total = 2.5s)
    // ISSUE-07: After the delay, check auth state. If still unresolved, the
    // ref.listen in build() will trigger navigation once it resolves.
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        _minTimeElapsed = true;
        _tryNavigate();
      }
    });
  }

  /// Evaluates state to navigate to HomeScreen if session exists, else OnboardingScreen
  void _evaluateNavigation() {
    final authState = ref.read(authStateNotifierProvider);
    
    Widget targetScreen;
    if (authState is AuthAuthenticated) {
      targetScreen = const HomeScreen();
    } else if (authState is AuthProfileIncomplete) {
      targetScreen = const ProfileSetupScreen();
    } else {
      targetScreen = const OnboardingScreen();
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final fadeTransition = Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: const Interval(0.0, 0.90, curve: Curves.easeInOut)),
          );
          final scaleTransition = Tween<double>(begin: 1.06, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: const Interval(0.0, 1.0, curve: Curves.easeOutQuart)),
          );
          return FadeTransition(
            opacity: fadeTransition,
            child: ScaleTransition(scale: scaleTransition, child: child),
          );
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();
    _orbitController.dispose();
    _shimmerController.dispose();
    _particleController.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    // ISSUE-07: Listen for auth state resolution. If minimum display time has
    // already elapsed, navigate immediately. Otherwise, set a flag so
    // _tryNavigate() handles it when the timer fires.
    ref.listen<AuthState>(authStateNotifierProvider, (previous, next) {
      if (next is! AuthInitial && next is! AuthLoading) {
        if (_minTimeElapsed) _tryNavigate();
      }
    });

    return Scaffold(
      body: GestureDetector(
        onPanDown: (details) => setState(() => _touchPosition = details.globalPosition),
        onPanUpdate: (details) => setState(() => _touchPosition = details.globalPosition),
        onPanEnd: (_) => setState(() => _touchPosition = null),
        child: Stack(
          children: [
            // Ambient shift light background
            AnimatedBuilder(
              animation: _ambientAnimation,
              builder: (context, child) {
                final Color topColor = Color.lerp(const Color(0xFFFFFFFF), const Color(0xFFFBFBFF), _ambientAnimation.value)!;
                final Color middleColor = Color.lerp(const Color(0xFFF5F3FF), const Color(0xFFEDE9FE), _ambientAnimation.value)!;
                final Color bottomColor = Color.lerp(const Color(0xFFFAFAFC), const Color(0xFFF3F1FF), _ambientAnimation.value)!;
                return Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [topColor, middleColor, bottomColor],
                    ),
                  ),
                );
              },
            ),

            // ISSUE-24: Particle layer is isolated inside its own AnimatedBuilder.
            // Only the CustomPaint repaints on every tick — not the full widget tree.
            Positioned.fill(
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _particleController,
                  builder: (context, _) {
                    _updateParticles(size);
                    return CustomPaint(
                      painter: _ParticlePainter(
                        particles: _particles,
                        touchPosition: _touchPosition,
                        touchRadius: _touchRadius,
                      ),
                    );
                  },
                ),
              ),
            ),

            // Logo & text components
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: Listenable.merge([_entranceController, _floatController, _orbitController]),
                    builder: (context, child) {
                      final logoOffset = _entranceController.isCompleted ? _floatAnimation.value : 0.0;
                      return Transform.translate(
                        offset: Offset(0, logoOffset),
                        child: Transform.scale(
                          scale: _logoScaleAnimation.value,
                          child: Opacity(
                            opacity: _logoOpacityAnimation.value,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                _buildBackgroundGlow(),
                                SizedBox(
                                  width: 170,
                                  height: 170,
                                  child: CustomPaint(
                                    painter: _OrbitRingPainter(
                                      rotationAngle: _orbitController.value * math.pi * 2,
                                      glowIntensity: _glowIntensityAnimation.value,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  width: 100,
                                  height: 100,
                                  child: CustomPaint(painter: _LogoPainter()),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 40),
                  AnimatedBuilder(
                    animation: _entranceController,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, _textSlideAnimation.value),
                        child: Opacity(opacity: _textOpacityAnimation.value, child: child),
                      );
                    },
                    child: Column(
                      children: [
                        AnimatedBuilder(
                          animation: Listenable.merge([_shimmerController, _entranceController]),
                          builder: (context, child) {
                            return ShaderMask(
                              shaderCallback: (bounds) {
                                return LinearGradient(
                                  begin: Alignment(-2.0 + (3.0 * _shimmerController.value), -0.5),
                                  end: Alignment(0.0 + (3.0 * _shimmerController.value), 0.5),
                                  colors: const [
                                    AppTheme.textPrimary,
                                    AppTheme.textPrimary,
                                    AppTheme.primaryPurple,
                                    AppTheme.textPrimary,
                                    AppTheme.textPrimary,
                                  ],
                                  stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
                                ).createShader(bounds);
                              },
                              blendMode: BlendMode.srcIn,
                              child: Text(
                                // ISSUE-19: Fixed brand name typo — was "ROOMSPEND"
                                "ROOMIESPEND",
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: _textTrackingAnimation.value,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "SHARED LIVING, SIMPLIFIED",
                          style: TextStyle(
                            // ISSUE-12: Replaced withOpacity with withValues
                            color: AppTheme.textSecondary.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3.5,
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
      ),
    );
  }

  // ISSUE-28: Removed unused 'Size size' parameter — it was passed in but never used.
  Widget _buildBackgroundGlow() {
    final double glowRadius = 70.0 + (40.0 * _glowIntensityAnimation.value);
    return Container(
      width: glowRadius,
      height: glowRadius,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            // ISSUE-12: Replaced withOpacity with withValues
            color: AppTheme.primaryPurple.withValues(alpha: 0.12 * _glowIntensityAnimation.value),
            blurRadius: 40,
            spreadRadius: 8,
          ),
          BoxShadow(
            color: AppTheme.secondaryViolet.withValues(alpha: 0.08 * _glowIntensityAnimation.value),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class _InteractiveParticle {
  double x;
  double y;
  double radius;
  double speed;
  double opacity;
  double wobbleSpeed;
  double wobbleAmount;
  double wobblePhase = 0.0;

  _InteractiveParticle({
    required this.x,
    required this.y,
    required this.radius,
    required this.speed,
    required this.opacity,
    required this.wobbleSpeed,
    required this.wobbleAmount,
  }) {
    wobblePhase = math.Random().nextDouble() * math.pi * 2;
  }
}

class _ParticlePainter extends CustomPainter {
  final List<_InteractiveParticle> particles;
  final Offset? touchPosition;
  final double touchRadius;

  _ParticlePainter({
    required this.particles,
    this.touchPosition,
    required this.touchRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    if (touchPosition != null) {
      final touchGlow = Paint()
        ..shader = RadialGradient(
          // ISSUE-12: Replaced withOpacity with withValues
          colors: [AppTheme.primaryPurple.withValues(alpha: 0.08), Colors.transparent],
        ).createShader(Rect.fromCircle(center: touchPosition!, radius: touchRadius));
      canvas.drawCircle(touchPosition!, touchRadius, touchGlow);
    }

    for (var particle in particles) {
      final double brightnessVal = particle.opacity;
      if (particle.radius > 2.0) {
        paint.color = AppTheme.primaryPurple.withValues(alpha: brightnessVal * 0.40);
      } else {
        paint.color = AppTheme.secondaryViolet.withValues(alpha: brightnessVal * 0.28);
      }
      final position = Offset(particle.x * size.width, particle.y * size.height);
      canvas.drawCircle(position, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => true;
}

class _OrbitRingPainter extends CustomPainter {
  final double rotationAngle;
  final double glowIntensity;

  _OrbitRingPainter({
    required this.rotationAngle,
    required this.glowIntensity,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (glowIntensity <= 0.05) return;

    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double radius1 = size.width * 0.45;
    final double radius2 = size.width * 0.38;

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // ISSUE-12: All withOpacity calls replaced with withValues
    final gradient = SweepGradient(
      colors: [
        AppTheme.primaryPurple.withValues(alpha: 0.0),
        AppTheme.primaryPurple.withValues(alpha: 0.20 * glowIntensity),
        AppTheme.secondaryViolet.withValues(alpha: 0.18 * glowIntensity),
        AppTheme.primaryPurple.withValues(alpha: 0.25 * glowIntensity),
        AppTheme.primaryPurple.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      transform: GradientRotation(rotationAngle),
    ).createShader(rect);

    final ringPaint = Paint()
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(Offset(cx, cy), radius1, ringPaint);

    final innerGradient = SweepGradient(
      colors: [
        AppTheme.secondaryViolet.withValues(alpha: 0.0),
        AppTheme.secondaryViolet.withValues(alpha: 0.22 * glowIntensity),
        AppTheme.primaryPurple.withValues(alpha: 0.15 * glowIntensity),
        AppTheme.secondaryViolet.withValues(alpha: 0.25 * glowIntensity),
        AppTheme.secondaryViolet.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.3, 0.6, 0.8, 1.0],
      transform: GradientRotation(-rotationAngle * 1.5),
    ).createShader(rect);

    final innerRingPaint = Paint()
      ..shader = innerGradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;

    canvas.drawCircle(Offset(cx, cy), radius2, innerRingPaint);

    final nodePaint = Paint()
      ..color = AppTheme.primaryPurple.withValues(alpha: 0.65 * glowIntensity)
      ..style = PaintingStyle.fill;
    
    final double node1x = cx + radius1 * math.cos(rotationAngle);
    final double node1y = cy + radius1 * math.sin(rotationAngle);
    canvas.drawCircle(Offset(node1x, node1y), 3.0, nodePaint);

    final nodePaint2 = Paint()
      ..color = AppTheme.secondaryViolet.withValues(alpha: 0.60 * glowIntensity)
      ..style = PaintingStyle.fill;
    final double node2x = cx + radius2 * math.cos(-rotationAngle * 1.5 + math.pi);
    final double node2y = cy + radius2 * math.sin(-rotationAngle * 1.5 + math.pi);
    canvas.drawCircle(Offset(node2x, node2y), 2.5, nodePaint2);
  }

  @override
  bool shouldRepaint(covariant _OrbitRingPainter oldDelegate) =>
      oldDelegate.rotationAngle != rotationAngle ||
      oldDelegate.glowIntensity != glowIntensity;
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final double padding = w * 0.08;
    final double contentWidth = w - (padding * 2);
    final double contentHeight = h - (padding * 2);
    final double left = padding;
    final double top = padding;

    final glowPaint = Paint()
      // ISSUE-12: Replaced withOpacity with withValues
      ..color = AppTheme.secondaryViolet.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

    final roofPath = Path();
    roofPath.moveTo(left + contentWidth / 2, top + contentHeight * 0.05);
    roofPath.lineTo(left + contentWidth, top + contentHeight * 0.45);
    roofPath.lineTo(left + contentWidth * 0.8, top + contentHeight * 0.45);
    roofPath.lineTo(left + contentWidth / 2, top + contentHeight * 0.20);
    roofPath.lineTo(left + contentWidth * 0.2, top + contentHeight * 0.45);
    roofPath.lineTo(left, top + contentHeight * 0.45);
    roofPath.close();

    final cardPath = Path();
    cardPath.moveTo(left + contentWidth / 2, top + contentHeight * 0.35);
    cardPath.lineTo(left + contentWidth * 0.9, top + contentHeight * 0.60);
    cardPath.lineTo(left + contentWidth / 2, top + contentHeight * 0.95);
    cardPath.lineTo(left + contentWidth * 0.1, top + contentHeight * 0.60);
    cardPath.close();

    final arrowPath = Path();
    arrowPath.moveTo(left + contentWidth / 2, top + contentHeight * 0.50);
    arrowPath.lineTo(left + contentWidth * 0.7, top + contentHeight * 0.65);
    arrowPath.lineTo(left + contentWidth * 0.6, top + contentHeight * 0.70);
    arrowPath.lineTo(left + contentWidth / 2, top + contentHeight * 0.60);
    arrowPath.lineTo(left + contentWidth * 0.4, top + contentHeight * 0.70);
    arrowPath.lineTo(left + contentWidth * 0.3, top + contentHeight * 0.65);
    arrowPath.close();

    canvas.drawPath(cardPath, glowPaint);
    canvas.drawPath(roofPath, glowPaint);

    final rect = Rect.fromLTWH(0, 0, w, h);
    final fillGradient = AppTheme.logoGlowGradient.createShader(rect);
    final fillPaint = Paint()..shader = fillGradient..style = PaintingStyle.fill;
    final cyanGradient = AppTheme.cyanGradient.createShader(rect);
    final roofPaint = Paint()..shader = cyanGradient..style = PaintingStyle.fill;
    // ISSUE-12: Replaced withOpacity with withValues
    final arrowPaint = Paint()..color = Colors.white.withValues(alpha: 0.95)..style = PaintingStyle.fill;

    canvas.drawPath(cardPath, fillPaint);
    canvas.drawPath(roofPath, roofPaint);

    final borderPaint = Paint()..color = Colors.white.withValues(alpha: 0.45)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    canvas.drawPath(cardPath, borderPaint);
    canvas.drawPath(roofPath, borderPaint);
    canvas.drawPath(arrowPath, arrowPaint);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => false;
}
