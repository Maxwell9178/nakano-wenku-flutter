import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_update.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_dialog.dart';

/// 更新弹窗的用户选择。
enum UpdateDialogAction {
  /// 立即下载。
  download,

  /// 稍后提醒（本次版本不再自动弹出）。
  later,
}

/// 毛玻璃更新弹窗。
///
/// 展示新版本号与更新日志，只提供「立即下载 / 稍后提醒」两个出口，
/// 不做强制更新；用户点空白处等同于「稍后提醒」。
Future<UpdateDialogAction> showUpdateDialog(
  BuildContext context,
  AppVersionInfo info,
) async {
  final UpdateDialogAction? result = await showGlassDialog<UpdateDialogAction>(
    context: context,
    builder: (BuildContext context) {
      return GlassDialogCard(
        title: '发现新版本',
        english: 'NEW VERSION',
        content: _UpdateDialogBody(info: info),
        actions: <Widget>[
          GlassDialogButton(
            label: '立即下载',
            primary: true,
            onTap: () => Navigator.of(context).pop(UpdateDialogAction.download),
          ),
          GlassDialogButton(
            label: '稍后提醒',
            onTap: () => Navigator.of(context).pop(UpdateDialogAction.later),
          ),
        ],
      );
    },
  );
  return result ?? UpdateDialogAction.later;
}

class _UpdateDialogBody extends StatelessWidget {
  const _UpdateDialogBody({required this.info});

  final AppVersionInfo info;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Text(
              'v${info.versionName}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: AppColors.textPrimary(brightness),
              ),
            ),
            if (info.versionCode > 0) ...<Widget>[
              const SizedBox(width: 8),
              Text(
                'build ${info.versionCode}',
                style: AppTypography.englishLabel(
                  brightness,
                  fontSize: 9,
                  letterSpacing: 1.6,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ],
            if (info.preRelease) ...<Widget>[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.alpha(AppColors.accent(brightness), 0.5),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  '测试版',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.accent(brightness),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          '当前版本 v${AppConstants.versionName} · ${AppConstants.versionCode}',
          style: TextStyle(
            fontSize: 11,
            color: AppColors.textTertiary(brightness),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          '更新日志',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(brightness),
          ),
        ),
        const SizedBox(height: 6),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 168),
          child: SingleChildScrollView(
            child: Text(
              info.hasChangelog ? info.changelog : '本次更新没有附带说明。',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.7,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
