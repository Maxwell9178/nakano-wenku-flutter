import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'thin_divider.dart';

/// 顶部固定栏（书架主页使用，后续页面可复用）。
///
/// 需求范式：软件名在上，英文署名紧贴其下方，二者之下是一根可见细分割线。
/// 第一轮修正：署名不再与标题挤在同一行（避免被右侧截断），
/// 分割线改用可见的浅灰色。
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, this.trailing, this.padding, this.leading});

  /// 右侧可选操作（例如导入入口）。
  final Widget? trailing;

  /// 左侧可选图标（书架主页放应用图标）。
  final Widget? leading;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color line = AppColors.alpha(
      brightness == Brightness.dark ? Colors.white : Colors.black,
      brightness == Brightness.dark ? 0.30 : 0.22,
    );

    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      AppConstants.appName,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: AppFonts.serif,
                        fontFamilyFallback: AppFonts.serifFallback,
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.6,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      AppConstants.signature.toUpperCase(),
                      maxLines: 1,
                      style: AppTypography.englishLabel(
                        brightness,
                        fontSize: 8.6,
                        letterSpacing: 2.2,
                        color: AppColors.textTertiary(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          ThinDivider(color: line, thickness: 0.8),
        ],
      ),
    );
  }
}
