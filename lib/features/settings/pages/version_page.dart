import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/models/app_update.dart';
import '../../../core/services/apk_installer.dart';
import '../../../core/services/update_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/feedback.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/ghost_button.dart';
import '../../../core/widgets/grid_background.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/page_top_bar.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/thin_divider.dart';
import '../widgets/app_share_card.dart';
import '../widgets/update_dialog.dart';

/// 版本页。
///
/// 与需求一一对应：
/// - 展示 versionName 与 versionCode；
/// - 提供「检查更新」按钮（不受 7 天冷却限制）；
/// - 冷启动自动检测有冷却，这里的按钮始终可用；
/// - 测试版通过 Q 群分发，群号可一键复制。
class VersionPage extends StatefulWidget {
  const VersionPage({super.key, this.checkOnOpen = false});

  /// 进入页面后是否立即执行一次手动检测（「我的」页的检查更新入口使用）。
  final bool checkOnOpen;

  @override
  State<VersionPage> createState() => _VersionPageState();
}

class _VersionPageState extends State<VersionPage> {
  UpdateService? _updateService;
  bool _checking = false;
  UpdateCheckResult? _lastResult;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateService ??= context.read<UpdateService>();
    if (widget.checkOnOpen && !_checking && _lastResult == null) {
      // 等首帧渲染完成再发起请求，避免页面切换与弹窗竞争。
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdate());
    }
  }

  /// 打开配套更新网页（暂未启用，[AppConstants.updateWebUrl] 留空时不展示入口）。
  Future<void> _openUpdateWeb() async {
    final Uri? uri = Uri.tryParse(AppConstants.updateWebUrl);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _checkForUpdate() async {
    final UpdateService? service = _updateService;
    if (service == null || _checking) {
      return;
    }
    setState(() => _checking = true);

    final UpdateCheckResult result = await service.check();
    if (!mounted) {
      return;
    }
    setState(() {
      _checking = false;
      _lastResult = result;
    });

    final AppVersionInfo? info = result.info;
    if (result.hasUpdate && info != null) {
      final UpdateDialogAction action = await showUpdateDialog(context, info);
      if (action == UpdateDialogAction.later) {
        await service.dismiss(info);
        return;
      }
      await _download(info);
      return;
    }

    if (result.status == UpdateStatus.upToDate) {
      showSoftMessage(context, '已经是最新版本啦');
      return;
    }
    // 失败保持静默：卡片内已展示「暂时无法连接版本服务器」与最近一次检测时间，
    // 不再额外弹提示，避免离线时反复打扰。
  }

  Future<void> _download(AppVersionInfo info) async {
    final UpdateService? service = _updateService;
    if (service == null) {
      return;
    }

    // 下载期间用进度卡片占位，避免用户重复点击，也让 55MB 的等待有反馈。
    final ValueNotifier<double> progress = ValueNotifier<double>(0);
    final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
    bool dialogOpen = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) => _DownloadProgressDialog(
        progress: progress,
        versionName: info.versionName,
      ),
    ).then((_) => dialogOpen = false);

    final ApkInstallResult result = await service.downloadAndInstall(
      info,
      onProgress: (double value) => progress.value = value,
    );
    if (dialogOpen) {
      navigator.pop();
      dialogOpen = false;
    }
    progress.dispose();
    if (!mounted) {
      return;
    }

    switch (result) {
      case ApkInstallResult.launched:
        // 系统安装界面已经弹出，后续交给系统处理。
        return;
      case ApkInstallResult.needPermission:
        await _askInstallPermission();
        return;
      case ApkInstallResult.missingFile:
        showSoftMessage(context, '安装包已被系统清理，请重新下载');
        break;
      case ApkInstallResult.unsupported:
      case ApkInstallResult.failed:
        break;
    }

    // 应用内安装不可用时，最后回落到浏览器下载页（仍然可以完成升级）。
    final bool opened = await service.openDownload(info);
    if (!mounted) {
      return;
    }
    if (!opened) {
      showSoftMessage(context, '下载失败，请检查网络或稍后再试');
    }
  }

  /// 引导用户打开「安装未知应用」权限。
  Future<void> _askInstallPermission() async {
    final UpdateService? service = _updateService;
    if (service == null) {
      return;
    }
    final bool go = await showConfirmDialog(
      context: context,
      title: '需要安装权限',
      english: 'INSTALL PERMISSION',
      message: '应用内安装新版本需要允许「NakanoWenku 安装未知应用」，'
          '授权后返回本页面重新点击「安装」即可。',
      confirmLabel: '去授权',
    );
    if (!mounted || !go) {
      return;
    }
    await service.openInstallSettings();
  }

  Future<void> _copyGroup() async {
    await Clipboard.setData(const ClipboardData(text: AppConstants.qqGroup));
    if (!mounted) {
      return;
    }
    showSoftMessage(context, 'Q 群号已复制');
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
              const PageTopBar(title: '版本', english: 'VERSION'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                  children: <Widget>[
                    _buildIdentityCard(brightness),
                    const SizedBox(height: 30),
                    _buildUpdateCard(brightness),
                    const SizedBox(height: 30),
                    _buildTestChannelCard(brightness),
                    const SizedBox(height: 30),
                    _buildShareCard(brightness),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 应用信息 ----------------

  Widget _buildIdentityCard(Brightness brightness) {
    final Color accent = AppColors.accent(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '应用信息', english: 'APPLICATION'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
          child: Column(
            children: <Widget>[
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppColors.alpha(accent, 0.24),
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
                      Icons.menu_book_rounded,
                      size: 30,
                      color: AppColors.textTertiary(brightness),
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              Text(
                AppConstants.appName,
                style: AppTypography.chineseTitle(brightness, fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                AppConstants.signature,
                style: AppTypography.englishLabel(
                  brightness,
                  fontSize: 9,
                  letterSpacing: 2.6,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
              const SizedBox(height: 18),
              const ThinDivider(width: double.infinity, thickness: 0.7),
              const SizedBox(height: 14),
              _InfoRow(
                label: '版本名称',
                english: 'VERSION NAME',
                value: AppConstants.versionName,
                brightness: brightness,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: '版本代号',
                english: 'VERSION CODE',
                value: '${AppConstants.versionCode}',
                brightness: brightness,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- 更新检测 ----------------

  Widget _buildUpdateCard(Brightness brightness) {
    final UpdateCheckResult? result = _lastResult;
    final DateTime? lastCheck = _updateService?.lastCheckTime;

    String statusText = '冷启动会自动检测一次，两次之间间隔 7 天。';
    if (_checking) {
      statusText = '正在连接版本服务器……';
    } else if (result != null) {
      if (result.hasUpdate) {
        statusText = '发现新版本 v${result.info?.versionName ?? ''}';
      } else if (result.status == UpdateStatus.upToDate) {
        statusText = '当前已经是最新版本。';
      } else {
        statusText = '暂时无法连接版本服务器，稍后再试即可。';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '版本更新', english: 'UPDATE'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              if (lastCheck != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '上次检测：${_formatTime(lastCheck)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              GhostButton(
                label: _checking ? '检测中…' : '检查更新',
                english: 'CHECK FOR UPDATES',
                icon: Icons.system_update_alt_rounded,
                expand: true,
                enabled: !_checking,
                onTap: _checkForUpdate,
              ),
              const SizedBox(height: 12),
              Text(
                '更新通过系统下载管理器完成，下载结束后点击通知即可安装；'
                '本软件不会在后台静默安装任何内容。',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.7,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
              if (AppConstants.updateWebUrl.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                GhostButton(
                  label: '更新说明网页',
                  english: 'UPDATE NOTES',
                  icon: Icons.open_in_new_rounded,
                  expand: true,
                  onTap: _openUpdateWeb,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- 测试版渠道 ----------------

  Widget _buildShareCard(Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '分享软件', english: 'SHARE'),
        const SizedBox(height: 12),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '生成一张软件卡片，可以直接发给朋友。图片完全在本机绘制，'
                '不会上传任何内容。',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.7,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: 14),
              GhostButton(
                label: '生成分享卡片',
                onTap: () => showAppShareDialog(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTestChannelCard(Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '测试版渠道', english: 'BETA CHANNEL'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Q 群 ${AppConstants.qqGroup}',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '测试版与更新问题都可以在群里反馈',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textTertiary(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              PressableScale(
                pressedScale: 0.94,
                onTap: _copyGroup,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.alpha(
                        AppColors.accent(brightness),
                        0.4,
                      ),
                      width: 0.9,
                    ),
                  ),
                  child: Text(
                    '复制群号',
                    style: TextStyle(
                      fontSize: 11.5,
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

  String _formatTime(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}.${two(time.month)}.${two(time.day)} '
        '${two(time.hour)}:${two(time.minute)}';
  }
}

/// 「中文标签 + 英文标注 + 右侧值」的信息行。
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.english,
    required this.value,
    required this.brightness,
  });

  final String label;
  final String english;
  final String value;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary(brightness),
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
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: AppColors.textPrimary(brightness),
          ),
        ),
      ],
    );
  }
}

/// 应用内更新：下载进度卡片。
///
/// 只显示进度，不允许中途关闭（避免下到一半的 APK 被误用），
/// 下载完成后由调用方立即 pop 并拉起系统安装器。
class _DownloadProgressDialog extends StatelessWidget {
  const _DownloadProgressDialog({
    required this.progress,
    required this.versionName,
  });

  final ValueNotifier<double> progress;
  final String versionName;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = AppColors.accent(brightness);

    return Center(
      child: LiquidGlass(
        borderRadius: 24,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
        child: SizedBox(
          width: 232,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '正在下载 v$versionName',
                style: AppTypography.chineseTitle(brightness, fontSize: 17),
              ),
              const SizedBox(height: 4),
              Text(
                'DOWNLOADING',
                style: TextStyle(
                  fontSize: 8.4,
                  letterSpacing: 2.2,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
              const SizedBox(height: 18),
              ValueListenableBuilder<double>(
                valueListenable: progress,
                builder: (BuildContext context, double value, Widget? child) {
                  final int percent = (value * 100).clamp(0, 100).round();
                  return Column(
                    children: <Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: SizedBox(
                          height: 4,
                          child: Stack(
                            children: <Widget>[
                              Positioned.fill(
                                child: ColoredBox(
                                  color: AppColors.alpha(accent, 0.14),
                                ),
                              ),
                              FractionallySizedBox(
                                widthFactor: value.clamp(0.0, 1.0),
                                child: ColoredBox(
                                  color: AppColors.alpha(accent, 0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
