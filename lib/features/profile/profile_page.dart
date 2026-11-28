import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/routing/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../core/services/account_data_service.dart';
import '../../core/services/book_repository.dart';
import '../../core/services/reading_stats_repository.dart';
import '../../core/services/tag_weight_repository.dart';
import '../../core/services/user_profile_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/donate_dialog.dart';
import '../../core/widgets/grid_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/text_input_dialog.dart';
import '../../core/widgets/thin_divider.dart';
import '../backup/wkarchive_flow.dart';
import '../onboarding/widgets/avatar_picker.dart';
import '../settings/pages/version_page.dart';
import 'pages/about_support_page.dart';
import 'pages/book_list_page.dart';
import 'pages/changelog_page.dart';
import 'pages/check_in_page.dart';
import 'profile_controller.dart';
import 'widgets/tag_radar_chart.dart';

/// 「我的」页面。
///
/// 负责账号信息、入驻天数、阅读时长、打卡日历、书籍统计、偏好雷达图，
/// 以及数据包导出 / 导入与账号数据删除（两次确认）。
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key, this.active = true});

  /// 当前是否处于选中标签页：从别的标签切回来时刷新一次统计。
  final bool active;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  ProfileController? _controller;
  Listenable? _listenable;
  bool _deleting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) {
      return;
    }
    final ProfileController controller = ProfileController(
      books: context.read<BookRepository>(),
      stats: context.read<ReadingStatsRepository>(),
      profile: context.read<UserProfileController>(),
      tagWeights: context.read<TagWeightRepository>(),
    )..load();

    _controller = controller;
    _listenable = Listenable.merge(<Listenable>[
      controller,
      context.read<UserProfileController>(),
    ]);
  }

  @override
  void didUpdateWidget(covariant ProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller?.load();
    }
  }

  // ---------------- 账号操作 ----------------

  Future<void> _pickAvatar() async {
    final ProfileController? controller = _controller;
    if (controller == null) {
      return;
    }
    final String? path = await pickAvatarImagePath();
    if (path == null || path.isEmpty) {
      return;
    }
    try {
      await controller.profile.updateAvatar(path);
      if (!mounted) {
        return;
      }
      controller.load();
      showSoftMessage(context, '头像已更新');
    } on ProfileException catch (error) {
      if (mounted) {
        showSoftMessage(context, error.message);
      }
    }
  }

  Future<void> _editUserName() async {
    final ProfileController? controller = _controller;
    if (controller == null) {
      return;
    }
    final String? name = await showTextInputDialog(
      context: context,
      title: '修改昵称',
      english: 'NICKNAME',
      initialValue: controller.profile.userName,
      hintText: '起一个喜欢的名字',
      maxLength: 16,
      validator: (String value) => value.trim().isEmpty ? '昵称不能为空' : null,
    );
    if (name == null) {
      return;
    }
    try {
      await controller.profile.updateUserName(name);
      if (!mounted) {
        return;
      }
      controller.load();
    } on ProfileException catch (error) {
      if (mounted) {
        showSoftMessage(context, error.message);
      }
    }
  }

  Future<void> _deleteAccount() async {
    if (_deleting) {
      return;
    }

    final bool first = await showConfirmDialog(
      context: context,
      title: '删除账号',
      english: 'DELETE ACCOUNT',
      message: '请确认这是你本人的操作。\n确认后将继续下一步。',
      confirmLabel: '是我本人',
      danger: true,
    );
    if (!first || !mounted) {
      return;
    }

    final bool second = await showConfirmDialog(
      context: context,
      title: '数据不可恢复',
      english: 'IRREVERSIBLE',
      message: '账号资料、全部书籍与章节、摘抄、阅读时长、打卡记录、'
          '偏好设置都会被永久清除，且无法恢复。\n\n确定要删除吗？',
      confirmLabel: '确认删除',
      danger: true,
    );
    if (!second || !mounted) {
      return;
    }

    setState(() => _deleting = true);
    final AccountDataService accountData = context.read<AccountDataService>();
    await accountData.deleteAccount();
    if (!mounted) {
      return;
    }
    showSoftMessage(context, '已清空全部本地数据');
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.onboarding,
      (Route<dynamic> route) => false,
    );
  }

  Future<void> _exportArchive() async {
    await WkArchiveFlow.export(context);
  }

  Future<void> _importArchive() async {
    final bool applied = await WkArchiveFlow.import(context);
    if (applied && mounted) {
      _controller?.load();
    }
  }

  // ---------------- 页面 ----------------

  @override
  Widget build(BuildContext context) {
    final ProfileController? controller = _controller;
    final Listenable? listenable = _listenable;
    if (controller == null || listenable == null) {
      return const SizedBox.shrink();
    }

    return GridBackground(
      child: SafeArea(
        bottom: false,
        child: AnimatedBuilder(
          animation: listenable,
          builder: (BuildContext context, Widget? child) {
            final Brightness brightness = Theme.of(context).brightness;
            return RefreshIndicator(
              color: AppColors.accent(brightness),
              backgroundColor: AppColors.surface(brightness),
              onRefresh: () async => controller.load(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 6, 0, 130),
                children: <Widget>[
                  _buildHeader(brightness),
                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _buildAccountCard(brightness, controller),
                        const SizedBox(height: 18),
                        _buildStatRow(brightness, controller),
                        const SizedBox(height: 30),
                        const SectionHeader(
                          title: '阅读数据',
                          english: 'READING DATA',
                        ),
                        const SizedBox(height: 16),
                        _buildReadingEntries(brightness, controller),
                        const SizedBox(height: 30),
                        const SectionHeader(
                          title: '阅读偏好',
                          english: 'READING TASTE',
                        ),
                        const SizedBox(height: 16),
                        _buildRadarCard(brightness, controller),
                        const SizedBox(height: 30),
                        const SectionHeader(
                          title: '数据与备份',
                          english: 'DATA & BACKUP',
                        ),
                        const SizedBox(height: 16),
                        _buildBackupRow(brightness),
                        const SizedBox(height: 30),
                        const SectionHeader(
                          title: '关于与支持',
                          english: 'ABOUT & SUPPORT',
                        ),
                        const SizedBox(height: 16),
                        _buildAboutEntries(brightness),
                        const SizedBox(height: 34),
                        _buildDeleteAccount(brightness),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(Brightness brightness) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '我的',
                      style: AppTypography.chineseTitle(
                        brightness,
                        fontSize: 27,
                      ).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'PROFILE',
                      style: AppTypography.englishLabel(
                        brightness,
                        fontSize: 9.5,
                        letterSpacing: 3.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PressableScale(
                pressedScale: 0.92,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.settings),
                child: LiquidGlass(
                  borderRadius: 20,
                  padding: const EdgeInsets.all(9),
                  opacity: 0.10,
                  shadows: false,
                  child: Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ThinDivider(color: AppColors.divider(brightness)),
        ],
      ),
    );
  }

  // ---------------- 账号卡 ----------------

  Widget _buildAccountCard(
    Brightness brightness,
    ProfileController controller,
  ) {
    return LiquidGlass(
      borderRadius: 24,
      padding: const EdgeInsets.fromLTRB(18, 18, 16, 18),
      child: Row(
        children: <Widget>[
          AvatarPicker(
            imagePath: controller.avatarPath,
            size: 62,
            onTap: _pickAvatar,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  controller.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontFamilyFallback: AppFonts.serifFallback,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '已入驻 ${controller.joinedDays} 天 · 本地账号',
                  style: TextStyle(
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                    color: AppColors.textTertiary(brightness),
                  ),
                ),
              ],
            ),
          ),
          PressableScale(
            pressedScale: 0.92,
            onTap: _editUserName,
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 三个核心统计 ----------------

  Widget _buildStatRow(
    Brightness brightness,
    ProfileController controller,
  ) {
    return LiquidGlass(
      borderRadius: 20,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatBlock(
              label: '入驻天数',
              value: '${controller.joinedDays}',
              unit: '天',
              brightness: brightness,
            ),
          ),
          _verticalDivider(brightness),
          Expanded(
            child: _StatBlock(
              label: '累计阅读',
              value: controller.readingDurationLabel,
              brightness: brightness,
              highlight: true,
            ),
          ),
          _verticalDivider(brightness),
          Expanded(
            child: _StatBlock(
              label: '打卡天数',
              value: '${controller.totalCheckInDays}',
              unit: '天',
              brightness: brightness,
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider(Brightness brightness) {
    return Container(
      width: 0.8,
      height: 30,
      color: AppColors.divider(brightness),
    );
  }

  // ---------------- 阅读数据入口 ----------------

  Widget _buildReadingEntries(
    Brightness brightness,
    ProfileController controller,
  ) {
    return LiquidGlass(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: <Widget>[
          _EntryRow(
            icon: Icons.calendar_month_outlined,
            title: '阅读打卡日历',
            subtitle: '本月 ${controller.monthCheckInDays} 天 · '
                '累计 ${controller.totalCheckInDays} 天',
            brightness: brightness,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) =>
                    CheckInPage(stats: controller.stats),
              ),
            ),
          ),
          _entryDivider(brightness),
          _EntryRow(
            icon: Icons.auto_stories_outlined,
            title: '全部书籍',
            subtitle: '共 ${controller.totalBooks} 本',
            brightness: brightness,
            onTap: () => _openBookList(BookListFilter.all),
          ),
          _entryDivider(brightness),
          _EntryRow(
            icon: Icons.task_alt_rounded,
            title: '已读书籍',
            subtitle: '共 ${controller.finishedBooks} 本',
            brightness: brightness,
            onTap: () => _openBookList(BookListFilter.finished),
          ),
          _entryDivider(brightness),
          _EntryRow(
            icon: Icons.bookmarks_outlined,
            title: '书签库',
            subtitle: '全部书籍的书签都在这里',
            brightness: brightness,
            onTap: _openBookmarkLibrary,
          ),
          _entryDivider(brightness),
          _EntryRow(
            icon: Icons.menu_book_outlined,
            title: '未读书籍',
            subtitle: '共 ${controller.unfinishedBooks} 本',
            brightness: brightness,
            onTap: () => _openBookList(BookListFilter.unfinished),
          ),
          _entryDivider(brightness),
          // 需求：「我的」页面提供检查更新入口，手动检测不受 7 天冷却限制。
          _EntryRow(
            icon: Icons.system_update_alt_rounded,
            title: '检查更新',
            subtitle: '当前版本 v${AppConstants.versionName} · '
                '${AppConstants.versionCode}',
            brightness: brightness,
            onTap: _openVersionPage,
          ),
        ],
      ),
    );
  }

  // ---------------- 关于与支持入口 ----------------

  /// 关于与支持：打赏、安全声明 / 技术说明 / 关于作者、更新日志。
  ///
  /// 这些内容原来被塞在设置页最底部，几乎没人翻得到；
  /// 现在直接放在「我的」页面，打赏入口一眼可见。
  Widget _buildAboutEntries(Brightness brightness) {
    return LiquidGlass(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        children: <Widget>[
          _EntryRow(
            icon: Icons.local_cafe_outlined,
            title: '打赏支持',
            subtitle: '如果你对这个项目感兴趣，可以请我喝杯咖啡',
            brightness: brightness,
            onTap: () => showDonateDialog(context),
          ),
          _entryDivider(brightness),
          _EntryRow(
            icon: Icons.info_outline_rounded,
            title: '关于与支持',
            subtitle: '安全声明 · 技术说明 · 关于作者',
            brightness: brightness,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const AboutSupportPage(),
              ),
            ),
          ),
          _entryDivider(brightness),
          _EntryRow(
            icon: Icons.history_rounded,
            title: '更新日志',
            subtitle: '当前版本 v${AppConstants.versionName}',
            brightness: brightness,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) => const ChangelogPage(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryDivider(Brightness brightness) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ThinDivider(
        thickness: 0.6,
        color: AppColors.alpha(AppColors.divider(brightness), 0.7),
      ),
    );
  }

  Future<void> _openBookList(BookListFilter filter) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => BookListPage(filter: filter),
      ),
    );
    if (mounted) {
      _controller?.load();
    }
  }

  /// 打开总书签库（全部书籍的书签汇总）。
  Future<void> _openBookmarkLibrary() async {
    await Navigator.of(context).pushNamed(AppRoutes.bookmarkLibrary);
    if (mounted) {
      _controller?.load();
    }
  }

  /// 打开版本页并立即执行一次手动检测（不受自动检测冷却限制）。
  Future<void> _openVersionPage() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const VersionPage(checkOnOpen: true),
      ),
    );
  }

  // ---------------- 雷达图 ----------------
  Widget _buildRadarCard(
    Brightness brightness,
    ProfileController controller,
  ) {
    // 八维：标签权重 × 阅读时长，阅读页退出后即时刷新。
    final List<double> values = controller.tagRadar;
    final List<String> dims = TagWeightRepository.dimensions;
    final Map<String, double> ratios = <String, double>{
      for (int i = 0; i < dims.length; i++)
        dims[i]: i < values.length ? values[i] : 0,
    };
    final String? top = controller.topTag;

    return SizedBox(
      width: double.infinity,
      child: LiquidGlass(
        borderRadius: 22,
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
        child: Column(
          children: <Widget>[
            Center(child: TagRadarChart(ratios: ratios, size: 236)),
            const SizedBox(height: 6),
            Text(
              top == null ? '开始阅读后这里会记录你的兴趣分布' : '最常读：$top',
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.8,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- 数据包 ----------------

  Widget _buildBackupRow(Brightness brightness) {
    // 两张卡严格等宽等高、整体居中：用 LayoutBuilder 直接把可用宽度二等分，
    // 不依赖 Expanded 的弹性计算，避免不同机型/语言下出现宽度偏差。
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 12;
        final double cardWidth = (constraints.maxWidth - gap) / 2;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: cardWidth,
              child: _BackupAction(
                icon: Icons.archive_outlined,
                title: '导出数据包',
                english: 'EXPORT ARCHIVE',
                brightness: brightness,
                onTap: _exportArchive,
              ),
            ),
            const SizedBox(width: gap),
            SizedBox(
              width: cardWidth,
              child: _BackupAction(
                icon: Icons.unarchive_outlined,
                title: '恢复数据包',
                english: 'RESTORE BACKUP',
                brightness: brightness,
                onTap: _importArchive,
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------- 删除账号 ----------------

  Widget _buildDeleteAccount(Brightness brightness) {
    return PressableScale(
      enabled: !_deleting,
      pressedScale: 0.98,
      onTap: _deleteAccount,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: AppColors.danger,
                ),
                const SizedBox(width: 8),
                Text(
                  _deleting ? '正在清除…' : '账号数据删除',
                  style: TextStyle(
                    fontSize: 12.5,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '删除后本机全部阅读数据与设置不可恢复',
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.4,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 局部组件 ----------------

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.label,
    required this.value,
    required this.brightness,
    this.unit,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String? unit;
  final Brightness brightness;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color color = highlight
        ? AppColors.accent(brightness)
        : AppColors.textPrimary(brightness);

    return Column(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            fontSize: 9.5,
            letterSpacing: 0.8,
            color: AppColors.textTertiary(brightness),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          unit == null ? value : '$value $unit',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppFonts.serif,
            fontFamilyFallback: AppFonts.serifFallback,
            fontSize: unit == null ? 14 : 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.brightness,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.985,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 17, color: AppColors.accent(brightness)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      letterSpacing: 0.4,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.3,
                      color: AppColors.textTertiary(brightness),
                    ),
                  ),
                ],
              ),
            ),
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

class _BackupAction extends StatelessWidget {
  const _BackupAction({
    required this.icon,
    required this.title,
    required this.english,
    required this.brightness,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String english;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.97,
      onTap: onTap,
      child: LiquidGlass(
        borderRadius: 18,
        // 固定高度：两张卡片文字长短不同（EXPORT .WKARCHIVE / RESTORE BACKUP），
        // 高度由内容撑开时会出现一高一矮，这里统一成同一尺寸并整体居中。
        child: SizedBox(
          height: 96,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  icon,
                  size: 20,
                  color: AppColors.textSecondary(brightness),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 0.6,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  english,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 7.2,
                    letterSpacing: 0.8,
                    color: AppColors.textTertiary(brightness),
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
