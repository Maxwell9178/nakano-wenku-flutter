import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/glass_dialog.dart';
import '../../../core/widgets/ghost_button.dart';
import '../../../core/widgets/grid_background.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/thin_divider.dart';

/// 软件本体分享卡片（第 3 轮清单第 6 项）。
///
/// 与「单本书籍分享卡片」完全独立：这里分享的是软件本身，
/// 内容是图标、名称、作者、GitHub 地址与一句话简介。
class AppShareCard extends StatelessWidget {
  const AppShareCard({super.key, this.version = AppConstants.versionName});

  final String version;

  static const Color _accent = Color(0xFF8A8A84);
  static const Color _ink = Color(0xFF2A2A28);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[Color(0xF2FFFFFF), Color(0xF2EDEDEA)],
              ),
              border: Border.all(color: const Color(0x66FFFFFF), width: 1),
            ),
            child: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: GridPainter(
                      lineColor: const Color(0x11000000),
                      step: 26,
                      strokeWidth: 0.55,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Text(
                            'NAKANO WENKU',
                            style: TextStyle(
                              fontFamily: AppFonts.serif,
                              fontSize: 8.6,
                              letterSpacing: 2.4,
                              color: _ink.withValues(alpha: 0.55),
                            ),
                          ),
                          Text(
                            'v$version',
                            style: TextStyle(
                              fontSize: 8.6,
                              letterSpacing: 1.2,
                              color: _ink.withValues(alpha: 0.45),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              AppConstants.appIconAsset,
                              width: 62,
                              height: 62,
                              fit: BoxFit.cover,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  'NakanoWenku',
                                  style: AppTypography.chineseTitle(
                                    Brightness.light,
                                    fontSize: 20,
                                  ).copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '本地书架 · 离线阅读器',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    height: 1.5,
                                    letterSpacing: 0.4,
                                    color: _ink.withValues(alpha: 0.66),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 46,
                        height: 1,
                        color: const Color(0x668A8A84),
                      ),
                      const SizedBox(height: 14),
                      _IntroLine(text: '完全离线运行，书籍与进度都只存在本机。'),
                      _IntroLine(
                          text: '支持 EPUB / TXT / DOCX / Markdown / ZIP 与漫画包。'),
                      _IntroLine(text: '3D 书架、液态玻璃界面、可自定义的阅读排版。'),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: const Color(0x0D000000),
                          border: Border.all(
                            color: const Color(0x14000000),
                            width: 0.8,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Text(
                                  '作者',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1.0,
                                    color: _ink.withValues(alpha: 0.45),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Maxwell',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _ink.withValues(alpha: 0.82),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: <Widget>[
                                Text(
                                  'GitHub',
                                  style: TextStyle(
                                    fontSize: 9,
                                    letterSpacing: 1.0,
                                    color: _ink.withValues(alpha: 0.45),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    AppConstants.repoUrl
                                        .replaceFirst('https://', ''),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _ink.withValues(alpha: 0.72),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        AppConstants.signature,
                        style: TextStyle(
                          fontSize: 8.2,
                          letterSpacing: 2.2,
                          color: _accent.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IntroLine extends StatelessWidget {
  const _IntroLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 3,
              height: 3,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0x998A8A84),
              ),
            ),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10.5,
                height: 1.62,
                color: Color(0xCC2A2A28),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 弹出软件分享卡片，并支持保存到系统相册（完全本地生成）。
Future<void> showAppShareDialog(BuildContext context) async {
  final GlobalKey cardKey = GlobalKey();
  await showGlassDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      final Brightness brightness = Theme.of(dialogContext).brightness;
      return GlassDialogCard(
        title: '分享这个软件',
        english: 'SHARE APP',
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: RepaintBoundary(
                key: cardKey,
                child: const AppShareCard(),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '卡片在本机生成，不会上传任何图片。',
              style: TextStyle(
                fontSize: 10.5,
                height: 1.6,
                color: AppColors.textTertiary(brightness),
              ),
            ),
            if (AppConstants.qqGroup.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              ThinDivider(thickness: 0.7),
              const SizedBox(height: 6),
              Text(
                '交流群 ${AppConstants.qqGroup}',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ],
          ],
        ),
        actions: <Widget>[
          GhostButton(
            label: '保存到相册',
            onTap: () => _saveCard(dialogContext, cardKey),
            expand: false,
          ),
          LiquidGlass(
            borderRadius: 16,
            onTap: () => Navigator.of(dialogContext).pop(),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text('收下卡片', style: TextStyle(fontSize: 11.5)),
            ),
          ),
        ],
      );
    },
  );
}

Future<void> _saveCard(BuildContext context, GlobalKey key) async {
  final RenderObject? object = key.currentContext?.findRenderObject();
  if (object is! RenderRepaintBoundary) {
    return;
  }
  try {
    final ui.Image image = await object.toImage(pixelRatio: 2.6);
    final ByteData? data = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();
    if (data == null) {
      return;
    }
    final Uint8List bytes = data.buffer.asUint8List();
    try {
      await Gal.putImageBytes(bytes, album: 'NakanoWenku');
      return;
    } catch (_) {
      // 相册不可用时退化到应用目录，至少不丢图。
      final Directory dir = await getApplicationDocumentsDirectory();
      final String path =
          '${dir.path}/NakanoWenku/app_share_${DateTime.now().millisecondsSinceEpoch}.png';
      final File file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
    }
  } catch (_) {
    // 出图失败保持静默，不打断用户。
  }
}
