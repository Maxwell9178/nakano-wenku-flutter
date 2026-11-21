import 'package:flutter/material.dart';

import '../../../core/models/book.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/pressable_scale.dart';

/// 3D 轮播下方信息区：书名 / 作者 / 连载状态 + 进入详情的箭头按钮。
///
/// 该区域随轮播居中书籍实时刷新；文字用 AnimatedSwitcher 做柔和淡入，
/// 即使高速滑动也不会出现生硬跳变。
class BookInfoPanel extends StatelessWidget {
  const BookInfoPanel({
    super.key,
    required this.book,
    required this.onOpenDetail,
  });

  final Book book;
  final VoidCallback onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (Widget? current, List<Widget> previous) {
                return Stack(
                  alignment: Alignment.bottomLeft,
                  children: <Widget>[
                    ...previous,
                    if (current != null) current,
                  ],
                );
              },
              child: Column(
                key: ValueKey<int>(book.number),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    book.title,
                    // 长书名自动换行，不用省略号截断，卷号信息必须完整可见。
                    softWrap: true,
                    style: AppTypography.chineseTitle(
                      brightness,
                      fontSize: 23,
                    ).copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      height: 1.28,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: <Widget>[
                      Flexible(
                        child: Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 12,
                            letterSpacing: 0.3,
                            color: AppColors.textSecondary(
                              theme.brightness,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 2.5,
                        height: 2.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.textTertiary(theme.brightness),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        book.seriesStatus.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          letterSpacing: 0.4,
                          color: book.seriesStatus == BookSeriesStatus.completed
                              ? AppColors.accent(theme.brightness)
                              : AppColors.textSecondary(theme.brightness),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 14),
          PressableScale(
            pressedScale: 0.92,
            onTap: onOpenDetail,
            child: LiquidGlass(
              borderRadius: 22,
              borderWidth: 0.9,
              padding: EdgeInsets.zero,
              tint: AppColors.accent(theme.brightness),
              opacity: 0.10,
              shadows: false,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 19,
                  color: AppColors.accent(theme.brightness),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
