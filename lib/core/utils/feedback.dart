import 'package:flutter/material.dart';

/// 统一的轻量提示（不打断操作的浮动 SnackBar）。
///
/// 项目要求「网络差/失败不要弹报错弹窗打扰用户」，
/// 因此所有可恢复的提示都走这个入口，保持克制。
void showSoftMessage(BuildContext context, String message) {
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) {
    return;
  }
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 2200),
    ),
  );
}
