import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/models/book.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/thin_divider.dart';

/// 书籍封面绘制组件。
///
/// 需求：书本基底统一为灰色，封面使用书籍自带图片并绘制真实立体透视，
/// 书脊上竖排打印白色编号 NW-XXXX。
/// 尚未导入封面的书籍由这里绘制「灰底 + 书名 + 作者 + 细线」的占位封面，
/// 保证书架不会出现空白块。
class BookCoverArt extends StatelessWidget {
  const BookCoverArt({
    super.key,
    required this.book,
    required this.width,
    required this.height,
    this.sideFade = 0,
    this.dense = false,
  });

  final Book book;
  final double width;
  final double height;

  /// 侧边书籍的黑色书脊遮罩程度：0 = 正面完整封面，1 = 只留黑书脊。
  final double sideFade;

  /// 列表缩略图使用紧凑绘制（不显示书脊文字与多行书名）。
  final bool dense;

  static const BorderRadius _radius = BorderRadius.only(
    topLeft: Radius.circular(2),
    bottomLeft: Radius.circular(2),
    topRight: Radius.circular(4),
    bottomRight: Radius.circular(4),
  );

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final double spineWidth = (width * 0.075).clamp(7.0, 12.0).toDouble();

    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.alpha(Colors.black, 0.30 - sideFade * 0.16),
              blurRadius: 24,
              spreadRadius: -6,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: _radius,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              _buildCover(brightness, dense),

              // 右侧黑色书脊 + 白色编号。
              if (!dense)
                Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: spineWidth,
                  child: ColoredBox(
                    color: const Color(0xFF191919),
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 1,
                        child: Text(
                          book.id,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize:
                                (spineWidth * 0.72).clamp(6.5, 9.0).toDouble(),
                            letterSpacing: 1.2,
                            color: AppColors.alpha(Colors.white, 0.82),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

              // 书脊左侧一条极细高光，增强立体感。
              if (!dense)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: spineWidth,
                  child: Container(
                    width: 0.8,
                    color: AppColors.alpha(Colors.white, 0.18),
                  ),
                ),

              // 侧边书只保留黑色书脊：随距离逐渐压黑封面。
              if (sideFade > 0)
                ColoredBox(
                  color: AppColors.alpha(
                    const Color(0xFF121212),
                    0.92 * sideFade,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// 取书名首个字形（按 Unicode 码点，不会切坏中文字符）。
  static String _firstGlyph(String title) {
    if (title.isEmpty) {
      return '书';
    }
    return String.fromCharCode(title.runes.first);
  }

  Widget _buildCover(Brightness brightness, bool dense) {
    final String? path = book.coverPath;

    if (path != null && path.isNotEmpty) {
      return Image.file(
        File(path),
        fit: BoxFit.cover,
        // 封面文件被用户删除时不报错，回落到绘制封面。
        errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
          return _buildPlaceholder(brightness, dense);
        },
      );
    }

    return _buildPlaceholder(brightness, dense);
  }

  Widget _buildPlaceholder(Brightness brightness, bool dense) {
    // 无论深浅主题，书本基底都是灰色（需求硬性规定）。
    final List<Color> baseColors = brightness == Brightness.dark
        ? const <Color>[Color(0xFF4C4C4C), Color(0xFF2B2B2B)]
        : const <Color>[Color(0xFF5A5A5A), Color(0xFF3A3A3A)];

    if (dense) {
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: baseColors,
          ),
        ),
        child: Center(
          child: Text(
            _firstGlyph(book.title),
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: (width * 0.42).clamp(12.0, 22.0).toDouble(),
              fontWeight: FontWeight.w600,
              color: AppColors.alpha(Colors.white, 0.88),
            ),
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: baseColors,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          width * 0.11,
          width * 0.12,
          width * 0.16,
          width * 0.10,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              book.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: (width * 0.115).clamp(11.0, 20.0).toDouble(),
                height: 1.4,
                letterSpacing: 0.4,
                fontWeight: FontWeight.w600,
                color: AppColors.alpha(Colors.white, 0.92),
              ),
            ),
            const Spacer(),
            ThinDivider(
              width: (width * 0.34).clamp(18.0, 54.0).toDouble(),
              thickness: 0.8,
              color: AppColors.alpha(Colors.white, 0.35),
            ),
            const SizedBox(height: 6),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: (width * 0.072).clamp(7.5, 11.0).toDouble(),
                letterSpacing: 0.3,
                color: AppColors.alpha(Colors.white, 0.66),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
