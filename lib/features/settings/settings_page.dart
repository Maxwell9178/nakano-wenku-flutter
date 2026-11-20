import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/book.dart';
import '../../core/models/reading_preferences.dart';
import '../../core/routing/app_routes.dart';
import '../../core/routing/soft_page_route.dart';
import '../../core/services/book_repository.dart';
import '../../core/services/custom_font_service.dart';
import '../../core/services/reading_preferences_repository.dart';
import '../../core/settings/app_settings.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/ghost_button.dart';
import '../../core/widgets/grid_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/page_top_bar.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/thin_divider.dart';
import '../profile/pages/book_list_page.dart';
import '../reader/widgets/glass_slider.dart';

/// 设置页。
///
/// 全部偏好都写入 [AppSettingsController] / [ReadingPreferencesRepository]，
/// 页面本身不持有业务状态：改动即保存，重建后从本地读回。
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  ReadingPreferences? _preferences;
  int _finishedCount = 0;
  int _unfinishedCount = 0;
  bool _loadingBooks = true;

  ReadingPreferencesRepository? _preferenceStore;
  CustomFontService? _fontService;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preferenceStore != null) {
      return;
    }
    _preferenceStore = context.read<ReadingPreferencesRepository>();
    _fontService = context.read<CustomFontService>();
    _preferences = _preferenceStore!.load();
    _loadBookCounts();
  }

  Future<void> _loadBookCounts() async {
    final List<Book> books = context.read<BookRepository>().loadAll();
    int finished = 0;
    for (final Book book in books) {
      if (book.isFinished) {
        finished++;
      }
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _finishedCount = finished;
      _unfinishedCount = books.length - finished;
      _loadingBooks = false;
    });
  }

  Future<void> _updatePreferences(ReadingPreferences next) async {
    setState(() => _preferences = next);
    await _preferenceStore?.save(next);
  }

  /// 默认背景的展示名（空串表示跟随主题）。
  String _backgroundLabel(String id) {
    if (id.isEmpty) {
      return '跟随主题';
    }
    return ReadingBackground.findBuiltIn(id)?.name ?? '自定义背景';
  }

  Future<void> _pickFont() async {
    final CustomFontService? service = _fontService;
    if (service == null) {
      return;
    }
    try {
      final String? path = await service.importFont();
      if (path == null || !mounted) {
        return;
      }
      final AppSettingsController settings =
          context.read<AppSettingsController>();
      await settings.setCustomFontPath(path);
      await settings.setReadingFontMode(ReadingFontMode.custom);
      if (mounted) {
        showSoftMessage(context, '字体已导入并启用');
      }
    } on CustomFontException catch (error) {
      if (mounted) {
        showSoftMessage(context, error.message);
      }
    } on Object {
      if (mounted) {
        showSoftMessage(context, '字体导入失败，请换一个字体文件');
      }
    }
  }

  Future<void> _clearFont() async {
    final AppSettingsController settings =
        context.read<AppSettingsController>();
    await _fontService?.clear();
    await settings.setCustomFontPath(null);
    if (settings.readingFontMode == ReadingFontMode.custom) {
      await settings.setReadingFontMode(ReadingFontMode.system);
    }
    if (!mounted) {
      return;
    }
    showSoftMessage(context, '已移除自定义字体');
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final AppSettingsController settings =
        context.watch<AppSettingsController>();
    final Color accent = AppColors.accent(brightness);

    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      body: GridBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              const PageTopBar(title: '设置', english: 'SETTINGS'),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
                  children: <Widget>[
                    _buildAppearanceCard(brightness, settings, accent),
                    const SizedBox(height: 26),
                    _buildFontCard(brightness, settings, accent),
                    const SizedBox(height: 26),
                    _buildReadingPreferenceCard(brightness, accent),
                    const SizedBox(height: 26),
                    _buildWatermarkCard(brightness, settings, accent),
                    const SizedBox(height: 26),
                    _buildLibraryCard(brightness, accent),
                    const SizedBox(height: 26),
                    _buildPerformanceCard(brightness, settings, accent),
                    const SizedBox(height: 26),
                    _buildAboutCard(brightness, accent),
                    const SizedBox(height: 28),
                    Center(
                      child: Text(
                        '${AppConstants.appName} · v${AppConstants.versionName}',
                        style: AppTypography.englishLabel(
                          brightness,
                          fontSize: 8.6,
                          letterSpacing: 2.4,
                          color: AppColors.textTertiary(brightness),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 外观（主题 / 毛玻璃 / 边框 / 预览） ----------------

  Widget _buildAppearanceCard(
    Brightness brightness,
    AppSettingsController settings,
    Color accent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '外观', english: 'APPEARANCE'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SettingLabel(
                title: '主题',
                english: 'THEME',
                brightness: brightness,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  _ChoiceChip(
                    label: '浅色',
                    selected: settings.themeMode == ThemeMode.light,
                    onTap: () => settings.setThemeMode(ThemeMode.light),
                    accent: accent,
                    brightness: brightness,
                  ),
                  const SizedBox(width: 8),
                  _ChoiceChip(
                    label: '深色',
                    selected: settings.themeMode == ThemeMode.dark,
                    onTap: () => settings.setThemeMode(ThemeMode.dark),
                    accent: accent,
                    brightness: brightness,
                  ),
                  const SizedBox(width: 8),
                  _ChoiceChip(
                    label: '跟随系统',
                    selected: settings.themeMode == ThemeMode.system,
                    onTap: () => settings.setThemeMode(ThemeMode.system),
                    accent: accent,
                    brightness: brightness,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SettingLabel(
                title: '毛玻璃模糊',
                english: 'BLUR ${settings.glassBlur}',
                brightness: brightness,
              ),
              const SizedBox(height: 4),
              _SliderRow(
                value: settings.glassBlur.toDouble(),
                min: 0,
                max: 100,
                onChanged: (double value) =>
                    settings.setGlassBlur(value.round()),
                accent: accent,
              ),
              const SizedBox(height: 10),
              _SettingLabel(
                title: '毛玻璃透明度',
                english: 'OPACITY ${settings.glassOpacity}',
                brightness: brightness,
              ),
              const SizedBox(height: 4),
              _SliderRow(
                value: settings.glassOpacity.toDouble(),
                min: 0,
                max: 100,
                onChanged: (double value) =>
                    settings.setGlassOpacity(value.round()),
                accent: accent,
              ),
              const SizedBox(height: 16),
              _SettingLabel(
                title: '边框粗细',
                english: 'BORDER',
                brightness: brightness,
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  for (final GlassBorderLevel level in GlassBorderLevel.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _ChoiceChip(
                        label: level.label,
                        selected: settings.glassBorder == level,
                        onTap: () => settings.setGlassBorder(level),
                        accent: accent,
                        brightness: brightness,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              _buildGlassPreview(brightness, settings, accent),
            ],
          ),
        ),
      ],
    );
  }

  /// 2、3、4 项共用的小预览框：实时反映模糊 / 透明度 / 边框。
  Widget _buildGlassPreview(
    Brightness brightness,
    AppSettingsController settings,
    Color accent,
  ) {
    final GlassSpec spec = settings.glassSpec;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 92,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              AppColors.alpha(accent, 0.16),
              AppColors.alpha(accent, 0.03),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppColors.alpha(
                    brightness == Brightness.dark ? Colors.black : Colors.white,
                    spec.panelOpacity,
                  ),
                  border: Border.all(
                    width: spec.borderWidth,
                    color: AppColors.alpha(accent, 0.55),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '毛玻璃预览',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'GLASS PREVIEW · ${settings.glassBlur}/${settings.glassOpacity}',
                      style: AppTypography.englishLabel(
                        brightness,
                        fontSize: 8.2,
                        letterSpacing: 1.8,
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
    );
  }

  // ---------------- 阅读字体 ----------------

  Widget _buildFontCard(
    Brightness brightness,
    AppSettingsController settings,
    Color accent,
  ) {
    final bool hasCustom =
        settings.customFontPath != null && settings.customFontPath!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '阅读字体', english: 'TYPEFACE'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
          child: Column(
            children: <Widget>[
              for (final ReadingFontMode mode in ReadingFontMode.values)
                _FontOptionRow(
                  mode: mode,
                  selected: settings.readingFontMode == mode,
                  brightness: brightness,
                  accent: accent,
                  subtitle: mode == ReadingFontMode.custom
                      ? (hasCustom ? '已导入字体包' : '未导入字体包')
                      : null,
                  onTap: () async {
                    if (mode == ReadingFontMode.custom && !hasCustom) {
                      await _pickFont();
                      return;
                    }
                    await settings.setReadingFontMode(mode);
                  },
                ),
              const SizedBox(height: 6),
              ThinDivider(width: double.infinity, thickness: 0.7),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: GhostButton(
                      label: '导入字体包',
                      english: 'Import font',
                      icon: Icons.file_upload_outlined,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      onTap: _pickFont,
                    ),
                  ),
                  if (hasCustom) ...<Widget>[
                    const SizedBox(width: 10),
                    Expanded(
                      child: GhostButton(
                        label: '移除自定义',
                        english: 'Remove',
                        icon: Icons.delete_outline_rounded,
                        accent: false,
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        onTap: _clearFont,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text(
                '支持 ttf / otf / ttc，仅在本机保存与使用；缺字时自动回退宋体。',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.6,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- 阅读偏好（全局持久化） ----------------

  Widget _buildReadingPreferenceCard(Brightness brightness, Color accent) {
    final ReadingPreferences prefs = _preferences ?? const ReadingPreferences();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SectionHeader(
          title: '阅读偏好',
          english: 'READING',
          trailing: _LinkText(
            label: '恢复默认',
            brightness: brightness,
            onTap: () => _updatePreferences(const ReadingPreferences()),
          ),
        ),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SliderTitle(
                title: '字号',
                value: '${prefs.fontSize.toStringAsFixed(1)} pt',
                brightness: brightness,
              ),
              _SliderRow(
                value: prefs.fontSize,
                min: ReadingPreferences.fontSizeMin,
                max: ReadingPreferences.fontSizeMax,
                onChanged: (double value) =>
                    _updatePreferences(prefs.copyWith(fontSize: value)),
                accent: accent,
              ),
              _SliderTitle(
                title: '行距',
                value: '${prefs.lineHeight.toStringAsFixed(2)} 倍',
                brightness: brightness,
              ),
              _SliderRow(
                value: prefs.lineHeight,
                min: ReadingPreferences.lineHeightMin,
                max: ReadingPreferences.lineHeightMax,
                onChanged: (double value) =>
                    _updatePreferences(prefs.copyWith(lineHeight: value)),
                accent: accent,
              ),
              _SliderTitle(
                title: '段落间距',
                value: '${prefs.paragraphSpacing.round()} px',
                brightness: brightness,
              ),
              _SliderRow(
                value: prefs.paragraphSpacing,
                min: ReadingPreferences.paragraphSpacingMin,
                max: ReadingPreferences.paragraphSpacingMax,
                onChanged: (double value) =>
                    _updatePreferences(prefs.copyWith(paragraphSpacing: value)),
                accent: accent,
              ),
              _SliderTitle(
                title: '左右页边距',
                value: '${prefs.leftMargin.round()} / '
                    '${prefs.rightMargin.round()} px',
                brightness: brightness,
              ),
              _SliderRow(
                value: prefs.leftMargin,
                min: ReadingPreferences.marginMin,
                max: ReadingPreferences.marginMax,
                onChanged: (double value) => _updatePreferences(
                  prefs.copyWith(leftMargin: value, rightMargin: value),
                ),
                accent: accent,
              ),
              _SliderTitle(
                title: '上下页边距',
                value: '${prefs.topMargin.round()} / '
                    '${prefs.bottomMargin.round()} px',
                brightness: brightness,
              ),
              _SliderRow(
                value: prefs.topMargin,
                min: ReadingPreferences.marginMin,
                max: ReadingPreferences.marginMax,
                onChanged: (double value) => _updatePreferences(
                  prefs.copyWith(topMargin: value, bottomMargin: value),
                ),
                accent: accent,
              ),
              const SizedBox(height: 8),
              _SliderTitle(
                title: '翻页模式',
                value: prefs.pageMode.label,
                brightness: brightness,
              ),
              Row(
                children: <Widget>[
                  _ChoiceChip(
                    label: ReaderPageMode.scroll.label,
                    selected: prefs.pageMode == ReaderPageMode.scroll,
                    onTap: () => _updatePreferences(
                      prefs.copyWith(pageMode: ReaderPageMode.scroll),
                    ),
                    accent: accent,
                    brightness: brightness,
                  ),
                  const SizedBox(width: 8),
                  _ChoiceChip(
                    label: ReaderPageMode.horizontal.label,
                    selected: prefs.pageMode == ReaderPageMode.horizontal,
                    onTap: () => _updatePreferences(
                      prefs.copyWith(pageMode: ReaderPageMode.horizontal),
                    ),
                    accent: accent,
                    brightness: brightness,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _SliderTitle(
                title: '默认背景',
                value: _backgroundLabel(prefs.defaultBackgroundId),
                brightness: brightness,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  _ChoiceChip(
                    label: '跟随主题',
                    selected: prefs.defaultBackgroundId.isEmpty,
                    onTap: () => _updatePreferences(
                        prefs.copyWith(defaultBackgroundId: '')),
                    accent: accent,
                    brightness: brightness,
                  ),
                  for (final ReadingBackground item
                      in ReadingBackground.builtIns)
                    _ChoiceChip(
                      label: item.name,
                      selected: prefs.defaultBackgroundId == item.id,
                      onTap: () => _updatePreferences(
                        prefs.copyWith(defaultBackgroundId: item.id),
                      ),
                      accent: accent,
                      brightness: brightness,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '这里的调整会作为全局阅读偏好保存，阅读页打开时自动读取；'
                '某本书在阅读页单独换过背景时，以那本书为准。',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.6,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- 阅读水印 ----------------

  Widget _buildWatermarkCard(
    Brightness brightness,
    AppSettingsController settings,
    Color accent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '阅读水印', english: 'WATERMARK'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _SettingLabel(
                      title: '开启水印',
                      english: 'ENABLED',
                      brightness: brightness,
                    ),
                  ),
                  _GlassSwitch(
                    value: settings.watermarkEnabled,
                    accent: accent,
                    onChanged: settings.setWatermarkEnabled,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: settings.watermarkEnabled ? 1 : 0.45,
                child: IgnorePointer(
                  ignoring: !settings.watermarkEnabled,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _SettingLabel(
                        title: '水印类型',
                        english: 'STYLE',
                        brightness: brightness,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: <Widget>[
                          for (final WatermarkType type in WatermarkType.values)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ChoiceChip(
                                label: '${type.label} · ${type.english}',
                                selected: settings.watermarkType == type,
                                onTap: () => settings.setWatermarkType(type),
                                accent: accent,
                                brightness: brightness,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.alpha(
                            accent,
                            brightness == Brightness.dark ? 0.08 : 0.05,
                          ),
                        ),
                        child: Text(
                          settings.watermarkType.sample,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.6,
                            letterSpacing: 0.8,
                            color: AppColors.textSecondary(brightness),
                          ),
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

  // ---------------- 书籍统计入口 ----------------

  Widget _buildLibraryCard(Brightness brightness, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '我的书籍', english: 'LIBRARY'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: <Widget>[
              _StatEntryRow(
                title: '已读书目',
                english: 'FINISHED',
                count: _loadingBooks ? null : _finishedCount,
                brightness: brightness,
                accent: accent,
                onTap: () => _openBookList(BookListFilter.finished),
              ),
              ThinDivider(width: double.infinity, thickness: 0.7),
              _StatEntryRow(
                title: '未读书目',
                english: 'UNFINISHED',
                count: _loadingBooks ? null : _unfinishedCount,
                brightness: brightness,
                accent: accent,
                onTap: () => _openBookList(BookListFilter.unfinished),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openBookList(BookListFilter filter) async {
    await Navigator.of(context).push<void>(
      SoftPageRoute<void>(
        builder: (BuildContext context) => BookListPage(filter: filter),
      ),
    );
    await _loadBookCounts();
  }

  // ---------------- 关于与版本 ----------------

  Widget _buildAboutCard(Brightness brightness, Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '关于与版本', english: 'ABOUT'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          child: Column(
            children: <Widget>[
              _AboutRow(
                title: '版本信息',
                english: 'VERSION',
                value:
                    'v${AppConstants.versionName} · ${AppConstants.versionCode}',
                brightness: brightness,
                accent: accent,
                onTap: () => Navigator.of(context).pushNamed(AppRoutes.version),
              ),
              ThinDivider(width: double.infinity, thickness: 0.7),
              _AboutRow(
                title: '安全声明',
                english: 'SAFETY NOTICE',
                value: '本地优先',
                brightness: brightness,
                accent: accent,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.safetyNotice),
              ),
              ThinDivider(width: double.infinity, thickness: 0.7),
              _AboutRow(
                title: '技术说明',
                english: 'TECH NOTES',
                value: '离线运行',
                brightness: brightness,
                accent: accent,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.techNotes),
              ),
              ThinDivider(width: double.infinity, thickness: 0.7),
              _AboutRow(
                title: '关于作者',
                english: 'ABOUT AUTHOR',
                value: AppConstants.author,
                brightness: brightness,
                accent: accent,
                onTap: () =>
                    Navigator.of(context).pushNamed(AppRoutes.aboutAuthor),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------- 性能与动效 ----------------

  Widget _buildPerformanceCard(
    Brightness brightness,
    AppSettingsController settings,
    Color accent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SectionHeader(title: '性能与动效', english: 'PERFORMANCE'),
        const SizedBox(height: 14),
        LiquidGlass(
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _SettingLabel(
                title: '帧率偏好',
                english: 'FRAME RATE',
                brightness: brightness,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  for (final FrameRateOption option in FrameRateOption.values)
                    _ChoiceChip(
                      label: option.label,
                      selected: settings.frameRate == option,
                      onTap: () => settings.setFrameRate(option),
                      accent: accent,
                      brightness: brightness,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                settings.frameRate.description,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.6,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
              const SizedBox(height: 16),
              ThinDivider(width: double.infinity, thickness: 0.7),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _SettingLabel(
                          title: '减少动画',
                          english: 'REDUCE MOTION',
                          brightness: brightness,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '关闭页面切换与卡片的过渡动画，适合低配设备',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.6,
                            color: AppColors.textTertiary(brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _GlassSwitch(
                    value: settings.reduceMotion,
                    accent: accent,
                    onChanged: settings.setReduceMotion,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------- 小区块组件 ----------------

/// 中文标题 + 右侧英文数值的标签行。
class _SettingLabel extends StatelessWidget {
  const _SettingLabel({
    required this.title,
    required this.english,
    required this.brightness,
  });

  final String title;
  final String english;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.textPrimary(brightness),
            ),
          ),
        ),
        Text(
          english,
          style: AppTypography.englishLabel(
            brightness,
            fontSize: 8.2,
            letterSpacing: 2.0,
            color: AppColors.textTertiary(brightness),
          ),
        ),
      ],
    );
  }
}

/// 滑块标题：左侧中文 + 右侧实时数值。
class _SliderTitle extends StatelessWidget {
  const _SliderTitle({
    required this.title,
    required this.value,
    required this.brightness,
  });

  final String title;
  final String value;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 2),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
              color: AppColors.textTertiary(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

/// 统一封装的液态滑块行。
class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.accent,
  });

  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: GlassSlider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        accent: accent,
        onChanged: onChanged,
      ),
    );
  }
}

/// 胶囊选择块。
class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
    required this.brightness,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.95,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? AppColors.alpha(accent, 0.14)
              : AppColors.alpha(
                  brightness == Brightness.dark ? Colors.white : Colors.black,
                  0.02,
                ),
          border: Border.all(
            width: selected ? 1.0 : 0.7,
            color: selected
                ? AppColors.alpha(accent, 0.55)
                : AppColors.divider(brightness),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.4,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppColors.textPrimary(brightness)
                : AppColors.textSecondary(brightness),
          ),
        ),
      ),
    );
  }
}

/// 字体选项行。
class _FontOptionRow extends StatelessWidget {
  const _FontOptionRow({
    required this.mode,
    required this.selected,
    required this.brightness,
    required this.accent,
    required this.onTap,
    this.subtitle,
  });

  final ReadingFontMode mode;
  final bool selected;
  final Brightness brightness;
  final Color accent;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.99,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  width: selected ? 5.0 : 0.9,
                  color: selected
                      ? AppColors.alpha(accent, 0.75)
                      : AppColors.divider(brightness),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  if (subtitle != null) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textTertiary(brightness),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              mode.english,
              style: AppTypography.englishLabel(
                brightness,
                fontSize: 8.2,
                letterSpacing: 1.8,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 书籍统计入口行（左标题、右数量 + 箭头）。
class _StatEntryRow extends StatelessWidget {
  const _StatEntryRow({
    required this.title,
    required this.english,
    required this.count,
    required this.brightness,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String english;
  final int? count;
  final Brightness brightness;
  final Color accent;
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
            Text(
              count == null ? '—' : '$count 本',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.alpha(accent, 0.9),
              ),
            ),
            const SizedBox(width: 6),
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

/// 右侧文字按钮（恢复默认）。
class _LinkText extends StatelessWidget {
  const _LinkText({
    required this.label,
    required this.brightness,
    required this.onTap,
  });

  final String label;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.94,
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 0.4,
          color: AppColors.textTertiary(brightness),
        ),
      ),
    );
  }
}

/// 「中文标签 + 英文标注 + 右侧值」的入口行（关于与版本分组）。
class _AboutRow extends StatelessWidget {
  const _AboutRow({
    required this.title,
    required this.english,
    required this.value,
    required this.brightness,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String english;
  final String value;
  final Brightness brightness;
  final Color accent;
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
              constraints: const BoxConstraints(maxWidth: 150),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.alpha(accent, 0.9),
                ),
              ),
            ),
            const SizedBox(width: 6),
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

/// 细长玻璃开关（与阅读设置保持同一视觉语言）。
class _GlassSwitch extends StatelessWidget {
  const _GlassSwitch({
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      pressedScale: 0.94,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 44,
        height: 25,
        padding: const EdgeInsets.all(2.6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: value
              ? AppColors.alpha(accent, 0.75)
              : AppColors.alpha(Colors.grey, 0.28),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 19.8,
            height: 19.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.alpha(Colors.black, 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
