import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main_screen.dart';
import '../auth/login_screen.dart';
import '../../utils/session_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Gold luxury palette
  static const Color _bgDeep = Color(0xFF000000);
  static const Color _bgSurface = Color(0xFF0D0B08);
  static const Color _gold = Color(0xFFB48232);
  static const Color _goldLight = Color(0xFFE8D5A0);
  static const Color _goldFaint = Color(0x26B48232);

  late final AnimationController _entryCtrl;
  late final AnimationController _ringCtrl;
  late final AnimationController _pulseCtrl;

  late final Animation<double> _fadeAnim;
  late final Animation<double> _slideAnim;
  late final Animation<double> _ring1Anim;
  late final Animation<double> _ring2Anim;
  late final Animation<double> _glowAnim;

  final String imageUrl =
      "https://res.cloudinary.com/dzve5tof6/image/upload/v1780306934/new_mqp4ja.webp";

  @override
  void initState() {
    super.initState();

    // Entry animation (fade + slide up)
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnim = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<double>(
      begin: 30,
      end: 0,
    ).animate(CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut));

    // Continuously spinning rings
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _ring1Anim = Tween<double>(begin: 0, end: 2 * pi).animate(_ringCtrl);
    _ring2Anim = Tween<double>(begin: 2 * pi, end: 0).animate(_ringCtrl);

    // Ambient gold glow pulse
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _glowAnim = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _entryCtrl.forward();
    _handleNavigation();
  }

  Future<void> _handleNavigation() async {
    await Future.delayed(const Duration(seconds: 5));
    if (!mounted) return;

    final isLoggedIn = await SessionManager.isLoggedIn();

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => 
            isLoggedIn ? MainScreen() : const LoginScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _ringCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _bgDeep,
        body: Stack(
          children: [
            // Subtle diagonal lines texture
            CustomPaint(
              size: MediaQuery.of(context).size,
              painter: _LinePainter(),
            ),

            // Ambient radial glow
            AnimatedBuilder(
              animation: _glowAnim,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.3, -0.4),
                    radius: 0.9,
                    colors: [
                      _gold.withOpacity(0.07 * _glowAnim.value),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Main content
            Center(
              child: AnimatedBuilder(
                animation: _entryCtrl,
                builder: (_, child) => Opacity(
                  opacity: _fadeAnim.value,
                  child: Transform.translate(
                    offset: Offset(0, _slideAnim.value),
                    child: child,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo with rotating rings
                    _LogoWidget(
                      imageUrl: imageUrl,
                      ring1Anim: _ring1Anim,
                      ring2Anim: _ring2Anim,
                      glowAnim: _glowAnim,
                      gold: _gold,
                      goldFaint: _goldFaint,
                    ),

                    const SizedBox(height: 28),

                    // Brand name
                    Text(
                      'Aerthh',
                      style: TextStyle(
                        color: _goldLight,
                        fontSize: 24,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 8,
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Tagline
                    Text(
                      'BEST. EXCELLENCE',
                      style: TextStyle(
                        color: _gold.withOpacity(0.55),
                        fontSize: 9,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 5,
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Gold divider line
                    Container(
                      width: 60,
                      height: 0.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            _gold.withOpacity(0.6),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // Dot loader
                    _DotLoader(color: _gold),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Logo with spinning rings ─────────────────────────────────────────────────

class _LogoWidget extends StatelessWidget {
  const _LogoWidget({
    required this.imageUrl,
    required this.ring1Anim,
    required this.ring2Anim,
    required this.glowAnim,
    required this.gold,
    required this.goldFaint,
  });

  final String imageUrl;
  final Animation<double> ring1Anim;
  final Animation<double> ring2Anim;
  final Animation<double> glowAnim;
  final Color gold;
  final Color goldFaint;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 130,
      height: 130,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ambient glow
          AnimatedBuilder(
            animation: glowAnim,
            builder: (_, __) => Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    gold.withOpacity(0.18 * glowAnim.value),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Outer rotating ring
          AnimatedBuilder(
            animation: ring1Anim,
            builder: (_, __) => Transform.rotate(
              angle: ring1Anim.value,
              child: CustomPaint(
                size: const Size(130, 130),
                painter: _DashedRingPainter(
                  color: gold.withOpacity(0.4),
                  strokeWidth: 0.8,
                  dashCount: 40,
                ),
              ),
            ),
          ),

          // Inner counter-rotating ring
          AnimatedBuilder(
            animation: ring2Anim,
            builder: (_, __) => Transform.rotate(
              angle: ring2Anim.value,
              child: CustomPaint(
                size: const Size(106, 106),
                painter: _DashedRingPainter(
                  color: gold.withOpacity(0.2),
                  strokeWidth: 0.6,
                  dashCount: 24,
                ),
              ),
            ),
          ),

          // Logo image
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: gold.withOpacity(0.5), width: 0.8),
            ),
            child: ClipOval(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: const Color(0xFF0D0B08),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 1,
                          color: gold,
                        ),
                      ),
                    ),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  color: const Color(0xFF0D0B08),
                  child: Icon(
                    Icons.business_center_outlined,
                    color: gold.withOpacity(0.6),
                    size: 28,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Dashed ring painter ──────────────────────────────────────────────────────

class _DashedRingPainter extends CustomPainter {
  const _DashedRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
  });
  final Color color;
  final double strokeWidth;
  final int dashCount;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide / 2) - strokeWidth;
    final step = (2 * pi) / dashCount;
    for (int i = 0; i < dashCount; i += 2) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * step,
        step * 0.6,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Subtle background line texture ──────────────────────────────────────────

class _LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFB48232).withOpacity(0.04)
      ..strokeWidth = 0.5;
    const spacing = 60.0;
    for (double y = 0; y < size.height + size.width; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y - size.width), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Animated dot loader ──────────────────────────────────────────────────────

class _DotLoader extends StatefulWidget {
  const _DotLoader({required this.color});
  final Color color;

  @override
  State<_DotLoader> createState() => _DotLoaderState();
}

class _DotLoaderState extends State<_DotLoader> with TickerProviderStateMixin {
  late final List<AnimationController> _ctrls;
  late final List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _ctrls = List.generate(
      3,
      (i) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1400),
      )..repeat(reverse: true, period: Duration(milliseconds: 1400 + i * 200)),
    );
    _anims = _ctrls
        .map(
          (c) => Tween<double>(
            begin: 0.25,
            end: 1.0,
          ).animate(CurvedAnimation(parent: c, curve: Curves.easeInOut)),
        )
        .toList();
    for (int i = 0; i < 3; i++) {
      Future.delayed(Duration(milliseconds: i * 200), () {
        if (mounted) _ctrls[i].repeat(reverse: true);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => AnimatedBuilder(
          animation: _anims[i],
          builder: (_, __) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.color.withOpacity(_anims[i].value),
            ),
          ),
        ),
      ),
    );
  }
}
