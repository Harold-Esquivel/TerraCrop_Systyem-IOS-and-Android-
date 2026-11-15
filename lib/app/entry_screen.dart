import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'app_theme.dart';
import 'brand.dart';
import 'growing_loading_view.dart';

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
                            child: Text(
                              'TerraCrop',
                              style: TextStyle(
                                color: context.colors.ink,
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
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 20,
                  child: Text(
                    'AGRICULTURA INTELIGENTE · MODO PRUEBA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: context.colors.muted,
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
    body: AnimatedBuilder(
      animation: growth,
      builder: (context, _) => GrowingLoadingView(
        progress: growth.value,
        messages: messages,
        subtitle: 'Cuidando cada etapa de tus cultivos',
      ),
    ),
  );
}
