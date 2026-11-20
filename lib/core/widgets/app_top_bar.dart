import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'thin_divider.dart';

/// 顶部固定栏（书架主页使用，后续页面可复用）。
///
/// 需求：软件名 + 英文署名 + 细分割线，并且固定不随内容滑动消失。
/// 因此这里只负责「长什么样」，由页面把它放在不受滚动影响的位置。
class AppTopBar extends StatelessWidget {
  const AppTopBar({super.key, this.trailing, this.padding});

  /// 右侧可选操作（例如后续轮次的导入按钮）。
  final Widget? trailing;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color line = AppColors.divider(brightness);

    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(24, 10, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Text(
                AppConstants.appName,
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontFamilyFallback: AppFonts.serifFallback,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.6,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              const SizedBox(width: 12),
              // 中间的分割线（竖直细线）。
              Container(width: 0.8, height: 15, color: line),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppConstants.signature.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.englishLabel(
                    brightness,
                    fontSize: 8.6,
                    letterSpacing: 2.2,
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          const ThinDivider(thickness: 0.8),
        ],
      ),
    );
  }
}
