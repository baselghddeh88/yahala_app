import 'dart:math' as math;

import 'package:flutter/material.dart';

const Color _green = Color(0xFF1a6b3c);
const Color _gold = Color(0xFFc9952a);

class PromotedAdFrame extends StatefulWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsetsGeometry margin;
  final BorderRadius borderRadius;

  const PromotedAdFrame({
    super.key,
    required this.child,
    required this.isDark,
    this.margin = EdgeInsets.zero,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  @override
  State<PromotedAdFrame> createState() => _PromotedAdFrameState();
}

class _PromotedAdFrameState extends State<PromotedAdFrame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Container(
            margin: widget.margin,
            padding: const EdgeInsets.all(2.2),
            decoration: BoxDecoration(
              borderRadius: widget.borderRadius,
              gradient: SweepGradient(
                transform: GradientRotation(_controller.value * math.pi * 2),
                colors: [
                  _gold.withValues(alpha: 0.34),
                  _gold,
                  Colors.white.withValues(alpha: widget.isDark ? 0.82 : 0.96),
                  _green.withValues(alpha: 0.9),
                  _gold,
                  _gold.withValues(alpha: 0.34),
                ],
                stops: const [0, 0.22, 0.34, 0.48, 0.72, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: _gold.withValues(alpha: widget.isDark ? 0.18 : 0.22),
                  blurRadius: 14,
                  spreadRadius: 0.5,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: widget.borderRadius.subtract(
                const BorderRadius.all(Radius.circular(2)),
              ),
              child: child,
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}
