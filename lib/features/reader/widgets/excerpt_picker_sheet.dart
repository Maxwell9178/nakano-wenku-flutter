import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/thin_divider.dart';

/// 摘抄选择弹窗：从当前章节的段落里挑一段存入摘抄库。
///
/// 需求约定摘抄要同时记录书名与章节，书名由调用方（阅读页控制器）补齐，
/// 这里只负责把用户选中的段落返回。
Future<String?> showExcerptPickerSheet(
  BuildContext context, {
  required String chapterTitle,
  required List<String> paragraphs,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.alpha(Colors.black, 0.38),
    builder: (BuildContext context) => _ExcerptPickerSheet(
      chapterTitle: chapterTitle,
      paragraphs: paragraphs,
    ),
  );
}

class _ExcerptPickerSheet extends StatefulWidget {
  const _ExcerptPickerSheet({
    required this.chapterTitle,
    required this.paragraphs,
  });

  final String chapterTitle;
  final List<String> paragraphs;

  @override
  State<_ExcerptPickerSheet> createState() => _ExcerptPickerSheetState();
}

class _ExcerptPickerSheetState extends State<_ExcerptPickerSheet> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final double maxHeight = MediaQuery.of(context).size.height * 0.72;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: FrostedGlass(
        borderRadius: 26,
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                Text(
                  '摘抄',
                  style: AppTypography.chineseTitle(brightness, fontSize: 20),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'EXCERPT',
                    style: AppTypography.englishLabel(
                      brightness,
                      fontSize: 8.6,
                      letterSpacing: 2.4,
                    ),
                  ),
                ),
                const Spacer(),
                PressableScale(
                  pressedScale: 0.9,
                  onTap: () => Navigator.of(context).maybePop(),
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.chapterTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textTertiary(brightness),
              ),
            ),
            const SizedBox(height: 12),
            ThinDivider(thickness: 0.8, color: AppColors.divider(brightness)),
            const SizedBox(height: 10),
            Expanded(
              child: widget.paragraphs.isEmpty
                  ? Center(
                      child: Text(
                        '本章还没有可摘抄的段落',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary(brightness),
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: widget.paragraphs.length,
                      separatorBuilder: (BuildContext context, int index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final bool selected = _selected == index;
                        final String text = widget.paragraphs[index];
                        return PressableScale(
                          pressedScale: 0.985,
                          onTap: () => setState(() => _selected = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: selected
                                  ? AppColors.alpha(
                                      AppColors.accent(brightness),
                                      0.10,
                                    )
                                  : AppColors.alpha(
                                      AppColors.textPrimary(brightness),
                                      0.025,
                                    ),
                              border: Border.all(
                                color: selected
                                    ? AppColors.alpha(
                                        AppColors.accent(brightness),
                                        0.45,
                                      )
                                    : AppColors.alpha(
                                        AppColors.textPrimary(brightness),
                                        0.08,
                                      ),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  selected
                                      ? Icons.radio_button_checked_rounded
                                      : Icons.radio_button_unchecked_rounded,
                                  size: 15,
                                  color: selected
                                      ? AppColors.accent(brightness)
                                      : AppColors.textTertiary(brightness),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    text,
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      height: 1.75,
                                      color: AppColors.textSecondary(brightness),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            LiquidGlass(
              borderRadius: 16,
              opacity: _selected == null ? 0.04 : 0.16,
              padding: const EdgeInsets.symmetric(vertical: 14),
              onTap: _selected == null
                  ? null
                  : () {
                      final String text =
                          widget.paragraphs[_selected!].trim();
                      Navigator.of(context).pop(text);
                    },
              child: Center(
                child: Text(
                  '保存这条摘抄',
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 1.6,
                    fontWeight: FontWeight.w600,
                    color: _selected == null
                        ? AppColors.textTertiary(brightness)
                        : AppColors.accent(brightness),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
