import 'dart:async';

import 'package:flutter/material.dart';
import 'app_theme.dart';

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.color = Colors.white,
    this.onTap,
  });
  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(22),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: border),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0B24446A),
              blurRadius: 22,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    ),
  );
}

class StaggerItem extends StatefulWidget {
  const StaggerItem({super.key, required this.index, required this.child});
  final int index;
  final Widget child;
  @override
  State<StaggerItem> createState() => _StaggerItemState();
}

class _StaggerItemState extends State<StaggerItem> {
  bool visible = false;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer(Duration(milliseconds: 60 * widget.index), () {
      if (mounted) setState(() => visible = true);
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
    opacity: visible ? 1 : 0,
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutCubic,
    child: AnimatedSlide(
      offset: visible ? Offset.zero : const Offset(0, .08),
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}

class PageIntro extends StatelessWidget {
  const PageIntro({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String eyebrow, title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 19, 22, 20),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow.toUpperCase(),
                style: const TextStyle(
                  color: blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.7,
                ),
              ),
              const SizedBox(height: 7),
              Text(title, style: Theme.of(context).textTheme.headlineLarge),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(color: muted, fontSize: 13),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class MetricPill extends StatelessWidget {
  const MetricPill({
    super.key,
    required this.icon,
    required this.label,
    this.color = green,
  });
  final IconData icon;
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .1),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class PressButton extends StatefulWidget {
  const PressButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.outlined = false,
  });
  final String label;
  final IconData? icon;
  final VoidCallback onPressed;
  final bool outlined;
  @override
  State<PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<PressButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => pressed = true),
    onTapCancel: () => setState(() => pressed = false),
    onTapUp: (_) {
      setState(() => pressed = false);
      widget.onPressed();
    },
    child: AnimatedScale(
      scale: pressed ? .96 : 1,
      duration: const Duration(milliseconds: 120),
      child: Container(
        height: 49,
        padding: const EdgeInsets.symmetric(horizontal: 17),
        decoration: BoxDecoration(
          color: widget.outlined ? Colors.white : blue,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: widget.outlined ? border : blue),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.icon != null) ...[
              Icon(
                widget.icon,
                size: 18,
                color: widget.outlined ? ink : Colors.white,
              ),
              const SizedBox(width: 7),
            ],
            Text(
              widget.label,
              style: TextStyle(
                color: widget.outlined ? ink : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
