import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'pressable_scale.dart';

/// 细线描边按钮（次级操作）。
///
/// 需求要求页面分割元素与装饰元素统一使用细线条，因此次级按钮
/// 采用「一根细边 + 透明底」的轻量形态，点击时同样有内缩回弹反馈。
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.english,
    this.enabled = true,
    this.expand = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    this.accent = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  /// 可选的小号英文标注，显示在中文下方。
  final String? english;

  final bool enabled;

  /// 是否占满父级宽度。
  final bool expand;

  final EdgeInsetsGeometry padding;

  /// 使用强调色描边，否则使用中性分割线颜色。
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accentColor = accent
        ? AppColors.accent(brightness)
        : AppColors.textSecondary(brightness);
    final Color borderColor = AppColors.alpha(
      accentColor,
      enabled ? 0.45 : 0.18,
    );

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          expand ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(
                icon,
                size: 17,
                color: enabled
                    ? AppColors.textPrimary(brightness)
                    : AppColors.textTertiary(brightness),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: enabled
                      ? AppColors.textPrimary(brightness)
                      : AppColors.textTertiary(brightness),
                ),
              ),
            ),
          ],
        ),
        if (english != null && english!.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            english!.toUpperCase(),
            textAlign: expand ? TextAlign.center : TextAlign.start,
            style: AppTypography.englishLabel(
              brightness,
              fontSize: 9.5,
              color: AppColors.textTertiary(brightness),
            ),
          ),
        ],
      ],
    );

    final Widget button = Container(
      width: expand ? double.infinity : null,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 0.9),
        color: AppColors.alpha(accentColor, 0.035),
      ),
      child: content,
    );

    return PressableScale(
      enabled: enabled,
      onTap: onTap,
      pressedScale: 0.96,
      child: button,
    );
  }
}
