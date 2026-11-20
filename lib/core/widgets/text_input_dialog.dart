import 'package:flutter/material.dart';

import 'glass_dialog.dart';

/// 通用「单行文本输入」毛玻璃弹窗。
///
/// 用于修改书名 / 作者 / 编号，以及新增网站快捷小球等场景；
/// 校验失败时在输入框下方就地提示，不关闭弹窗。
/// 返回 null 表示用户取消。
Future<String?> showTextInputDialog({
  required BuildContext context,
  required String title,
  String? english,
  String? message,
  String initialValue = '',
  String hintText = '',
  int maxLength = 60,
  String confirmLabel = '保存',
  String cancelLabel = '取消',
  String? Function(String value)? validator,
  bool allowEmpty = false,
  TextInputType? keyboardType,
}) async {
  final TextEditingController controller =
      TextEditingController(text: initialValue);

  try {
    return await showGlassDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        String? errorText;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            void submit() {
              final String value = controller.text.trim();
              if (!allowEmpty && value.isEmpty) {
                setState(() => errorText = '内容不能为空');
                return;
              }
              final String? validation = validator?.call(value);
              if (validation != null) {
                setState(() => errorText = validation);
                return;
              }
              Navigator.of(dialogContext).pop(value);
            }

            return GlassDialogCard(
              title: title,
              english: english,
              message: message,
              content: TextField(
                controller: controller,
                autofocus: true,
                maxLength: maxLength,
                keyboardType: keyboardType,
                textInputAction: TextInputAction.done,
                onSubmitted: (String _) => submit(),
                decoration: InputDecoration(
                  hintText: hintText,
                  errorText: errorText,
                  counterText: '',
                ),
              ),
              actions: <Widget>[
                GlassDialogButton(
                  label: cancelLabel,
                  onTap: () => Navigator.of(dialogContext).pop(),
                ),
                GlassDialogButton(
                  label: confirmLabel,
                  primary: true,
                  onTap: submit,
                ),
              ],
            );
          },
        );
      },
    );
  } finally {
    controller.dispose();
  }
}
