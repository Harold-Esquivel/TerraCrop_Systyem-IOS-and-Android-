import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'app_theme.dart';
import 'brand.dart';

class EntryScreen extends StatefulWidget {
  const EntryScreen({super.key});
  @override
  State<EntryScreen> createState() => _EntryScreenState();
}

class _EntryScreenState extends State<EntryScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2450),
  )..forward();

  double phase(double start, double end) => Curves.easeOutCubic.transform(
    ((animation.value - start) / (end - start)).clamp(0, 1),
  );

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  void enter() => Navigator.of(context).pushReplacement(
    PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => const LoadingScreen(),
      transitionDuration: const Duration(milliseconds: 430),
      transitionsBuilder: (_, fade, _, child) =>
          FadeTransition(opacity: fade, child: child),
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BrandBackdrop(
      child: SafeArea(
        child: AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final logo = phase(0, .28);
            final name = phase(.30, .57);
            final rise = phase(.59, .80);
                final button = phase(.80, 1);
            return Stack(
              children: [
                Center(
                  child: Transform.translate(
                    offset: Offset(0, -48 * rise),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Opacity(
                          opacity: logo,
                          child: Transform.scale(
                            scale: .9 + .1 * logo,
                            child: const LogoMark(size: 190),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Opacity(
                          opacity: name,
                          child: ImageFiltered(
                            imageFilter: ui.ImageFilter.blur(
                              sigmaX: 9 * (1 - name),
                              sigmaY: 9 * (1 - name),
                            ),
                            child: const Text(
                              'TerraCrop',
                              style: TextStyle(
                                color: ink,
                                fontSize: 35,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Center(
                  child: Transform.translate(
                    offset: Offset(0, 168 + 17 * (1 - button)),
                    child: IgnorePointer(
                      ignoring: button < .99,
                      child: Opacity(
                        opacity: button,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 30),
                          child: SizedBox(
                            width: 280,
                            height: 56,
                            child: ElevatedButton.icon(
                              key: const Key('entry-login-button'),
                              onPressed: enter,
                              icon: const Icon(Icons.arrow_forward_rounded),
                              label: const Text(
                                'Iniciar sesión',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: Text(
                    'AGRICULTURA INTELIGENTE · MODO PRUEBA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: muted,
                      fontSize: 10,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});
  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  static const messages = [
    'Preparando tu campo inteligente...',
    'Conectando parcelas y cultivos...',
    'Analizando el estado de tu suelo...',
    'Todo listo para comenzar.',
  ];
  late final AnimationController growth = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..forward();
  Timer? finishTimer;

  @override
  void initState() {
    super.initState();
    finishTimer = Timer(const Duration(seconds: 4), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, _, _) => const AppShell(),
          transitionDuration: const Duration(milliseconds: 380),
          transitionsBuilder: (_, fade, _, child) =>
              FadeTransition(opacity: fade, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    finishTimer?.cancel();
    growth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: BrandBackdrop(
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const LogoMark(size: 138),
                const SizedBox(height: 8),
                const Text(
                  'TerraCrop',
                  style: TextStyle(
                    color: ink,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.2,
                  ),
                ),
                const SizedBox(height: 42),
                Container(
                  height: 128,
                  constraints: const BoxConstraints(maxWidth: 340),
                  padding: const EdgeInsets.fromLTRB(15, 6, 15, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x132D5C80),
                        blurRadius: 28,
                        offset: Offset(0, 12),
                      ),
                    ],
                  ),
                  child: AnimatedBuilder(
                    animation: growth,
                    builder: (context, _) => CustomPaint(
                      key: const Key('growing-plants'),
                      painter: _GrowingPlantsPainter(growth.value),
                      size: const Size(double.infinity, 112),
                    ),
                  ),
                ),
                const SizedBox(height: 26),
                AnimatedBuilder(
                  animation: growth,
                  builder: (context, _) {
                    final index = (growth.value * messages.length)
                        .floor()
                        .clamp(0, messages.length - 1);
                    return Column(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            messages[index],
                            key: ValueKey(index),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: ink,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Cuidando cada etapa de tus cultivos',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: muted, fontSize: 12),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _GrowingPlantsPainter extends CustomPainter {
  const _GrowingPlantsPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const plants = 7;
    final soilY = size.height - 24;
    final soil = Paint()..color = const Color(0xFFBE926B);
    final soilDark = Paint()..color = const Color(0xFF9E7556);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, soilY, size.width, 13),
        const Radius.circular(8),
      ),
      soil,
    );
    canvas.drawLine(
      Offset(0, soilY + 11),
      Offset(size.width, soilY + 11),
      soilDark..strokeWidth = 2,
    );

    for (var i = 0; i < plants; i++) {
      final x = size.width * (i + .5) / plants;
      final local = ((progress - i * .085) / .46).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final eased = Curves.easeOutCubic.transform(local);
      final height = (38 + (i.isEven ? 9 : 1)) * eased;
      final stem = Paint()
        ..color = const Color(0xFF389D70)
        ..strokeWidth = 3.4
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, soilY), Offset(x, soilY - height), stem);
      if (local > .22) {
        final leafScale = ((local - .22) / .78).clamp(0.0, 1.0);
        _leaf(
          canvas,
          Offset(x - 1, soilY - height * .58),
          -0.55,
          15 * leafScale,
        );
        _leaf(canvas, Offset(x + 1, soilY - height * .72), .55, 15 * leafScale);
      }
      if (local > .56) {
        final topScale = ((local - .56) / .44).clamp(0.0, 1.0);
        _leaf(canvas, Offset(x, soilY - height + 2), 0, 11 * topScale);
      }
    }
  }

  void _leaf(Canvas canvas, Offset base, double angle, double length) {
    if (length <= 0) return;
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromLTWH(-length * .23, -length, length * .46, length),
      Paint()..color = const Color(0xFF49B886),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GrowingPlantsPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
