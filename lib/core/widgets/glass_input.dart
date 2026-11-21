import 'package:flutter/material.dart';

import '../settings/app_settings.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'glass_dialog.dart';
import 'liquid_glass.dart';
import 'pressable_scale.dart';

/// 毛玻璃输入弹窗：书签备注、批注、分组名、快捷站点编辑都用它。
///
/// 返回值：确认时是去掉首尾空白的文本（允许为空串），取消时是 null。
Future<String?> showGlassInputDialog({
  required BuildContext context,
  required String title,
  String? english,
  String? hint,
  String initialValue = '',
  int maxLines = 1,
  String confirmLabel = '确定',
  String cancelLabel = '取消',
}) {
  return showGlassDialog<String>(
    context: context,
    builder: (BuildContext dialogContext) => _GlassInputDialog(
      title: title,
      english: english,
      hint: hint,
      initialValue: initialValue,
      maxLines: maxLines,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
    ),
  );
}

class _GlassInputDialog extends StatefulWidget {
  const _GlassInputDialog({
    required this.title,
    required this.english,
    required this.hint,
    required this.initialValue,
    required this.maxLines,
    required this.confirmLabel,
    required this.cancelLabel,
  });

  final String title;
  final String? english;
  final String? hint;
  final String initialValue;
  final int maxLines;
  final String confirmLabel;
  final String cancelLabel;

  @override
  State<_GlassInputDialog> createState() => _GlassInputDialogState();
}

class _GlassInputDialogState extends State<_GlassInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color textColor = AppColors.textPrimary(Theme.of(context).brightness);
    final Color accent = AppColors.accent(Theme.of(context).brightness);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: LiquidGlass(
            borderRadius: 24,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  widget.title,
                  style: AppTypography.chineseTitle(
                          Theme.of(context).brightness,
                          fontSize: 18)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                if (widget.english != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    widget.english!.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8.4,
                      letterSpacing: 2.2,
                      color: AppColors.alpha(textColor, 0.68),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.alpha(textColor, 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.alpha(textColor, 0.16),
                      width: 0.8,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    maxLines: widget.maxLines,
                    minLines: 1,
                    textInputAction: widget.maxLines > 1
                        ? TextInputAction.newline
                        : TextInputAction.done,
                    onSubmitted: widget.maxLines > 1 ? null : (_) => _submit(),
                    cursorColor: accent,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: textColor,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      hintText: widget.hint,
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.alpha(textColor, 0.45),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: <Widget>[
                    _DialogButton(
                      label: widget.cancelLabel,
                      onTap: () => Navigator.of(context).pop(),
                      isDark: isDark,
                    ),
                    const SizedBox(width: 10),
                    _DialogButton(
                      label: widget.confirmLabel,
                      primary: true,
                      onTap: _submit,
                      isDark: isDark,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  const _DialogButton({
    required this.label,
    required this.onTap,
    required this.isDark,
    this.primary = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final Color textColor = AppColors.textPrimary(Theme.of(context).brightness);
    final Color accent = AppColors.accent(Theme.of(context).brightness);

    return PressableScale(
      pressedScale: 0.96,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: primary
              ? AppColors.alpha(accent, 0.90)
              : AppColors.alpha(textColor, 0.06),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: primary
                ? AppColors.alpha(accent, 0.90)
                : AppColors.alpha(textColor, 0.18),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: primary ? FontWeight.w600 : FontWeight.w500,
            color: primary
                ? (isDark ? const Color(0xFF141414) : Colors.white)
                : textColor,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

/// 弹窗内的小号提示文字，避免每处重复写样式。
class DialogHintText extends StatelessWidget {
  const DialogHintText(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 11.5,
        height: 1.65,
        color: AppColors.alpha(
            AppColors.textPrimary(Theme.of(context).brightness), 0.62),
      ),
    );
  }
}

/// 供弹窗内部使用的动效时长（减少动画时归零）。
Duration dialogMotion(int milliseconds) =>
    AppSettingsController.motion(milliseconds);
