import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/services/user_profile_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/ghost_button.dart';
import '../../core/widgets/grid_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/thin_divider.dart';
import '../backup/wkarchive_flow.dart';
import 'widgets/avatar_picker.dart';

/// 首次启动初始化页。
///
/// 只在「未完成过初始化」时出现（由本地布尔标记控制），提供两条路径：
/// 1. 新建本地账号：昵称 + 可选头像，完全离线，不需要手机号 / 邮箱；
/// 2. 导入 .wkarchive 备份：恢复已有账号资料，导入完成直接进入书架。
///
/// 备份导入与「我的 - 数据包导入」共用同一套流程，书籍、章节、摘抄、
/// 阅读进度与打卡一并恢复；包内缺少 avatar.png 时自动使用默认空白头像。
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const int _maxNameLength = 16;

  final TextEditingController _nameController = TextEditingController();

  String? _avatarPath;
  bool _busy = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  // ---------------- 校验 ----------------

  String get _trimmedName => _nameController.text.trim();

  String? get _nameError {
    final String name = _trimmedName;
    if (name.isEmpty) {
      return null;
    }
    if (name.length > _maxNameLength) {
      return '昵称请控制在 $_maxNameLength 个字符以内';
    }
    return null;
  }

  // ---------------- 动作 ----------------

  Future<void> _pickAvatar() async {
    if (_busy) {
      return;
    }
    final String? path = await pickAvatarImagePath();
    if (!mounted || path == null) {
      return;
    }
    setState(() => _avatarPath = path);
  }

  /// 路径一：创建本地账号。
  Future<void> _createAccount() async {
    if (_busy) {
      return;
    }

    final String name = _trimmedName;
    if (name.isEmpty) {
      showSoftMessage(context, '先给自己取一个昵称吧');
      return;
    }
    final String? error = _nameError;
    if (error != null) {
      showSoftMessage(context, error);
      return;
    }

    setState(() => _busy = true);
    try {
      await context.read<UserProfileController>().createLocalAccount(
            userName: name,
            avatarSourcePath: _avatarPath,
          );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } on ProfileException catch (exception) {
      if (mounted) {
        showSoftMessage(context, exception.message);
      }
    } catch (_) {
      if (mounted) {
        showSoftMessage(context, '创建失败，请稍后重试');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  /// 路径二：导入 .wkarchive 备份。
  ///
  /// 「我的」页面与这里共用 [WkArchiveFlow]，解析与覆盖 / 合并逻辑只有一份。
  Future<void> _importBackup() async {
    if (_busy) {
      return;
    }

    setState(() => _busy = true);
    try {
      final bool applied = await WkArchiveFlow.import(context);
      if (!mounted || !applied) {
        return;
      }
      Navigator.of(context).pushReplacementNamed(AppRoutes.home);
    } catch (_) {
      if (mounted) {
        showSoftMessage(context, '导入失败，请确认备份包是否完整');
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  // ---------------- 界面 ----------------

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color accent = AppColors.accent(brightness);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: brightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: GridBackground(
          child: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 28,
                    right: 28,
                    top: 36,
                    bottom: 28 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 64)
                          .clamp(0.0, double.infinity)
                          .toDouble(),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 430),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: <Widget>[
                            _buildHeader(brightness),
                            const SizedBox(height: 30),
                            AvatarPicker(
                              imagePath: _avatarPath,
                              enabled: !_busy,
                              onTap: _pickAvatar,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _avatarPath == null ? '轻触选择头像（可跳过）' : '轻触可更换头像',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textTertiary(brightness),
                                  ),
                            ),
                            const SizedBox(height: 26),
                            _buildNameField(brightness),
                            const SizedBox(height: 22),
                            _buildPrimaryAction(accent),
                            const SizedBox(height: 26),
                            _buildOrDivider(brightness),
                            const SizedBox(height: 18),
                            GhostButton(
                              label: '导入 .wkarchive 配置包',
                              english: 'Restore from backup',
                              icon: Icons.unarchive_outlined,
                              expand: true,
                              enabled: !_busy,
                              onTap: _importBackup,
                            ),
                            const SizedBox(height: 26),
                            Text(
                              '全程离线 · 无需手机号 / 邮箱 / 第三方账号',
                              textAlign: TextAlign.center,
                              style: AppTypography.englishLabel(
                                brightness,
                                fontSize: 9.5,
                                letterSpacing: 1.6,
                                color: AppColors.textTertiary(brightness),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Brightness brightness) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '初次见面',
          style: AppTypography.chineseTitle(brightness, fontSize: 30)
              .copyWith(letterSpacing: 5),
        ),
        const SizedBox(height: 10),
        Text(
          'WELCOME TO NAKANOWENKU',
          textAlign: TextAlign.center,
          style: AppTypography.englishLabel(
            brightness,
            fontSize: 9.5,
            letterSpacing: 3.0,
            color: AppColors.textTertiary(brightness),
          ),
        ),
        const SizedBox(height: 14),
        const ThinDivider(width: 46, thickness: 0.9),
        const SizedBox(height: 14),
        Text(
          '这里只属于你，数据全部保存在本机',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _buildNameField(Brightness brightness) {
    final String? error = _nameError;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        TextField(
          controller: _nameController,
          enabled: !_busy,
          textInputAction: TextInputAction.done,
          maxLength: _maxNameLength,
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _createAccount(),
          style: Theme.of(context).textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: '输入你的昵称',
            prefixIcon: Icon(
              Icons.edit_outlined,
              size: 18,
              color: AppColors.textTertiary(brightness),
            ),
            counterStyle: TextStyle(
              fontSize: 10.5,
              color: AppColors.textTertiary(brightness),
            ),
            errorText: error,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryAction(Color accent) {
    return LiquidGlass(
      borderRadius: 17,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
      onTap: _busy ? null : _createAccount,
      tint: accent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _busy
                ? SizedBox(
                    key: const ValueKey<String>('busy'),
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    ),
                  )
                : Icon(
                    Icons.auto_stories_outlined,
                    key: const ValueKey<String>('idle'),
                    size: 18,
                    color: accent,
                  ),
          ),
          const SizedBox(width: 10),
          Text(
            _busy ? '正在准备…' : '完成创建，进入软件',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrDivider(Brightness brightness) {
    final Color line = AppColors.divider(brightness);

    return Row(
      children: <Widget>[
        Expanded(child: ThinDivider(color: line, thickness: 0.7)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '或',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 2,
              color: AppColors.textTertiary(brightness),
            ),
          ),
        ),
        Expanded(child: ThinDivider(color: line, thickness: 0.7)),
      ],
    );
  }
}
