import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/thin_divider.dart';

/// 阅读页右侧的液态玻璃侧边条。
///
/// 上方竖排展示「书名-作者」，下方依次是
/// 阅读设置 / 摘抄 / 目录 三个矢量图标按钮。
/// 「上一章 / 下一章」按钮已按需求整体删除，章节切换只走目录。
class ReaderSidebar extends StatelessWidget {
  const ReaderSidebar({
    super.key,
    required this.bookLabel,
    required this.textColor,
    required this.onSettings,
    required this.onExcerpt,
    required this.onCatalog,
  });

  final String bookLabel;
  final Color textColor;
  final VoidCallback onSettings;
  final VoidCallback onExcerpt;
  final VoidCallback onCatalog;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      opacity: 0.10,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          RotatedBox(
            quarterTurns: 3,
            child: SizedBox(
              width: 96,
              child: Text(
                bookLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.5,
                  letterSpacing: 1.2,
                  color: AppColors.alpha(textColor, 0.62),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ThinDivider(
            width: 18,
            thickness: 0.7,
            color: AppColors.alpha(textColor, 0.22),
          ),
          const SizedBox(height: 8),
          _SideButton(
            icon: Icons.tune_rounded,
            tooltip: '阅读设置',
            color: textColor,
            onTap: onSettings,
          ),
          _SideButton(
            icon: Icons.format_quote_rounded,
            tooltip: '摘抄',
            color: textColor,
            onTap: onExcerpt,
          ),
          _SideButton(
            icon: Icons.format_list_bulleted_rounded,
            tooltip: '目录',
            color: textColor,
            onTap: onCatalog,
          ),
        ],
      ),
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Tooltip(
        message: tooltip,
        child: PressableScale(
          enabled: enabled,
          pressedScale: 0.9,
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.alpha(color, enabled ? 0.06 : 0.02),
            ),
            child: Icon(
              icon,
              size: 19,
              color: AppColors.alpha(color, enabled ? 0.82 : 0.28),
            ),
          ),
        ),
      ),
    );
  }
}
