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

/// 读完分享卡片。
///
/// 卡片本身是一张可离屏导出的竖版图片：包含账号名称、封面、书名、
/// 总字数与读完时间，底部固定文案「已读完的书又加一啦！」。
class FinishedShareCard extends StatelessWidget {
  const FinishedShareCard({
    super.key,
    required this.book,
    required this.userName,
    required this.finishedAt,
  });

  final Book book;
  final String userName;
  final DateTime finishedAt;

  @override
  Widget build(BuildContext context) {
    const Color ink = Color(0xFF2A241B);
    const Color accent = Color(0xFF8A6A3C);

    return Container(
      width: 282,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFFFCFAF4), Color(0xFFEFE8DA)],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.alpha(Colors.black, 0.18),
            blurRadius: 26,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: CustomPaint(
        painter: const GridPainter(
          lineColor: Color(0x11000000),
          step: 26,
          strokeWidth: 0.55,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    'NAKANO WENKU',
                    style: AppTypography.englishLabel(
                      Brightness.light,
                      fontSize: 8.4,
                      letterSpacing: 2.4,
                      color: AppColors.alpha(ink, 0.55),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'FINISHED',
                    style: AppTypography.englishLabel(
                      Brightness.light,
                      fontSize: 8.4,
                      letterSpacing: 2.4,
                      color: AppColors.alpha(accent, 0.85),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              BookCoverArt(book: book, width: 94, height: 130),
              const SizedBox(height: 16),
              Text(
                book.title,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.chineseTitle(
                  Brightness.light,
                  fontSize: 19,
                ).copyWith(color: ink, height: 1.4),
              ),
              const SizedBox(height: 5),
              Text(
                book.author,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.alpha(ink, 0.50),
                ),
              ),
              const SizedBox(height: 12),
              const ThinDivider(
                width: 46,
                thickness: 0.8,
                color: Color(0x668A6A3C),
              ),
              const SizedBox(height: 12),
              _MetaLine(label: '总字数', value: book.wordCountLabel),
              const SizedBox(height: 7),
              _MetaLine(label: '读完时间', value: _formatDate(finishedAt)),
              const SizedBox(height: 7),
              _MetaLine(label: '读者', value: userName),
              const SizedBox(height: 16),
              Text(
                '已读完的书又加一啦！',
                style: TextStyle(
                  fontSize: 12.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w600,
                  color: AppColors.alpha(accent, 0.95),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ANOTHER BOOK FINISHED',
                style: AppTypography.englishLabel(
                  Brightness.light,
                  fontSize: 7.2,
                  letterSpacing: 2.2,
                  color: AppColors.alpha(ink, 0.34),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}.${two(time.month)}.${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
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
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 1.0,
              color: Color(0x992A241B),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 10.5,
              color: Color(0xDD2A241B),
            ),
          ),
        ),
      ],
    );
  }
}

/// 弹出读完分享卡片（含保存到系统相册）。
Future<void> showFinishedShareDialog(
  BuildContext context, {
  required Book book,
  required String userName,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'finished',
    barrierColor: AppColors.alpha(Colors.black, 0.46),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation) {
      return _FinishedShareDialog(book: book, userName: userName);
    },
    transitionBuilder: (BuildContext context, Animation<double> animation,
        Animation<double> secondaryAnimation, Widget child) {
      final CurvedAnimation curved =
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _FinishedShareDialog extends StatefulWidget {
  const _FinishedShareDialog({required this.book, required this.userName});

  final Book book;
  final String userName;

  @override
  State<_FinishedShareDialog> createState() => _FinishedShareDialogState();
}

class _FinishedShareDialogState extends State<_FinishedShareDialog> {
  final GlobalKey _cardKey = GlobalKey();
  late final DateTime _finishedAt = DateTime.now();
  bool _saving = false;

  Future<void> _saveToGallery() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final RenderObject? renderObject =
          _cardKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) {
        showSoftMessage(context, '卡片还没有准备好，请稍后再试');
        return;
      }

      final ui.Image image = await renderObject.toImage(pixelRatio: 2.6);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) {
        if (mounted) {
          showSoftMessage(context, '卡片导出失败，请稍后再试');
        }
        return;
      }
      final Uint8List bytes = byteData.buffer.asUint8List();

      try {
        await Gal.putImageBytes(bytes, album: 'NakanoWenku');
        if (mounted) {
          showSoftMessage(context, '已保存到系统相册');
        }
      } catch (_) {
        // 相册写入失败（无权限 / 设备不支持）时退化为存到应用文档目录，
        // 不弹错误框，也不让用户白操作一场。
        final Directory documents = await getApplicationDocumentsDirectory();
        final Directory folder =
            Directory('${documents.path}${Platform.pathSeparator}NakanoWenku');
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }
        final String path =
            '${folder.path}${Platform.pathSeparator}finished_'
            '${DateTime.now().millisecondsSinceEpoch}.png';
        await File(path).writeAsBytes(bytes, flush: true);
        if (mounted) {
          showSoftMessage(context, '相册不可用，已保存到应用目录：$path');
        }
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Material(
          color: Colors.transparent,
          child: FrostedGlass(
            borderRadius: 26,
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                RepaintBoundary(
                  key: _cardKey,
                  child: FinishedShareCard(
                    book: widget.book,
                    userName: widget.userName,
                    finishedAt: _finishedAt,
                  ),
                ),
                const SizedBox(height: 16),
                LiquidGlass(
                  borderRadius: 16,
                  opacity: _saving ? 0.06 : 0.16,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onTap: _saving ? null : _saveToGallery,
                  child: Center(
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 1.6),
                          )
                        : Text(
                            '保存到相册',
                            style: TextStyle(
                              fontSize: 13,
                              letterSpacing: 1.6,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accent(
                                Theme.of(context).brightness,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 10),
                GhostButton(
                  label: '收下这张卡片',
                  expand: true,
                  onTap: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
