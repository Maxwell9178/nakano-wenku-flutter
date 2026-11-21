import 'package:flutter/material.dart';

import '../../../core/services/book_import_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/thin_divider.dart';

/// 导入过程中的小型进度卡片：逐文件进度 + 完成打勾。
///
/// 浮在页面底部，导入结束后由调用方决定何时移除。
class ImportProgressCard extends StatelessWidget {
  const ImportProgressCard({
    super.key,
    required this.progresses,
  });

  final List<ImportProgress> progresses;

  bool get _allDone =>
      progresses.isNotEmpty && progresses.every((ImportProgress p) => p.done);

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return LiquidGlass(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _allDone
                    ? Icons.check_circle_rounded
                    : Icons.auto_awesome_outlined,
                size: 16,
                color: _allDone
                    ? AppColors.accent(brightness)
                    : AppColors.textSecondary(brightness),
              ),
              const SizedBox(width: 8),
              Text(
                _allDone ? '导入完成' : '正在导入',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              const Spacer(),
              Text(
                '${progresses.where((ImportProgress p) => p.done).length}'
                ' / ${progresses.length}',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final ImportProgress progress in progresses.take(3)) ...<Widget>[
            _ProgressRow(progress: progress),
            const SizedBox(height: 9),
          ],
          if (progresses.length > 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '还有 ${progresses.length - 3} 个文件正在处理',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ),
          ThinDivider(
            thickness: 0.7,
            color: AppColors.alpha(AppColors.divider(brightness), 0.8),
            margin: const EdgeInsets.only(top: 2, bottom: 8),
          ),
          Text(
            _allDone ? '已全部写入本地书架，可返回查看。' : '解析与入库全部在本机完成，不会上传任何文件。',
            style: TextStyle(
              fontSize: 9.5,
              height: 1.5,
              color: AppColors.textTertiary(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.progress});

  final ImportProgress progress;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = AppColors.accent(brightness);
    final double fraction = progress.fraction.clamp(0.0, 1.0).toDouble();

    return Row(
      children: <Widget>[
        SizedBox(
          width: 18,
          height: 18,
          child: progress.done
              ? Icon(
                  progress.failed
                      ? Icons.error_outline_rounded
                      : Icons.check_rounded,
                  size: 15,
                  color: progress.failed
                      ? AppColors.danger
                      : AppColors.accent(brightness),
                )
              : SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.6,
                    value: fraction,
                    color: accent,
                    backgroundColor:
                        AppColors.alpha(AppColors.divider(brightness), 0.7),
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                progress.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: 5),
              ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: SizedBox(
                  height: 2.4,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        flex: (fraction * 1000).round().clamp(0, 1000),
                        child: Container(
                          color: progress.failed
                              ? AppColors.alpha(AppColors.danger, 0.6)
                              : AppColors.alpha(accent, 0.72),
                        ),
                      ),
                      Expanded(
                        flex: 1000 - (fraction * 1000).round().clamp(0, 1000),
                        child: Container(
                          color: AppColors.alpha(
                              AppColors.divider(brightness), 0.55),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 62,
          child: Text(
            progress.message ?? '${(fraction * 100).round()}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 9.5,
              color: progress.failed
                  ? AppColors.danger
                  : AppColors.textTertiary(brightness),
            ),
          ),
        ),
      ],
    );
  }
}

/// 导入页底部的一行小提示（英文标注风格）。
class ImportHintLine extends StatelessWidget {
  const ImportHintLine({super.key, required this.english, required this.text});

  final String english;
  final String text;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          english.toUpperCase(),
          style: AppTypography.englishLabel(brightness, fontSize: 8.6)
              .copyWith(color: AppColors.textTertiary(brightness)),
        ),
        const SizedBox(height: 6),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.6,
            color: AppColors.textSecondary(brightness),
          ),
        ),
      ],
    );
  }
}
