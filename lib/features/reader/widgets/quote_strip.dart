import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass.dart';
import 'reader_background.dart';

/// 沉浸模式底部的极细液态玻璃长条，随机展示一条名言。
class QuoteStrip extends StatelessWidget {
  const QuoteStrip({
    super.key,
    required this.quote,
    required this.backgroundId,
  });

  final String quote;
  final String backgroundId;

  @override
  Widget build(BuildContext context) {
    if (quote.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool dark = ReaderBackgroundView.isDarkBackground(backgroundId);
    final Color color = dark
        ? AppColors.alpha(const Color(0xFFF2F2EE), 0.66)
        : AppColors.alpha(const Color(0xFF1A1A1A), 0.62);

    return LiquidGlass(
      borderRadius: 12,
      tint: dark ? Colors.white : Colors.black,
      opacity: 0.06,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      shadows: false,
      child: Text(
        quote,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 9.5,
          height: 1.4,
          letterSpacing: 0.6,
          color: color,
        ),
      ),
    );
  }
}
