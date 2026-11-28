import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/donate_dialog.dart';
import '../../../core/widgets/grid_background.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/page_top_bar.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/thin_divider.dart';
import 'changelog_page.dart';

/// 关于与支持页。
///
/// 之前这些入口被塞在「设置」页最下面，几乎翻不到；现在单独成一页，
/// 从「我的」直接进入，打赏、QQ 群、安全声明、技术说明、关于作者、
/// 更新日志与版本信息都集中在这里。
class AboutSupportPage extends StatelessWidget {
  const AboutSupportPage({super.key});

  Future<void> _copyGroup(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: AppConstants.qqGroup));
    if (!context.mounted) {
      return;
    }
    showSoftMessage(context, 'Q 群号已复制');
  }

  Future<void> _openUrl(
    BuildContext context,
    String url,
    String fallback,
  ) async {
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

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = AppColors.accent(brightness);

    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      body: GridBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              const PageTopBar(title: '关于与支持', english: 'ABOUT & SUPPORT'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                  children: <Widget>[
                    _buildAuthorCard(brightness, accent),
                    const SizedBox(height: 26),
                    const SectionHeader(
                      title: '支持这个项目',
                      english: 'SUPPORT',
                      alignment: CrossAxisAlignment.start,
                    ),
                    const SizedBox(height: 12),
                    _buildSupportCard(context, brightness, accent),
                    const SizedBox(height: 26),
                    const SectionHeader(
                      title: '说明与记录',
                      english: 'DOCUMENTS',
                      alignment: CrossAxisAlignment.start,
                    ),
                    const SizedBox(height: 12),
                    _buildDocumentCard(context, brightness),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAuthorCard(Brightness brightness, Color accent) {
    return LiquidGlass(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: <Widget>[
          ClipOval(
            child: Image.asset(
              AppConstants.appIconAsset,
              width: 54,
              height: 54,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppConstants.appName,
                  style: AppTypography.chineseTitle(brightness, fontSize: 17),
                ),
                const SizedBox(height: 3),
                Text(
                  '独立开发 · 完全离线 · 仅 Android',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  AppConstants.signature,
                  style: TextStyle(
                    fontSize: 8.2,
                    letterSpacing: 2.0,
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupportCard(
    BuildContext context,
    Brightness brightness,
    Color accent,
  ) {
    return LiquidGlass(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '如果你对这个项目感兴趣，可以请我喝杯咖啡吗？',
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary(brightness),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '完全免费，也没有任何付费点。喜欢的话，点个 Star 就是最大的鼓励。',
            style: TextStyle(
              fontSize: 11,
              height: 1.7,
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: PressableScale(
                  pressedScale: 0.97,
                  onTap: () => showDonateDialog(context),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppColors.alpha(accent, 0.10),
                      border: Border.all(
                        color: AppColors.alpha(accent, 0.42),
                        width: 0.9,
                      ),
                    ),
                    child: Text(
                      '请我喝咖啡',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PressableScale(
                  pressedScale: 0.97,
                  onTap: () => _copyGroup(context),
                  child: Container(
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.alpha(
                          AppColors.divider(brightness),
                          1.2,
                        ),
                        width: 0.9,
                      ),
                    ),
                    child: Text(
                      'QQ 群 ${AppConstants.qqGroup}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              _buildLinkChip(
                brightness,
                icon: Icons.code_rounded,
                label: '项目仓库',
                onTap: () => _openUrl(
                  context,
                  AppConstants.repoUrl,
                  '打不开浏览器，请稍后再试',
                ),
              ),
              const SizedBox(width: 8),
              _buildLinkChip(
                brightness,
                icon: Icons.person_outline_rounded,
                label: '作者主页',
                onTap: () => _openUrl(
                  context,
                  AppConstants.authorUrl,
                  '打不开浏览器，请稍后再试',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkChip(
    Brightness brightness, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return PressableScale(
      pressedScale: 0.97,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: AppColors.alpha(AppColors.divider(brightness), 1.0),
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 13, color: AppColors.textTertiary(brightness)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentCard(BuildContext context, Brightness brightness) {
    return LiquidGlass(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: <Widget>[
          _DocRow(
            icon: Icons.shield_outlined,
            title: '安全声明与用户风险告知书',
            english: 'SAFETY NOTICE',
            brightness: brightness,
            onTap: () =>
                Navigator.of(context).pushNamed(AppRoutes.safetyNotice),
          ),
          _divider(brightness),
          _DocRow(
            icon: Icons.memory_rounded,
            title: '技术说明',
            english: 'TECH NOTES',
            brightness: brightness,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.techNotes),
          ),
          _divider(brightness),
          _DocRow(
            icon: Icons.face_retouching_natural_outlined,
            title: '关于作者',
            english: 'ABOUT THE AUTHOR',
            brightness: brightness,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.aboutAuthor),
          ),
          _divider(brightness),
          _DocRow(
            icon: Icons.history_rounded,
            title: '更新日志',
            english: 'CHANGELOG',
            brightness: brightness,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const ChangelogPage(),
              ),
            ),
          ),
          _divider(brightness),
          _DocRow(
            icon: Icons.system_update_alt_rounded,
            title: '版本与更新',
            english: 'VERSION',
            trailing: 'v${AppConstants.versionName}',
            brightness: brightness,
            onTap: () => Navigator.of(context).pushNamed(AppRoutes.version),
          ),
        ],
      ),
    );
  }

  Widget _divider(Brightness brightness) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ThinDivider(
        thickness: 0.6,
        color: AppColors.alpha(AppColors.divider(brightness), 0.7),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({
    required this.icon,
    required this.title,
    required this.english,
    required this.brightness,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String english;
  final Brightness brightness;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.985,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 17, color: AppColors.textSecondary(brightness)),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    english,
                    style: TextStyle(
                      fontSize: 8.2,
                      letterSpacing: 1.8,
                      color: AppColors.textTertiary(brightness),
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Text(
                  trailing!,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
              ),
            Icon(
              Icons.chevron_right_rounded,
              size: 17,
              color: AppColors.textTertiary(brightness),
            ),
          ],
        ),
      ),
    );
  }
}
