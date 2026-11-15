import 'dart:ui' show lerpDouble;

import 'package:provider/provider.dart';

import 'package:flutter/material.dart';

import '../screens/crops_screen.dart';
import '../screens/map_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/smart_cycle_screen.dart';
import '../screens/smart_market_screen.dart';
import 'app_theme.dart';
import 'app_appearance.dart';

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
  late final Animation<double> pageTransition = navigation.drive(
    CurveTween(curve: Curves.easeOutCubic),
  );
  final visited = <int>{0};

  static const labels = [
    'Mi perfil',
    'Smart-Cycle',
    'Cultivos',
    'Smart-Market',
    'MAPA',
  ];
  static const icons = [
    Icons.person_outline_rounded,
    Icons.cyclone_outlined,
    Icons.grass_outlined,
    Icons.storefront_outlined,
    Icons.map_outlined,
  ];

  @override
  void initState() {
    super.initState();
    navigation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      value: 1,
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
      visited.add(index);
      fromIndex = currentPosition;
      toIndex = index.toDouble();
    });
    navigation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ProfileScreen(),
      const SmartCycleScreen(),
      const CropsScreen(),
      const SmartMarketScreen(),
      const MapScreen(),
    ];
    return Scaffold(
      floatingActionButton: selected == 0 ? const _AppearanceButton() : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      body: SafeArea(
        bottom: false,
        child: FadeTransition(
          opacity: Tween<double>(begin: .65, end: 1).animate(pageTransition),
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(.035 * direction, 0),
              end: Offset.zero,
            ).animate(pageTransition),
            child: IndexedStack(
              index: selected,
              children: [
                for (var i = 0; i < pages.length; i++)
                  TickerMode(
                    enabled: selected == i,
                    child: visited.contains(i)
                        ? pages[i]
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
          child: Container(
            height: 82,
            decoration: BoxDecoration(
              color: context.colors.surface,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: context.colors.border, width: 1.6),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x263A607D),
                  blurRadius: 22,
                  spreadRadius: 1,
                  offset: Offset(0, 9),
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
                                    Color(0xFF16815E),
                                    Color(0xFF1769D2),
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
                                child: Semantics(
                                  button: true,
                                  selected: selected == i,
                                  child: InkWell(
                                    key: Key('nav-tab-$i'),
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
                                                    builder:
                                                        (_, scale, child) =>
                                                            Transform.scale(
                                                              scale: scale,
                                                              child: child,
                                                            ),
                                                    child: Icon(
                                                      icons[i],
                                                      size: 23,
                                                      color: Color.lerp(
                                                        context.colors.muted
                                                            .withValues(
                                                              alpha: .78,
                                                            ),
                                                        Colors.white,
                                                        (1 -
                                                                (position - i)
                                                                    .abs())
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
                                                      ? context.colors.blue
                                                      : context.colors.muted
                                                            .withValues(
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

class _AppearanceButton extends StatelessWidget {
  const _AppearanceButton();

  @override
  Widget build(BuildContext context) {
    final appearance = context.watch<AppAppearance?>();
    final dark =
        appearance?.isDark ?? Theme.of(context).brightness == Brightness.dark;
    final label = dark ? 'Activar modo claro' : 'Activar modo oscuro';
    return Semantics(
      label: label,
      button: true,
      toggled: dark,
      child: FloatingActionButton.small(
        key: const Key('profile-theme-toggle'),
        heroTag: 'profile-appearance',
        tooltip: label,
        backgroundColor: context.colors.softBlue,
        foregroundColor: context.colors.blue,
        elevation: 3,
        onPressed: appearance == null || appearance.saving
            ? null
            : () async {
                try {
                  await appearance.toggle();
                } catch (_) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No se pudo guardar la apariencia. Inténtalo de nuevo.',
                      ),
                    ),
                  );
                }
              },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
            key: ValueKey(dark),
          ),
        ),
      ),
    );
  }
}
