import 'package:flutter/material.dart';

import '../../../core/models/book.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/thin_divider.dart';
import 'book_cover_art.dart';

/// 下半区纯文字书籍列表的单个条目。
///
/// 展示：封面缩略图、书名、作者、末尾阅读状态（已读完 / 未读完）。
class BookListItem extends StatelessWidget {
  const BookListItem({super.key, required this.book, required this.onTap});

  final Book book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Brightness brightness = theme.brightness;

    final Color statusColor = book.isFinished
        ? AppColors.accent(brightness)
        : AppColors.textTertiary(brightness);

    return PressableScale(
      pressedScale: 0.985,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  BookCoverArt(
                    book: book,
                    width: 44,
                    height: 60,
                    dense: true,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 15.5,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                book.isFinished ? '已读完' : '未读完',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontSize: 10.5,
                                  letterSpacing: 0.8,
                                  fontWeight: FontWeight.w500,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                book.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11.5,
                                  letterSpacing: 0.3,
                                  color: AppColors.textSecondary(brightness),
                                ),
                              ),
                            ),
                            Text(
                              book.id,
                              style: TextStyle(
                                fontFamily: AppFonts.serif,
                                fontFamilyFallback: AppFonts.serifFallback,
                                fontSize: 9.5,
                                letterSpacing: 1.0,
                                color: AppColors.textTertiary(brightness),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ThinDivider(
              thickness: 0.7,
              color: AppColors.alpha(AppColors.divider(brightness), 0.75),
            ),
          ],
        ),
      ),
    );
  }
}
