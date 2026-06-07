import 'package:flutter/material.dart';

const _kOrange = Color(0xFFF26500);

/// 3-dot onboarding progress indicator. [current] is the 0-based step index.
class OnboardingProgress extends StatelessWidget {
  final int current;
  final int total;
  const OnboardingProgress({super.key, required this.current, this.total = 3});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final active = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? _kOrange : Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
