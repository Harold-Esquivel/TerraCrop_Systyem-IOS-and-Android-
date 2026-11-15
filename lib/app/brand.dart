import 'package:flutter/material.dart';

import 'app_theme.dart';

const terraLogoAsset =
    'assets/images/Gemini_Generated_Image_uamzuamzuamzuamz-removebg-preview.png';

/// Crops only transparent padding at display time. The supplied asset is intact.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    final imageSize = size * 500 / 241;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: OverflowBox(
          minWidth: imageSize,
          maxWidth: imageSize,
          minHeight: imageSize,
          maxHeight: imageSize,
          child: Transform.translate(
            offset: Offset(0, size * 62.5 / 241),
            child: Image.asset(
              terraLogoAsset,
              width: imageSize,
              height: imageSize,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}

class BrandBackdrop extends StatelessWidget {
  const BrandBackdrop({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, canvas, const Color(0xFFF0F7FF)],
            ),
          ),
        ),
      ),
      Positioned(
        top: -105,
        right: -105,
        child: _Glow(size: 290, color: paleBlue),
      ),
      Positioned(
        bottom: -120,
        left: -100,
        child: _Glow(size: 270, color: const Color(0xFFE7F6EC)),
      ),
      Positioned.fill(child: child),
    ],
  );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
    ),
  );
}
