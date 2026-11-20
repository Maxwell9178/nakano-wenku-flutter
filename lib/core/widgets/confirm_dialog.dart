import 'package:flutter/material.dart';

import 'glass_dialog.dart';

/// 通用二次确认毛玻璃弹窗。
///
/// 危险操作（删除书籍、删除章节、删除账号）统一用它，
/// 保证确认文案与视觉一致；返回 false 表示用户取消或点遮罩关闭。
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  String? english,
  String? message,
  String confirmLabel = '确认',
  String cancelLabel = '取消',
  bool danger = false,
}) async {
  final bool? result = await showGlassDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return GlassDialogCard(
        title: title,
        english: english,
        message: message,
        actions: <Widget>[
          GlassDialogButton(
            label: cancelLabel,
            onTap: () => Navigator.of(dialogContext).pop(false),
          ),
          GlassDialogButton(
            label: confirmLabel,
            primary: !danger,
            danger: danger,
            onTap: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      );
    },
  );
  return result ?? false;
}
