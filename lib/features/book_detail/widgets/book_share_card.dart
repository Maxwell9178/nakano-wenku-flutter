import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/models/book.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/frosted_glass.dart';
import '../../../core/widgets/ghost_button.dart';
import '../../../core/widgets/grid_background.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/thin_divider.dart';
import '../../bookshelf/widgets/book_cover_art.dart';

/// 书籍信息分享卡片。
///
/// 纯本地绘制：封面 + 书名 + 作者 + 累计阅读时长，
/// 截图后保存到系统相册，不调用任何云端接口。
class BookShareCard extends StatelessWidget {
  const BookShareCard({super.key, required this.book});

  final Book book;

  static const Color _ink = Color(0xFF2A241B);
  static const Color _accent = Color(0xFF8A6A3C);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 282,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFCFAF4), Color(0xFFEFE8DA)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: CustomPaint(
        painter: const GridPainter(
          lineColor: Color(0x11000000),
          step: 26,
          strokeWidth: 0.55,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'NAKANO WENKU',
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 8.6,
                      letterSpacing: 2.6,
                      fontWeight: FontWeight.w600,
                      color: _ink,
                    ),
                  ),
                  Text(
                    book.isComic ? 'COMIC' : 'BOOK CARD',
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 8.6,
                      letterSpacing: 2.0,
                      color: AppColors.alpha(_ink, 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  BookCoverArt(book: book, width: 76, height: 104),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          book.title,
                          softWrap: true,
                          style: const TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize: 17,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.8,
                            color: AppColors.alpha(_ink, 0.66),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          book.id,
                          style: const TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize: 9,
                            letterSpacing: 1.4,
                            color: _accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const ThinDivider(
                  width: 46, thickness: 1.0, color: Color(0x668A6A3C)),
              const SizedBox(height: 12),
              _MetaLine(label: '累计阅读', value: book.totalReadLabel),
              const SizedBox(height: 7),
              _MetaLine(label: '章节数量', value: '${book.chapterCount} 章'),
              const SizedBox(height: 7),
              _MetaLine(
                  label: '阅读进度', value: '${(book.progress * 100).round()}%'),
              const SizedBox(height: 16),
              Text(
                book.isComic ? '一页一页，慢慢看完。' : '一页一页，把故事读完。',
                style: const TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 11,
                  letterSpacing: 0.8,
                  color: _accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 58,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              letterSpacing: 0.6,
              color: AppColors.alpha(BookShareCard._ink, 0.52),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: AppFonts.serif,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: BookShareCard._ink,
            ),
          ),
        ),
      ],
    );
  }
}

/// 弹出分享卡片并支持保存到相册。
Future<void> showBookShareDialog(
  BuildContext context, {
  required Book book,
}) async {
  final GlobalKey cardKey = GlobalKey();
  bool saving = false;

  await showDialog<void>(
    context: context,
    barrierColor: AppColors.alpha(Colors.black, 0.46),
    builder: (BuildContext dialogContext) {
      return StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          Future<void> save() async {
            if (saving) {
              return;
            }
            setState(() => saving = true);
            final String message = await _saveCard(cardKey, book);
            if (!dialogContext.mounted) {
              return;
            }
            setState(() => saving = false);
            showSoftMessage(dialogContext, message);
          }

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Material(
                color: Colors.transparent,
                child: FrostedGlass(
                  borderRadius: 26,
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      RepaintBoundary(
                        key: cardKey,
                        child: BookShareCard(book: book),
                      ),
                      const SizedBox(height: 16),
                      LiquidGlass(
                        borderRadius: 16,
                        onTap: saving ? null : save,
                        child: SizedBox(
                          height: 44,
                          child: Center(
                            child: Text(
                              saving ? '正在保存…' : '保存到相册',
                              style: TextStyle(
                                fontSize: 12.5,
                                letterSpacing: 1.0,
                                color: AppColors.textPrimary(
                                  Theme.of(context).brightness,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GhostButton(
                        label: '收下这张卡片',
                        onTap: () => Navigator.of(dialogContext).pop(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String> _saveCard(GlobalKey cardKey, Book book) async {
  final RenderObject? renderObject = cardKey.currentContext?.findRenderObject();
  if (renderObject is! RenderRepaintBoundary) {
    return '卡片还没有准备好，请稍后再试';
  }
  try {
    final ui.Image image = await renderObject.toImage(pixelRatio: 2.6);
    final ByteData? data =
        await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) {
      return '卡片生成失败，请稍后再试';
    }
    final Uint8List bytes = data.buffer.asUint8List();
    try {
      await Gal.putImageBytes(bytes, album: 'NakanoWenku');
      return '已保存到系统相册';
    } catch (_) {
      final Directory dir = await getApplicationDocumentsDirectory();
      final Directory target = Directory('${dir.path}/NakanoWenku');
      if (!await target.exists()) {
        await target.create(recursive: true);
      }
      final String path =
          '${target.path}/book_${book.number}_${DateTime.now().millisecondsSinceEpoch}.png';
      await File(path).writeAsBytes(bytes, flush: true);
      return '相册不可用，已保存到应用目录：$path';
    }
  } catch (_) {
    return '卡片生成失败，请稍后再试';
  }
}
