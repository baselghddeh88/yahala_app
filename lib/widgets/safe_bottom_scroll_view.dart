import 'package:flutter/material.dart';

class SafeBottomScrollView extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final ScrollController? controller;

  const SafeBottomScrollView({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return SingleChildScrollView(
      controller: controller,
      padding: padding.copyWith(bottom: padding.bottom + bottomInset + 24),
      child: child,
    );
  }
}
