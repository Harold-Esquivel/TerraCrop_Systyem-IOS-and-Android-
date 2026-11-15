import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../screens/crops_screen.dart';
import '../screens/devices_screen.dart';
import '../screens/map_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/test_screen.dart';
import 'app_theme.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  int selected = 0;
  int direction = 1;
  double fromIndex = 0;
  double toIndex = 0;
  late final AnimationController navigation;

  static const labels = [
    'Mapa',
    'Mis cultivos',
    'Dispositivos',
    'Mi perfil',
    'Modo prueba',
  ];
  static const icons = [
    Icons.map_outlined,
    Icons.grass_outlined,
    Icons.sensors_outlined,
    Icons.person_outline_rounded,
    Icons.science_outlined,
  ];

  @override
  void initState() {
    super.initState();
    navigation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
  }

  @override
  void dispose() {
    navigation.dispose();
    super.dispose();
  }

  double get visualIndex => lerpDouble(
    fromIndex,
    toIndex,
    Curves.easeInOutCubic.transform(navigation.value),
  )!;

  void select(int index) {
    if (index == selected) return;
    final currentPosition = visualIndex;
    setState(() {
      direction = index > selected ? 1 : -1;
      selected = index;
      fromIndex = currentPosition;
      toIndex = index.toDouble();
    });
    navigation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const MapScreen(),
      const CropsScreen(),
      const DevicesScreen(),
      const ProfileScreen(),
      const TestScreen(),
    ];
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (child, animation) {
            final incoming = child.key == ValueKey(selected);
            final offset = Tween<Offset>(
              begin: Offset(incoming ? .08 * direction : -.08 * direction, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: child),
            );
          },
          child: KeyedSubtree(key: ValueKey(selected), child: pages[selected]),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: Container(
            height: 82,
            decoration: BoxDecoration(
              color: const Color(0xFFFCFEFF),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white, width: 1.6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x263A607D),
                  blurRadius: 22,
                  spreadRadius: 1,
                  offset: Offset(0, 9),
                ),
                BoxShadow(
                  color: Colors.white,
                  blurRadius: 10,
                  offset: Offset(-3, -4),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final itemWidth = constraints.maxWidth / 5;
                return AnimatedBuilder(
                  animation: navigation,
                  builder: (context, _) {
                    final position = visualIndex;
                    return Stack(
                      children: [
                        Positioned(
                          left: position * itemWidth + (itemWidth - 44) / 2,
                          top: 8,
                          child: IgnorePointer(
                            child: Container(
                              key: const Key('nav-selection-indicator'),
                              width: 44,
                              height: 44,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF3988F0),
                                    Color(0xFF226BDD),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0x552671E8),
                                    blurRadius: 12,
                                    offset: Offset(0, 5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            for (var i = 0; i < 5; i++)
                              SizedBox(
                                width: itemWidth,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(19),
                                  onTap: () => select(i),
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Column(
                                      children: [
                                        SizedBox(
                                          height: 50,
                                          child: Center(
                                            child:
                                                TweenAnimationBuilder<double>(
                                                  key: ValueKey(
                                                    'nav-$i-$selected',
                                                  ),
                                                  tween: Tween(
                                                    begin: i == selected
                                                        ? 1.14
                                                        : 1,
                                                    end: 1,
                                                  ),
                                                  duration: const Duration(
                                                    milliseconds: 380,
                                                  ),
                                                  curve: Curves.elasticOut,
                                                  builder: (_, scale, child) =>
                                                      Transform.scale(
                                                        scale: scale,
                                                        child: child,
                                                      ),
                                                  child: Icon(
                                                    icons[i],
                                                    size: 23,
                                                    color: Color.lerp(
                                                      muted.withValues(
                                                        alpha: .78,
                                                      ),
                                                      Colors.white,
                                                      (1 - (position - i).abs())
                                                          .clamp(0, 1),
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        SizedBox(
                                          width: itemWidth - 6,
                                          child: FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: Text(
                                              labels[i],
                                              style: TextStyle(
                                                fontSize: 10,
                                                letterSpacing: -.15,
                                                color: i == selected
                                                    ? blue
                                                    : muted.withValues(
                                                        alpha: .85,
                                                      ),
                                                fontWeight: i == selected
                                                    ? FontWeight.w800
                                                    : FontWeight.w600,
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
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
