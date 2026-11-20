import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/pressable_scale.dart';

/// 唤起系统图片选择器，返回本地图片路径。
///
/// 全程离线：只读取本地文件，不做任何上传。
/// 某些平台只返回字节而没有路径，这里落一份临时文件再返回路径，
/// 保证上层可以统一按「路径」处理头像。
Future<String?> pickAvatarImagePath() async {
  FilePickerResult? picked;
  try {
    picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['jpg', 'jpeg', 'png', 'webp'],
      allowMultiple: false,
      withData: true,
    );
  } catch (_) {
    return null;
  }

  if (picked == null || picked.files.isEmpty) {
    return null;
  }

  final PlatformFile file = picked.files.first;
  final String? path = file.path;
  if (path != null && path.isNotEmpty) {
    return path;
  }

  final Uint8List? bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    return null;
  }

  try {
    final Directory dir = await getTemporaryDirectory();
    final String ext = p.extension(file.name).isEmpty
        ? '.png'
        : p.extension(file.name).toLowerCase();
    final File temp = File(
      p.join(dir.path, 'picked_avatar_${DateTime.now().millisecondsSinceEpoch}$ext'),
    );
    await temp.writeAsBytes(bytes, flush: true);
    return temp.path;
  } catch (_) {
    return null;
  }
}

/// 圆形头像选择器。
///
/// 未选择图片时展示内置的默认空白头像（不引用任何网络图片或额外资源）。
class AvatarPicker extends StatelessWidget {
  const AvatarPicker({
    super.key,
    this.imagePath,
    this.onTap,
    this.size = 104,
    this.enabled = true,
  });

  final String? imagePath;
  final VoidCallback? onTap;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = AppColors.accent(brightness);

    final Widget avatar = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: _buildImage(brightness),
      ),
    );

    return PressableScale(
      enabled: enabled,
      onTap: onTap,
      pressedScale: 0.96,
      child: SizedBox(
        width: size + 8,
        height: size + 8,
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            // 细线外环
            Container(
              width: size + 6,
              height: size + 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.alpha(accent, 0.35),
                  width: 0.9,
                ),
              ),
            ),
            avatar,
            // 右下角的相机角标
            Positioned(
              right: 0,
              bottom: 2,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.alpha(
                    Theme.of(context).scaffoldBackgroundColor,
                    0.92,
                  ),
                  border: Border.all(
                    color: AppColors.alpha(accent, 0.45),
                    width: 0.9,
                  ),
                ),
                child: Icon(
                  Icons.photo_camera_outlined,
                  size: 15,
                  color: accent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(Brightness brightness) {
    final String? path = imagePath;
    if (path == null || path.isEmpty) {
      return _defaultAvatar(brightness);
    }

    return Image.file(
      File(path),
      // key 跟随路径变化，避免图片缓存导致换头像后仍显示旧图。
      key: ValueKey<String>(path),
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return _defaultAvatar(brightness);
      },
    );
  }

  Widget _defaultAvatar(Brightness brightness) {
    return Container(
      color: AppColors.alpha(
        AppColors.accent(brightness),
        0.06,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline_rounded,
        size: size * 0.42,
        color: AppColors.textTertiary(brightness),
      ),
    );
  }
}
