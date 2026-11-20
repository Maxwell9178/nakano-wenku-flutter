import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/glass_dialog.dart';
import '../../../core/widgets/grid_background.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/page_top_bar.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/thin_divider.dart';

/// 关于作者页。
///
/// 内容全部离线：作者与仓库链接跳转浏览器，作者的话与打赏二维码
/// 读取随包资源；打赏二维码支持保存到系统相册。
class AboutAuthorPage extends StatelessWidget {
  const AboutAuthorPage({super.key});

  Future<void> _openUrl(
      BuildContext context, String url, String fallback) async {
    bool opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      opened = false;
    }
    if (!context.mounted) {
      return;
    }
    if (!opened) {
      showSoftMessage(context, fallback);
    }
  }

  Future<void> _copyGroup(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: AppConstants.qqGroup));
    if (!context.mounted) {
      return;
    }
    showSoftMessage(context, 'Q 群号已复制');
  }

  Future<void> _showAuthorWords(BuildContext context) async {
    String text;
    try {
      text =
          (await rootBundle.loadString(AppConstants.authorWordsAsset)).trim();
    } on Object {
      text = '作者的话读取失败，请重新安装应用后再试。';
    }
    if (!context.mounted) {
      return;
    }
    await showGlassDialog<void>(
      context: context,
      builder: (BuildContext context) => GlassDialogCard(
        title: '有话对你说',
        english: 'FROM THE AUTHOR',
        content: _ScrollableText(text: text),
        actions: <Widget>[
          GlassDialogButton(
            label: '知道了',
            primary: true,
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Future<void> _showDonate(BuildContext context) async {
    await showGlassDialog<void>(
      context: context,
      builder: (BuildContext context) => GlassDialogCard(
        title: '请喝奶茶',
        english: 'BUY ME A MILK TEA',
        content: const _DonateDialogBody(),
        actions: <Widget>[
          GlassDialogButton(
            label: '关闭',
            onTap: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      body: GridBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              const PageTopBar(title: '关于作者', english: 'ABOUT'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 44),
                  children: <Widget>[
                    _buildAuthorCard(context, brightness),
                    const SizedBox(height: 26),
                    _buildLinksCard(context, brightness),
                    const SizedBox(height: 26),
                    _buildGroupCard(context, brightness),
                    const SizedBox(height: 26),
                    _buildDonateCard(context, brightness),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 作者名片 ----------------

  Widget _buildAuthorCard(BuildContext context, Brightness brightness) {
    final Color accent = AppColors.accent(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '作者', english: 'AUTHOR'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            children: <Widget>[
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.alpha(accent, 0.28),
                    width: 0.9,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  AppConstants.appIconAsset,
                  fit: BoxFit.cover,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return Icon(
                      Icons.person_outline_rounded,
                      size: 30,
                      color: AppColors.textTertiary(brightness),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppConstants.author,
                style: AppTypography.chineseTitle(brightness, fontSize: 19),
              ),
              const SizedBox(height: 5),
              Text(
                'NakanoWenku 的作者 · 独立开发者',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
              const SizedBox(height: 16),
              const ThinDivider(width: double.infinity, thickness: 0.7),
              const SizedBox(height: 14),
              Text(
                '这个项目完全开源、免费、离线优先：不登录、不联网收集数据、'
                '不插入广告，所有阅读数据只保存在你自己的设备上。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: 14),
              PressableScale(
                pressedScale: 0.97,
                onTap: () => _showAuthorWords(context),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: AppColors.alpha(accent, 0.05),
                    border: Border.all(
                      color: AppColors.alpha(accent, 0.4),
                      width: 0.9,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.mail_outline_rounded,
                        size: 17,
                        color: AppColors.textPrimary(brightness),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          '有话对你说',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            color: AppColors.textPrimary(brightness),
                          ),
                        ),
                      ),
                      Text(
                        'FROM THE AUTHOR',
                        style: AppTypography.englishLabel(
                          brightness,
                          fontSize: 8,
                          letterSpacing: 1.6,
                          color: AppColors.textTertiary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- 链接 ----------------

  Widget _buildLinksCard(BuildContext context, Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '项目', english: 'PROJECT'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: <Widget>[
              _LinkRow(
                icon: Icons.person_outline_rounded,
                title: '作者主页',
                english: 'GITHUB PROFILE',
                value: AppConstants.author,
                brightness: brightness,
                onTap: () => _openUrl(
                  context,
                  AppConstants.authorUrl,
                  '无法打开浏览器，请手动访问 ${AppConstants.authorUrl}',
                ),
              ),
              const ThinDivider(width: double.infinity, thickness: 0.7),
              _LinkRow(
                icon: Icons.folder_open_rounded,
                title: '项目仓库',
                english: 'SOURCE CODE',
                value: 'nakano-wenku-flutter',
                brightness: brightness,
                onTap: () => _openUrl(
                  context,
                  AppConstants.repoUrl,
                  '无法打开浏览器，请手动访问 ${AppConstants.repoUrl}',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- Q 群 ----------------

  Widget _buildGroupCard(BuildContext context, Brightness brightness) {
    final Color accent = AppColors.accent(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '交流群', english: 'COMMUNITY'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    Icons.forum_outlined,
                    size: 18,
                    color: AppColors.textSecondary(brightness),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'QQ 群',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: AppColors.textPrimary(brightness),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'COMMUNITY GROUP',
                          style: AppTypography.englishLabel(
                            brightness,
                            fontSize: 8,
                            letterSpacing: 1.8,
                            color: AppColors.textTertiary(brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    AppConstants.qqGroup,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.6,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '测试版、更新问题与使用反馈都在这里',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              PressableScale(
                pressedScale: 0.97,
                onTap: () => _copyGroup(context),
                child: Container(
                  width: double.infinity,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: AppColors.alpha(accent, 0.4),
                      width: 0.9,
                    ),
                    color: AppColors.alpha(accent, 0.04),
                  ),
                  child: Text(
                    '复制群号',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent(brightness),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- 打赏 ----------------

  Widget _buildDonateCard(BuildContext context, Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '请喝奶茶', english: 'SUPPORT'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '如果你觉得这个阅读器帮到了你，可以请我喝一杯奶茶。'
                '打赏完全自愿，不影响任何功能，也不会解锁额外内容。',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: 14),
              PressableScale(
                pressedScale: 0.97,
                onTap: () => _showDonate(context),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.alpha(
                        AppColors.accent(brightness),
                        0.45,
                      ),
                      width: 0.9,
                    ),
                    color: AppColors.alpha(
                      AppColors.accent(brightness),
                      0.07,
                    ),
                  ),
                  child: Text(
                    '微信打赏',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.0,
                      color: AppColors.accent(brightness),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 打赏二维码弹窗正文：展示微信收款码，并支持保存到系统相册。
class _DonateDialogBody extends StatefulWidget {
  const _DonateDialogBody();

  @override
  State<_DonateDialogBody> createState() => _DonateDialogBodyState();
}

class _DonateDialogBodyState extends State<_DonateDialogBody> {
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
        // 相册写入失败（无权限 / 设备不支持）时退化为应用目录，
        // 保证「保存」这个动作始终有结果。
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
          borderRadius: BorderRadius.circular(14),
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
              borderRadius: BorderRadius.circular(13),
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

/// 可滚动文本正文（作者的话等长文本）。
class _ScrollableText extends StatelessWidget {
  const _ScrollableText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: SingleChildScrollView(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            height: 1.85,
            color: AppColors.textSecondary(brightness),
          ),
        ),
      ),
    );
  }
}

/// 图标 + 中英文标签 + 右侧值的链接行。
class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.english,
    required this.value,
    required this.brightness,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String english;
  final String value;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.99,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.textSecondary(brightness)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    english,
                    style: AppTypography.englishLabel(
                      brightness,
                      fontSize: 8,
                      letterSpacing: 1.8,
                      color: AppColors.textTertiary(brightness),
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.accent(brightness),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary(brightness),
            ),
          ],
        ),
      ),
    );
  }
}
