import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../utils/feedback.dart';
import 'glass_dialog.dart';
import 'pressable_scale.dart';

/// 打赏弹窗（全局共用一个实现）。
///
/// 「我的」页面的「关于与支持」与「关于作者」页都用它，
/// 保证两处看到的是同一张收款码与同一套保存逻辑。
Future<void> showDonateDialog(BuildContext context) async {
  await showGlassDialog<void>(
    context: context,
    builder: (BuildContext context) => const GlassDialogCard(
      title: '请喝一杯咖啡',
      english: 'BUY ME A MILK TEA',
      message: '如果你对这个项目感兴趣，可以请我喝杯咖啡。',
      content: DonateDialogBody(),
    ),
  );
}

/// 打赏二维码正文：展示微信收款码，并支持保存到系统相册。
class DonateDialogBody extends StatefulWidget {
  const DonateDialogBody({super.key});

  @override
  State<DonateDialogBody> createState() => _DonateDialogBodyState();
}

class _DonateDialogBodyState extends State<DonateDialogBody> {
  bool _saving = false;

  Future<void> _saveToGallery() async {
    if (_saving) {
      return;
    }
    setState(() => _saving = true);
    try {
      final ByteData data = await rootBundle.load(AppConstants.donateQrAsset);
      final Uint8List bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      try {
        await Gal.putImageBytes(
          bytes,
          album: 'NakanoWenku',
          name: 'nakano_wenku_donate',
        );
        if (mounted) {
          showSoftMessage(context, '已保存到系统相册');
        }
      } catch (_) {
        // 相册写入失败（无权限 / 设备不支持）时退化为应用目录。
        final Directory documents = await getApplicationDocumentsDirectory();
        final Directory folder = Directory(
          '${documents.path}${Platform.pathSeparator}NakanoWenku',
        );
        if (!await folder.exists()) {
          await folder.create(recursive: true);
        }
        final String path =
            '${folder.path}${Platform.pathSeparator}nakano_wenku_donate.jpg';
        await File(path).writeAsBytes(bytes, flush: true);
        if (mounted) {
          showSoftMessage(context, '相册不可用，已保存到应用目录：$path');
        }
      }
    } on Object {
      if (mounted) {
        showSoftMessage(context, '二维码保存失败，请稍后再试');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = AppColors.accent(brightness);

    return Column(
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.asset(
            AppConstants.donateQrAsset,
            width: 216,
            fit: BoxFit.contain,
            errorBuilder: (
              BuildContext context,
              Object error,
              StackTrace? stackTrace,
            ) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  '二维码资源缺失',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          '微信扫码打赏，完全自愿，不影响任何功能使用。',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.7,
            color: AppColors.textSecondary(brightness),
          ),
        ),
        const SizedBox(height: 14),
        PressableScale(
          pressedScale: 0.97,
          onTap: _saving ? null : _saveToGallery,
          child: Container(
            width: double.infinity,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.alpha(accent, 0.4),
                width: 0.9,
              ),
              color: AppColors.alpha(accent, 0.05),
            ),
            child: Text(
              _saving ? '保存中…' : '保存图片',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
