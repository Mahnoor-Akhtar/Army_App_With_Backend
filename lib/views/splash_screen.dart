import 'dart:math' as math;
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onFinish;

  const SplashScreen({super.key, required this.onFinish});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _rotationController;
  late AnimationController _backgroundController;

  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Intro Animations for logo and text
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.8, curve: Curves.elasticOut),
      ),
    );

    // Continuous rotation for loading spinner
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Subtle breathing/moving animation for background topographic lines
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    // Start intro fade in
    _fadeController.forward();

    // Transition to main screen after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        widget.onFinish();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _rotationController.dispose();
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF03140A), // Extremely dark forest green
      body: Stack(
        children: [
          // 1. Dynamic Topographic Map Background
          AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(size.width, size.height),
                painter: TopographicPainter(
                  animationValue: _backgroundController.value,
                ),
              );
            },
          ),

          // 2. Subtle radial glow centered on the logo
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.2),
                  radius: 0.8,
                  colors: [
                    const Color(0xFF0C5A32).withValues(alpha: 0.25), // Glowing green center
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 3. Splash Content Layer
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // TOP TEXT
                Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: _fadeAnimation.value,
                        child: Text(
                          'PAKISTAN ARMY',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12.0,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3.5,
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // LOGO, TITLE, SUBTITLE GROUP
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated Crest Emblem
                          AnimatedBuilder(
                            animation: _fadeController,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Opacity(
                                  opacity: _fadeAnimation.value,
                                  child: Container(
                                    width: 260,
                                    height: 260,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFD4AF37).withValues(alpha: 0.12),
                                          blurRadius: 40,
                                          spreadRadius: 8,
                                        ),
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/images/army_crest.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 35),

                          // Titles with Shaders for metallic look
                          AnimatedBuilder(
                            animation: _fadeAnimation,
                            builder: (context, child) {
                              return Opacity(
                                opacity: _fadeAnimation.value,
                                child: Column(
                                  children: [
                                    // "117 SP" Metallic Shader
                                    ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [
                                          Color(0xFFFFFFFF),
                                          Color(0xFFE5E5E5),
                                          Color(0xFFCD9B2D), // Gold tint highlights
                                          Color(0xFFFFFFFF),
                                        ],
                                        stops: [0.0, 0.45, 0.65, 1.0],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ).createShader(bounds),
                                      child: const Text(
                                        '117 SP',
                                        style: TextStyle(
                                          fontSize: 54,
                                          fontFamily: 'serif',
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 2,
                                          height: 1.0,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(0, 3),
                                              blurRadius: 6,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // "REGT." Metallic Shader
                                    ShaderMask(
                                      shaderCallback: (bounds) => const LinearGradient(
                                        colors: [
                                          Color(0xFFFFFFFF),
                                          Color(0xFFE5E5E5),
                                          Color(0xFFCD9B2D),
                                          Color(0xFFFFFFFF),
                                        ],
                                        stops: [0.0, 0.45, 0.65, 1.0],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ).createShader(bounds),
                                      child: const Text(
                                        'REGT.',
                                        style: TextStyle(
                                          fontSize: 40,
                                          fontFamily: 'serif',
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                          letterSpacing: 1.5,
                                          height: 1.1,
                                          shadows: [
                                            Shadow(
                                              offset: Offset(0, 3),
                                              blurRadius: 6,
                                              color: Colors.black54,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 15),

                                    // Golden glowing line
                                    Container(
                                      width: 140,
                                      height: 1.5,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Color(0xFFFFD700),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 15),

                                    // "ZARB-UL-HADEED"
                                    Text(
                                      'ZARB-UL-HADEED',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 4.0,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // SPINNER AND BOTTOM BAR
                Padding(
                  padding: const EdgeInsets.only(bottom: 30.0),
                  child: Column(
                    children: [
                      // Loading Spinner
                      RotationTransition(
                        turns: _rotationController,
                        child: CustomPaint(
                          size: const Size(40, 40),
                          painter: SpinnerPainter(),
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Bottom Brand Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'OFFICIAL APP',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.0,
                            ),
                          ),
                          const SizedBox(width: 12),
                          // VERIFIED BADGE
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.verified_user,
                                  color: Colors.white.withValues(alpha: 0.5),
                                  size: 11,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'VERIFIED',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 9.0,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

/// Custom Painter to draw topographic/contour lines dynamically
class TopographicPainter extends CustomPainter {
  final double animationValue;

  TopographicPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final width = size.width;
    final height = size.height;

    // We will draw 8 concentric-like topographic lines
    final List<double> scaleFactors = [0.2, 0.35, 0.5, 0.65, 0.8, 0.95, 1.1, 1.3];

    for (int i = 0; i < scaleFactors.length; i++) {
      // Set line opacity - lines further out are slightly more transparent
      double opacity = 0.035 - (i * 0.003);
      if (opacity < 0.005) opacity = 0.005;

      paint.color = const Color(0xFF81C784).withValues(alpha: opacity);

      final factor = scaleFactors[i];
      final path = Path();

      // Create a smooth topographic line by joining points via bezier curves
      final center = Offset(width * 0.5, height * 0.45);
      final int pointsCount = 12;

      for (int step = 0; step <= pointsCount; step++) {
        final double angle = (step / pointsCount) * 2 * math.pi;

        // Mathematical offset based on sine/cosine wave to generate organic-looking mountain ridges
        // and animated using the controller to make the ridges drift slowly
        final double noise = math.sin(angle * 3 + animationValue * 2 * math.pi) * 25.0 +
            math.cos(angle * 5 - animationValue * 4 * math.pi) * 15.0;

        final double radius = (math.min(width, height) * 0.35 * factor) + noise;

        final double px = center.dx + math.cos(angle) * radius;
        final double py = center.dy + math.sin(angle) * radius * 1.25; // slightly squished oval

        if (step == 0) {
          path.moveTo(px, py);
        } else {
          // Approximate curve using Bezier
          final double prevAngle = ((step - 1) / pointsCount) * 2 * math.pi;

          final double midAngle = (prevAngle + angle) / 2;
          final double midNoise = math.sin(midAngle * 3 + animationValue * 2 * math.pi) * 25.0 +
              math.cos(midAngle * 5 - animationValue * 4 * math.pi) * 15.0;
          final double midRadius = (math.min(width, height) * 0.35 * factor) + midNoise;
          final double midPx = center.dx + math.cos(midAngle) * midRadius;
          final double midPy = center.dy + math.sin(midAngle) * midRadius * 1.25;

          // Quadratic bezier curve through the mid point
          path.quadraticBezierTo(midPx, midPy, px, py);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant TopographicPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// Custom Loader / Spinner Painter (Glowing gradient circular arc)
class SpinnerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const double strokeWidth = 3.5;
    final Rect rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    // Glowing green trail gradient
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          Colors.transparent,
          Color(0xFF00FF66), // Glowing neon green
        ],
        stops: [0.2, 1.0],
      ).createShader(rect);

    // Soft glow backing
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2.0
      ..strokeCap = StrokeCap.round
      ..color = const Color(0xFF00FF66).withValues(alpha: 0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.0);

    canvas.drawArc(rect, 0, 1.75 * math.pi, false, glowPaint);
    canvas.drawArc(rect, 0, 1.75 * math.pi, false, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
