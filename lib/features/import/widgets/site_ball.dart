import 'package:flutter/material.dart';

import '../../../core/models/import_site.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/pressable_scale.dart';

/// 导入页顶部的网站快捷访问小球：圆形罗马数字 + 下方自定义站名。
///
/// 网址本身不在界面出现（只有设置弹窗里能看到并修改）。
class SiteBall extends StatelessWidget {
  const SiteBall({
    super.key,
    required this.site,
    required this.index,
    required this.onTap,
    this.onLongPress,
  });

  final ImportSite site;

  /// 在列表中的位置，决定小球里的罗马数字。
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color textColor = AppColors.textPrimary(brightness);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PressableScale(
          pressedScale: 0.92,
          onTap: onTap,
          onLongPress: onLongPress,
          child: LiquidGlass(
            borderRadius: 30,
            shadows: false,
            opacity: 0.10,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Center(
                child: Text(
                  ImportSite.romanLabel(index),
                  style: AppTypography.chineseTitle(brightness).copyWith(
                    fontSize: 16,
                    letterSpacing: 0.8,
                    color: textColor,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 66,
          child: Text(
            site.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              letterSpacing: 0.2,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ),
      ],
    );
  }
}

/// 「添加」小球，始终固定在第一位，方便用户快速新建站点。
class SiteBallAddButton extends StatelessWidget {
  const SiteBallAddButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color lineColor = AppColors.alpha(AppColors.accent(brightness), 0.42);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        PressableScale(
          pressedScale: 0.92,
          onTap: onTap,
          child: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: lineColor, width: 0.9),
              color: AppColors.alpha(lineColor, 0.06),
            ),
            child: Icon(
              Icons.add_rounded,
              size: 20,
              color: AppColors.accent(brightness),
            ),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 66,
          child: Text(
            '添加站点',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              height: 1.2,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ),
      ],
    );
  }
}
