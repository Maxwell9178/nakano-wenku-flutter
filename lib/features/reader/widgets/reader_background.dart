import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/models/reading_preferences.dart';
import '../../../core/widgets/grid_background.dart';

/// 阅读页背景。
///
/// 四种内置背景都带极淡的灰色网格纹理（与全局视觉一致）；
/// 用户上传的图片会先压暗再叠一层网格，保证正文仍然清晰。
class ReaderBackgroundView extends StatelessWidget {
  const ReaderBackgroundView({
    super.key,
    required this.backgroundId,
    required this.customPath,
    required this.child,
  });

  final String backgroundId;
  final String? customPath;
  final Widget child;

  /// 深色底（纯黑 / 深蓝）需要浅色文字。
  static bool isDarkBackground(String id) {
    return id == ReadingBackground.blackId || id == ReadingBackground.navyId;
  }

  /// 正文颜色。
  static Color textColor(String id) {
    if (isDarkBackground(id)) {
      return const Color(0xFFF2F2EE);
    }
    if (id == ReadingBackground.paperId) {
      return const Color(0xFF3B3021);
    }
    return const Color(0xFF1A1A1A);
  }

  /// 次要文字（章节号、提示语）颜色。
  static Color secondaryTextColor(String id) {
    if (isDarkBackground(id)) {
      return const Color(0x99F2F2EE);
    }
    if (id == ReadingBackground.paperId) {
      return const Color(0x993B3021);
    }
    return const Color(0x991A1A1A);
  }

  /// 内置背景下使用的底色（设置页预览也复用它）。
  static Color baseColor(String id) {
    switch (id) {
      case ReadingBackground.blackId:
        return const Color(0xFF000000);
      case ReadingBackground.navyId:
        return const Color(0xFF0E1E2C);
      case ReadingBackground.paperId:
        return const Color(0xFFF3E8CE);
      case ReadingBackground.lightId:
      default:
        return const Color(0xFFF7F7F4);
    }
  }

  static Color _gridColor(String id) {
    if (isDarkBackground(id)) {
      return const Color(0x14FFFFFF);
    }
    if (id == ReadingBackground.paperId) {
      return const Color(0x147A5F32);
    }
    return const Color(0x0F000000);
  }

  @override
  Widget build(BuildContext context) {
    final String? path = customPath;
    if (path != null && path.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.file(
            File(path),
            fit: BoxFit.cover,
            errorBuilder: (BuildContext context, Object error,
                StackTrace? stackTrace) {
              return Container(color: const Color(0xFF101010));
            },
          ),
          const ColoredBox(color: Color(0x8C000000)),
          const IgnorePointer(
            child: CustomPaint(
              painter: GridPainter(
                lineColor: Color(0x1AFFFFFF),
                step: 46,
                strokeWidth: 0.6,
              ),
            ),
          ),
          child,
        ],
      );
    }

    return Container(
      color: baseColor(backgroundId),
      child: CustomPaint(
        painter: GridPainter(
          lineColor: _gridColor(backgroundId),
          step: 46,
          strokeWidth: 0.7,
        ),
        child: child,
      ),
    );
  }
}
