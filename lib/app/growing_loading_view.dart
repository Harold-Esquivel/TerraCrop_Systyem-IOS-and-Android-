import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'brand.dart';

/// Shared presentation for the entry and simulation loading screens.
class GrowingLoadingView extends StatelessWidget {
  const GrowingLoadingView({
    super.key,
    required this.progress,
    required this.messages,
    required this.subtitle,
  });
  final double progress;
  final List<String> messages;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final index = (progress * messages.length).floor().clamp(
      0,
      messages.length - 1,
    );
    return BrandBackdrop(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
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
                  child: CustomPaint(
                    key: const Key('growing-plants'),
                    painter: _GrowingPlantsPainter(progress),
                    size: const Size(double.infinity, 112),
                  ),
                ),
                const SizedBox(height: 26),
                Semantics(
                  liveRegion: true,
                  child: AnimatedSwitcher(
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
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
