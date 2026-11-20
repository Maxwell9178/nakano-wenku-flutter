import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'thin_divider.dart';

/// 通用占位面板。
///
/// 统一「中文标题在上 / 细分割线 / 小号英文标注」的排版范式，
/// 供尚未实现的页面（搜索、我的、导入等）复用，
/// 避免每个占位页各写一套样式。
class PlaceholderPanel extends StatelessWidget {
  const PlaceholderPanel({
    super.key,
    required this.title,
    required this.english,
    required this.description,
    this.icon = Icons.auto_stories_outlined,
    this.footer,
  });

  final String title;
  final String english;
  final String description;
  final IconData icon;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.divider(brightness),
                  width: 0.9,
                ),
              ),
              child: Icon(
                icon,
                size: 27,
                color: AppColors.textTertiary(brightness),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.chineseTitle(brightness, fontSize: 24),
            ),
            const SizedBox(height: 9),
            Text(
              english.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.englishLabel(
                brightness,
                fontSize: 9.5,
                letterSpacing: 2.8,
              ),
            ),
            const SizedBox(height: 16),
            const ThinDivider(width: 44, thickness: 0.9),
            const SizedBox(height: 16),
            Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 12.5,
                height: 1.8,
                letterSpacing: 0.3,
                color: AppColors.textSecondary(brightness),
              ),
            ),
            if (footer != null) ...<Widget>[
              const SizedBox(height: 22),
              Text(
                footer!,
                textAlign: TextAlign.center,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: 10.5,
                  letterSpacing: 1.0,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
