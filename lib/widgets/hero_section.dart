import 'dart:math' as math;

import 'package:flutter/material.dart';

class HeroSection extends StatefulWidget {
  final VoidCallback onReservePressed;

  const HeroSection({super.key, required this.onReservePressed});

  @override
  State<HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<HeroSection>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _backdropController;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _backdropController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _backdropController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final width = size.width;
    final isMobile = width < 768;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _backdropController.stop();
    } else if (!_backdropController.isAnimating) {
      _backdropController.repeat();
    }
    final minHeight = (size.height * 0.78)
        .clamp(isMobile ? 440.0 : 560.0, isMobile ? 680.0 : 760.0)
        .toDouble();
    final titleSize = isMobile
        ? (width < 380 ? 42.0 : 52.0)
        : (width < 1100 ? 66.0 : 76.0);
    final buttonWidth = isMobile
        ? (width - 48).clamp(0.0, 380.0).toDouble()
        : null;

    return Container(
      constraints: BoxConstraints(minHeight: minHeight),
      width: double.infinity,
      child: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black,
                image: DecorationImage(
                  image: AssetImage('assets/images/hero_bg.png'),
                  fit: BoxFit.cover,
                  opacity: 0.30,
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: isMobile ? Alignment.topCenter : Alignment.centerLeft,
                  end: isMobile
                      ? Alignment.bottomCenter
                      : Alignment.centerRight,
                  colors: isMobile
                      ? [
                          Colors.black.withValues(alpha: 0.48),
                          Colors.black.withValues(alpha: 0.72),
                          Colors.black.withValues(alpha: 0.96),
                        ]
                      : [
                          Colors.black.withValues(alpha: 0.90),
                          Colors.black.withValues(alpha: 0.46),
                          Colors.black.withValues(alpha: 0.78),
                        ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: _HeroAtmospherePainter(
                  animation: _backdropController,
                  reduceMotion: reduceMotion,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 24 : 64,
              vertical: isMobile ? 40 : 64,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1160),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: isMobile
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    _entrance(
                      start: 0,
                      end: 0.55,
                      reduceMotion: reduceMotion,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.42),
                          border: Border.all(
                            color: const Color(
                              0xFFD4AF37,
                            ).withValues(alpha: 0.8),
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: const Text(
                          'BARBERÍA  /  ESTILO PROPIO',
                          style: TextStyle(
                            color: Color(0xFFE5C65A),
                            letterSpacing: 2,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 24 : 28),
                    _entrance(
                      start: 0.08,
                      end: 0.72,
                      reduceMotion: reduceMotion,
                      child: Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'CORTES CON\n'),
                            TextSpan(
                              text: 'ACTITUD.',
                              style: TextStyle(
                                color: const Color(0xFFE5C65A),
                                shadows: [
                                  Shadow(
                                    color: const Color(
                                      0xFFD4AF37,
                                    ).withValues(alpha: 0.28),
                                    blurRadius: 22,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontFamily: 'Playfair Display',
                          fontSize: titleSize,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.02,
                          letterSpacing: -1.5,
                        ),
                        textAlign: isMobile ? TextAlign.center : TextAlign.left,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _entrance(
                      start: 0.2,
                      end: 0.84,
                      reduceMotion: reduceMotion,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 590),
                        child: Text(
                          'Cortes, diseños y color con técnica, actitud y atención al detalle.',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.84),
                            fontSize: isMobile ? 15 : 18,
                            height: 1.65,
                            letterSpacing: 0.15,
                          ),
                          textAlign: isMobile
                              ? TextAlign.center
                              : TextAlign.left,
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 30 : 36),
                    _entrance(
                      start: 0.34,
                      end: 1,
                      reduceMotion: reduceMotion,
                      child: SizedBox(
                        width: buttonWidth,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD4AF37),
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 19,
                            ),
                            minimumSize: const Size(0, 58),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                              side: const BorderSide(
                                color: Color(0xFFF1D66D),
                                width: 1,
                              ),
                            ),
                            elevation: 8,
                            shadowColor: const Color(
                              0xFFD4AF37,
                            ).withValues(alpha: 0.38),
                            overlayColor: Colors.white.withValues(alpha: 0.16),
                          ),
                          onPressed: widget.onReservePressed,
                          icon: const Icon(Icons.event_available, size: 19),
                          label: Text(
                            'RESERVAR TURNO',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 15,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entrance({
    required double start,
    required double end,
    required bool reduceMotion,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _controller,
      child: child,
      builder: (context, child) {
        final progress = reduceMotion
            ? 1.0
            : Interval(
                start,
                end,
                curve: Curves.easeOutCubic,
              ).transform(_controller.value);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 14 * (1 - progress)),
            child: child,
          ),
        );
      },
    );
  }
}

class _HeroAtmospherePainter extends CustomPainter {
  final Animation<double> animation;
  final bool reduceMotion;

  _HeroAtmospherePainter({required this.animation, required this.reduceMotion})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final phase = reduceMotion ? 0.0 : animation.value * math.pi * 2;
    final width = size.width;
    final height = size.height;
    final shortestSide = math.min(width, height);

    final backDrift = math.sin(phase * 0.55);
    final midDrift = math.sin(phase * 0.9 + 1.2);
    final frontDrift = math.sin(phase * 1.3 + 2.4);

    final backGlowRect = Rect.fromCenter(
      center: Offset(
        width * (0.70 + backDrift * 0.12),
        height * (0.26 + math.cos(phase * 0.55) * 0.08),
      ),
      width: shortestSide * 1.0,
      height: shortestSide * 0.62,
    );
    canvas.drawOval(
      backGlowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFD4AF37).withValues(alpha: 0.40),
            const Color(0xFF9B6419).withValues(alpha: 0.18),
            Colors.transparent,
          ],
          stops: const [0, 0.42, 1],
        ).createShader(backGlowRect),
    );

    final midGlowRect = Rect.fromCenter(
      center: Offset(
        width * (0.30 + midDrift * 0.18),
        height * (0.77 - math.cos(phase * 0.9 + 1.2) * 0.09),
      ),
      width: shortestSide * 0.82,
      height: shortestSide * 0.48,
    );
    canvas.drawOval(
      midGlowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFC48B2C).withValues(alpha: 0.32),
            const Color(0xFF654116).withValues(alpha: 0.14),
            Colors.transparent,
          ],
          stops: const [0, 0.46, 1],
        ).createShader(midGlowRect),
    );

    final bandCenter = Offset(
      width * (0.60 + frontDrift * 0.23),
      height * (0.48 - math.cos(phase * 1.3 + 2.4) * 0.12),
    );
    final bandPath = Path()
      ..moveTo(bandCenter.dx - width * 0.62, bandCenter.dy + height * 0.42)
      ..lineTo(bandCenter.dx - width * 0.10, bandCenter.dy - height * 0.62)
      ..lineTo(bandCenter.dx + width * 0.08, bandCenter.dy - height * 0.62)
      ..lineTo(bandCenter.dx - width * 0.44, bandCenter.dy + height * 0.42)
      ..close();
    canvas.drawPath(
      bandPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            const Color(0xFFE9BC51).withValues(alpha: 0.18),
            const Color(0xFFD4AF37).withValues(alpha: 0.06),
            Colors.transparent,
          ],
          stops: const [0, 0.45, 0.72, 1],
        ).createShader(Offset.zero & size),
    );

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, shortestSide * 0.0016)
      ..color = const Color(0xFFE9BC51).withValues(alpha: 0.22);
    canvas.save();
    canvas.translate(
      width * (0.76 + backDrift * 0.05),
      height * (0.47 + midDrift * 0.04),
    );
    canvas.rotate(-0.34 + backDrift * 0.035);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: shortestSide * 1.20,
        height: shortestSide * 0.32,
      ),
      orbitPaint,
    );
    canvas.restore();

    final highlightRect = Rect.fromCenter(
      center: Offset(
        width * (0.83 + frontDrift * 0.15),
        height * (0.30 + midDrift * 0.05),
      ),
      width: shortestSide * 0.20,
      height: shortestSide * 0.20,
    );
    canvas.drawCircle(
      highlightRect.center,
      shortestSide * 0.035,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFE6A0).withValues(alpha: 0.44),
            const Color(0xFFD4AF37).withValues(alpha: 0.15),
            Colors.transparent,
          ],
        ).createShader(highlightRect),
    );
  }

  @override
  bool shouldRepaint(covariant _HeroAtmospherePainter oldDelegate) {
    return oldDelegate.reduceMotion != reduceMotion;
  }
}
