import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'thin_divider.dart';

/// 全局固定排版范式。
///
/// 需求：中文大标题在上层，下方是小号英文标注，二者之间用一根细横线分隔。
/// 所有页面标题统一使用本组件，禁止各自拼装。
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.english,
    this.alignment = CrossAxisAlignment.start,
    this.trailing,
    this.dividerWidth = 38,
    this.titleStyle,
    this.englishStyle,
    this.padding = EdgeInsets.zero,
  });

  /// 中文大标题。
  final String title;

  /// 英文标注（内部自动转大写 + 宽字距）。
  final String english;

  final CrossAxisAlignment alignment;

  /// 标题右侧附加内容（例如数量、跳转箭头）。
  final Widget? trailing;

  final double dividerWidth;

  final TextStyle? titleStyle;
  final TextStyle? englishStyle;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = AppColors.accent(brightness);

    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle ??
                      AppTypography.chineseTitle(brightness, fontSize: 22),
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: 10),
          ThinDivider(
            width: dividerWidth,
            thickness: 1.0,
            gradient: LinearGradient(
              colors: <Color>[
                AppColors.alpha(accent, 0.85),
                AppColors.alpha(accent, 0.12),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            english.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: englishStyle ?? AppTypography.englishLabel(brightness),
          ),
        ],
      ),
    );
  }
}
