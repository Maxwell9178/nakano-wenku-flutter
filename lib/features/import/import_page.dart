import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/models/import_site.dart';
import '../../core/services/book_import_service.dart';
import '../../core/services/import_site_repository.dart';
import '../../core/services/local_file_scanner.dart';
import '../../core/services/tag_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/feedback.dart';
import '../../core/widgets/confirm_dialog.dart';
import '../../core/widgets/ghost_button.dart';
import '../../core/widgets/glass_dialog.dart';
import '../../core/widgets/grid_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/page_top_bar.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/section_header.dart';
import '../../core/widgets/text_input_dialog.dart';
// (thin_divider import removed: page draws its own hairlines)
import 'import_controller.dart';
import 'widgets/import_progress_card.dart';
import 'widgets/site_ball.dart';

/// 导入页：网站快捷访问 + 本地扫描 + 格式筛选 + 多选导入 + 多卷策略。
///
/// 解析与写库都在 [ImportController] 里完成，本页只负责交互与展示。
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  ImportController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller ??= ImportController(
      scanner: context.read<LocalFileScanner>(),
      importService: context.read<BookImportService>(),
      siteRepository: context.read<ImportSiteRepository>(),
    )..loadSites();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  ImportController get _c => _controller!;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        child: SafeArea(
          bottom: false,
          child: AnimatedBuilder(
            animation: _c,
            builder: (BuildContext context, Widget? child) {
              return Stack(
                children: <Widget>[
                  Column(
                    children: <Widget>[
                      PageTopBar(
                        title: '导入书籍',
                        english: 'Import books',
                        trailing: _c.entries.isEmpty
                            ? null
                            : _SmallTextButton(
                                label: _c.selectedCount == _c.entries.length
                                    ? '清空'
                                    : '全选',
                                onTap: _c.selectedCount == _c.entries.length
                                    ? _c.clearSelection
                                    : _c.selectAll,
                              ),
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(0, 18, 0, 150),
                          children: <Widget>[
                            _buildSites(context),
                            const SizedBox(height: 26),
                            _buildFormats(context),
                            const SizedBox(height: 26),
                            _buildScanRow(context),
                            const SizedBox(height: 22),
                            if (_c.failures.isNotEmpty) _buildFailures(context),
                            _buildEntryList(context),
                            const SizedBox(height: 24),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: ImportHintLine(
                                english: 'Offline import',
                                text: '支持 EPUB / TXT / Markdown / DOCX / ZIP，'
                                    'ZIP 会自动展开内部的多卷 txt、epub 与 docx；'
                                    'PDF 与旧版 DOC 可扫描与勾选，但正文解析会在后续版本补齐。'
                                    '所有文件只在本机解析，不会上传。',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 0,
                    child: SafeArea(
                      top: false,
                      minimum: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          if (_c.importing &&
                              _c.progresses.isNotEmpty) ...<Widget>[
                            ImportProgressCard(progresses: _c.progresses),
                            const SizedBox(height: 10),
                          ],
                          _buildImportBar(context),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 网站小球

  Widget _buildSites(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SectionHeader(
            title: '快捷访问',
            english: 'Quick sites',
            trailing: Text(
              '长按可编辑或移除',
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            children: <Widget>[
              SiteBallAddButton(onTap: _addSite),
              for (int i = 0; i < _c.sites.length; i++) ...<Widget>[
                const SizedBox(width: 18),
                SiteBall(
                  site: _c.sites[i],
                  index: i + 1,
                  onTap: () => _openSite(_c.sites[i]),
                  onLongPress: () => _siteActions(_c.sites[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _addSite() async {
    final String? name = await showTextInputDialog(
      context: context,
      title: '站点名称',
      english: 'Site name',
      message: '名称只保存在本机，可随时修改。',
      hintText: '例如：轻小说文库',
      maxLength: 12,
    );
    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    final String? url = await showTextInputDialog(
      context: context,
      title: '站点网址',
      english: 'Site url',
      message: '网址会隐藏保存，界面只显示名称。',
      hintText: 'https://example.com',
      maxLength: 200,
      keyboardType: TextInputType.url,
      validator: (String value) {
        final Uri? uri = Uri.tryParse(value);
        if (uri == null ||
            !uri.hasScheme ||
            (uri.scheme != 'http' && uri.scheme != 'https')) {
          return '请输入 http / https 开头的完整网址';
        }
        return null;
      },
    );
    if (url == null || !mounted) {
      return;
    }

    await _c.addSite(name: name, url: url);
  }

  /// 长按站点小球：编辑或移除（不直接删除，避免误触）。
  Future<void> _siteActions(ImportSite site) async {
    String action = '';
    await showGlassDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return GlassDialogCard(
          title: site.name,
          english: 'QUICK SITE',
          message: site.url,
          actions: <Widget>[
            GlassDialogButton(
              label: '编辑',
              onTap: () {
                action = 'edit';
                Navigator.of(dialogContext).pop();
              },
            ),
            GlassDialogButton(
              label: '删除',
              danger: true,
              onTap: () {
                action = 'delete';
                Navigator.of(dialogContext).pop();
              },
            ),
          ],
        );
      },
    );
    if (!mounted) {
      return;
    }
    if (action == 'edit') {
      await _editSite(site);
    } else if (action == 'delete') {
      await _removeSite(site);
    }
  }

  Future<void> _editSite(ImportSite site) async {
    final String? name = await showTextInputDialog(
      context: context,
      title: '站点名称',
      english: 'Site name',
      message: '名称只保存在本机，可随时修改。',
      hintText: '例如：轻小说文库',
      initialValue: site.name,
      maxLength: 12,
    );
    if (name == null || name.isEmpty || !mounted) {
      return;
    }

    final String? url = await showTextInputDialog(
      context: context,
      title: '站点网址',
      english: 'Site url',
      message: '网址会隐藏保存，界面只显示名称。',
      hintText: 'https://example.com',
      initialValue: site.url,
      maxLength: 200,
      keyboardType: TextInputType.url,
      validator: (String value) {
        final Uri? uri = Uri.tryParse(value);
        if (uri == null ||
            !uri.hasScheme ||
            (uri.scheme != 'http' && uri.scheme != 'https')) {
          return '请输入 http / https 开头的完整网址';
        }
        return null;
      },
    );
    if (url == null || !mounted) {
      return;
    }

    await _c.updateSite(id: site.id, name: name, url: url);
    if (mounted) {
      showSoftMessage(context, '快捷入口已更新');
    }
  }

  Future<void> _openSite(ImportSite site) async {
    final Uri? uri = Uri.tryParse(site.url);
    if (uri == null) {
      return;
    }
    try {
      final bool opened =
          await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        showSoftMessage(context, '没有找到可用的浏览器');
      }
    } catch (_) {
      if (mounted) {
        showSoftMessage(context, '无法打开该站点');
      }
    }
  }

  Future<void> _removeSite(ImportSite site) async {
    final bool confirmed = await showConfirmDialog(
      context: context,
      title: '移除快捷站点',
      english: 'Remove site',
      message: '将移除「${site.name}」，已入库的书籍不受影响。',
      confirmLabel: '移除',
      danger: true,
    );
    if (!confirmed || !mounted) {
      return;
    }
    await _c.removeSite(site.id);
  }

  // ---------------------------------------------------------------- 格式筛选

  Widget _buildFormats(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SectionHeader(
            title: '导入格式',
            english: 'Formats',
            trailing: Text(
              '${_c.formats.length} / ${ImportController.formatOptions.length}',
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final String extension in ImportController.formatOptions)
                _FormatChip(
                  label: _formatLabel(extension),
                  selected: _c.isFormatEnabled(extension),
                  onTap: () => _c.toggleFormat(extension),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatLabel(String extension) {
    switch (extension) {
      case 'markdown':
        return 'Markdown';
      case 'docx':
        return 'DOCX';
      case 'doc':
        return 'DOC';
      default:
        return extension.toUpperCase();
    }
  }

  // ---------------------------------------------------------------- 扫描

  Widget _buildScanRow(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: <Widget>[
          LiquidGlass(
            borderRadius: 20,
            onTap: _c.scanning
                ? null
                : (_c.canScanStorage ? _c.scan : _c.pickManually),
            child: SizedBox(
              height: 52,
              child: Row(
                children: <Widget>[
                  const SizedBox(width: 18),
                  if (_c.scanning)
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        color: AppColors.accent(brightness),
                      ),
                    )
                  else
                    Icon(
                      _c.canScanStorage
                          ? Icons.manage_search_rounded
                          : Icons.folder_open_rounded,
                      size: 19,
                      color: AppColors.accent(brightness),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          _c.scanning
                              ? '正在读取文件…'
                              : (_c.canScanStorage ? '扫描本机文件' : '选择要导入的文件'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.4,
                            color: AppColors.textPrimary(brightness),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _c.canScanStorage
                              ? 'SCAN LOCAL STORAGE'
                              : 'CHOOSE FILES',
                          style: AppTypography.englishLabel(brightness,
                                  fontSize: 7.8, letterSpacing: 2.0)
                              .copyWith(
                                  color: AppColors.textTertiary(brightness)),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textTertiary(brightness),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
          if (_c.canScanStorage) ...<Widget>[
            const SizedBox(height: 10),
            GhostButton(
              label: '手动选择文件',
              english: 'Pick files',
              icon: Icons.file_open_outlined,
              onTap: _c.scanning ? null : _c.pickManually,
              expand: true,
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- 结果列表

  Widget _buildFailures(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.alpha(AppColors.danger, 0.32),
            width: 0.8,
          ),
          color: AppColors.alpha(AppColors.danger, 0.06),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.error_outline_rounded,
                    size: 15, color: AppColors.danger),
                const SizedBox(width: 8),
                Text(
                  '${_c.failures.length} 个文件未能导入',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final String failure in _c.failures.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  failure,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.5,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryList(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    if (_c.entries.isEmpty && !_c.scanning) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppColors.alpha(AppColors.divider(brightness), 0.85),
              width: 0.8,
            ),
          ),
          child: Column(
            children: <Widget>[
              Icon(
                Icons.folder_open_rounded,
                size: 26,
                color: AppColors.textTertiary(brightness),
              ),
              const SizedBox(height: 10),
              Text(
                '还没有扫描到文件',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _c.canScanStorage ? '点上方按钮扫描，或手动选择文件' : '点上方按钮，从设备里选择要导入的文件',
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_c.entries.isEmpty) {
      return const SizedBox.shrink();
    }

    // 按原始文件夹分区块：只显示文件夹名，不显示完整路径。
    final Map<String, List<LocalFileEntry>> groups =
        <String, List<LocalFileEntry>>{};
    for (final LocalFileEntry entry in _c.entries) {
      final int slash = entry.path.lastIndexOf('/');
      final String raw = slash <= 0 ? '' : entry.path.substring(0, slash);
      final int sep = raw.lastIndexOf('/');
      final String name =
          raw.isEmpty ? '内部存储' : (sep < 0 ? raw : raw.substring(sep + 1));
      groups
          .putIfAbsent(name.isEmpty ? '内部存储' : name, () => <LocalFileEntry>[])
          .add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SectionHeader(
            title: '本地文件',
            english: 'Local files',
            trailing: Text(
              '${_c.entries.length} 个 · 已选 ${_c.selectedCount}',
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        if (_c.truncated)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 4),
            child: Text(
              '文件较多，仅列出前 3000 个，可先筛选格式再扫描。',
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ),
        SizedBox(
          height: 430,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
            children: <Widget>[
              for (final MapEntry<String, List<LocalFileEntry>> group
                  in groups.entries) ...<Widget>[
                _buildFolderHeader(brightness, group.key, group.value),
                for (final LocalFileEntry entry in group.value)
                  _buildEntryRow(brightness, entry),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 文件夹区块标题 + 本区块独立全选。
  Widget _buildFolderHeader(
    Brightness brightness,
    String folder,
    List<LocalFileEntry> entries,
  ) {
    final int selected = entries
        .where((LocalFileEntry e) => _c.selectedPaths.contains(e.path))
        .length;
    final bool all = selected == entries.length;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.folder_rounded,
            size: 15,
            color: AppColors.textTertiary(brightness),
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              folder,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ),
          Text(
            '$selected/${entries.length}',
            style: TextStyle(
              fontSize: 9,
              color: AppColors.textTertiary(brightness),
            ),
          ),
          const SizedBox(width: 8),
          PressableScale(
            pressedScale: 0.94,
            onTap: () {
              // 已全选时逐个取消，否则把未选中的补上。
              for (final LocalFileEntry entry in entries) {
                final bool on = _c.selectedPaths.contains(entry.path);
                if (on == all) {
                  _c.toggleEntry(entry.path);
                }
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Text(
                all ? '取消全选' : '全选',
                style: TextStyle(
                  fontSize: 10,
                  color: all
                      ? AppColors.textTertiary(brightness)
                      : AppColors.accent(brightness),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryRow(Brightness brightness, LocalFileEntry entry) {
    final bool selected = _c.selectedPaths.contains(entry.path);
    return PressableScale(
      pressedScale: 0.99,
      onTap: () => _c.toggleEntry(entry.path),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: <Widget>[
            Icon(
              selected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              size: 19,
              color: selected
                  ? AppColors.accent(brightness)
                  : AppColors.textTertiary(brightness),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    entry.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${entry.extension.toUpperCase()} · ${entry.sizeLabel}',
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 0.3,
                      color: AppColors.textTertiary(brightness),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (!_c.supportedForParsing(entry.extension))
              Text(
                '暂不支持解析',
                style: TextStyle(
                  fontSize: 9,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 导入

  Widget _buildImportBar(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final bool busy = _c.importing;
    final bool enabled = !busy && _c.selectedCount > 0;

    return LiquidGlass(
      borderRadius: 26,
      onTap: enabled ? _startImport : null,
      opacity: enabled ? null : 0.08,
      child: SizedBox(
        height: 54,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (busy)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.7,
                    color: AppColors.accent(brightness),
                  ),
                )
              else
                Icon(
                  Icons.drive_folder_upload_outlined,
                  size: 18,
                  color: enabled
                      ? AppColors.accent(brightness)
                      : AppColors.textTertiary(brightness),
                ),
              const SizedBox(width: 10),
              Text(
                busy
                    ? '正在导入…'
                    : (_c.selectedCount == 0
                        ? '请先勾选要导入的文件'
                        : '导入所选（${_c.selectedCount}）'),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                  color: enabled
                      ? AppColors.textPrimary(brightness)
                      : AppColors.textTertiary(brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 调整「自选合并」的卷顺序；返回 null 表示用户取消。
  Future<List<int>?> _askMergeOrder(ImportPlan plan, Set<int> selection) async {
    final Brightness brightness = Theme.of(context).brightness;
    final List<int> order = plan.volumes
        .where(
            (ImportedVolume volume) => selection.contains(volume.sourceIndex))
        .map((ImportedVolume volume) => volume.sourceIndex)
        .toList();
    final Map<int, String> labels = <int, String>{
      for (final ImportedVolume volume in plan.volumes)
        volume.sourceIndex: volume.sourceLabel,
    };

    final List<int>? result = await showGlassDialog<List<int>>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) {
          return GlassDialogCard(
            title: '调整合并顺序',
            english: 'MERGE ORDER',
            message: '用上下箭头把卷排成正文的先后顺序，合并后章节就按这个顺序拼接。',
            content: SizedBox(
              height: 240,
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: order.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 6),
                itemBuilder: (BuildContext context, int index) {
                  final int sourceIndex = order[index];
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.divider(brightness),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: <Widget>[
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize: 12,
                            color: AppColors.textTertiary(brightness),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            labels[sourceIndex] ?? '第 $sourceIndex 卷',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textPrimary(brightness),
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          splashRadius: 16,
                          onPressed: index == 0
                              ? null
                              : () => setLocal(() {
                                    final int moved = order.removeAt(index);
                                    order.insert(index - 1, moved);
                                  }),
                          icon: const Icon(Icons.keyboard_arrow_up_rounded),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          iconSize: 16,
                          splashRadius: 16,
                          onPressed: index == order.length - 1
                              ? null
                              : () => setLocal(() {
                                    final int moved = order.removeAt(index);
                                    order.insert(index + 1, moved);
                                  }),
                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: <Widget>[
              GlassDialogButton(
                label: '按这个顺序合并',
                primary: true,
                onTap: () => Navigator.of(context).pop(order),
              ),
            ],
          );
        },
      ),
    );
    return result;
  }

  /// 导入前挑标签（最多两个，可不选）。
  Future<List<String>> _askImportTags() async {
    final Brightness brightness = Theme.of(context).brightness;
    final TagRepository repo = context.read<TagRepository>();
    final List<String> pool = repo.effectiveTags;
    if (pool.isEmpty) {
      return const <String>[];
    }
    final List<String> chosen = <String>[];

    final List<String>? result = await showGlassDialog<List<String>>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setLocal) {
          return GlassDialogCard(
            title: '给这批书选标签',
            english: 'TAGS',
            message: '最多选 ${TagRepository.maxTagsPerBook} 个，之后也可以单独改；不选直接继续。',
            content: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                for (final String tag in pool)
                  GestureDetector(
                    onTap: () => setLocal(() {
                      if (chosen.contains(tag)) {
                        chosen.remove(tag);
                      } else if (chosen.length < TagRepository.maxTagsPerBook) {
                        chosen.add(tag);
                      } else {
                        showSoftMessage(
                          context,
                          '最多选 ${TagRepository.maxTagsPerBook} 个标签',
                        );
                      }
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: chosen.contains(tag)
                            ? AppColors.alpha(
                                AppColors.textPrimary(brightness),
                                0.90,
                              )
                            : null,
                        border: Border.all(
                          color: AppColors.divider(brightness),
                          width: 0.9,
                        ),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: chosen.contains(tag)
                              ? AppColors.background(brightness)
                              : AppColors.textPrimary(brightness),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            actions: <Widget>[
              GlassDialogButton(
                label: '继续',
                primary: true,
                onTap: () => Navigator.of(context).pop(List<String>.of(chosen)),
              ),
            ],
          );
        },
      ),
    );
    return result ?? const <String>[];
  }

  Future<void> _startImport() async {
    final ImportPlan? plan = await _c.prepareSelected();
    if (plan == null || !mounted) {
      return;
    }

    if (!plan.hasVolumes) {
      _c.cancelImport();
      showSoftMessage(
        context,
        plan.failures.isNotEmpty ? plan.failures.first : '没有解析出任何章节内容',
      );
      return;
    }

    VolumeImportMode mode = VolumeImportMode.separate;
    Set<int> mergeSelection = const <int>{};

    if (plan.volumeCount > 1) {
      final _VolumeChoice? choice = await _askVolumeMode(plan);
      if (!mounted) {
        return;
      }
      if (choice == null) {
        _c.cancelImport();
        return;
      }
      mode = choice.mode;
      mergeSelection = choice.selection;
    }

    // 自选合并：允许调整合并进同一本书的卷顺序（文件夹里卷序常常是乱的）。
    List<int>? mergeOrder;
    if (mode == VolumeImportMode.mergeSelected && mergeSelection.length > 1) {
      mergeOrder = await _askMergeOrder(plan, mergeSelection);
      if (!mounted) {
        return;
      }
      if (mergeOrder == null) {
        _c.cancelImport();
        return;
      }
    }

    // 导入时直接给这批书选标签，省得之后一本本补。
    final List<String> pickedTags = await _askImportTags();
    if (!mounted) {
      return;
    }

    final String? group = await showTextInputDialog(
      context: context,
      title: '分组标签',
      english: 'Group',
      message: '给这次导入的书打一个分组，之后可在书架与搜索里筛选；留空表示不分组。',
      hintText: '例如：轻小说 / 2024 冬季',
      initialValue: _c.lastGroup ?? '',
      maxLength: 16,
      confirmLabel: '继续',
      allowEmpty: true,
    );
    if (!mounted) {
      return;
    }
    _c.lastGroup =
        (group == null || group.trim().isEmpty) ? null : group.trim();

    final ImportOutcome? outcome = await _c.commitPlan(
      plan,
      mode: mode,
      mergeSelection: mergeSelection,
      group: _c.lastGroup,
      mergeOrder: mergeOrder,
      tags: pickedTags,
    );
    if (!mounted || outcome == null) {
      return;
    }

    if (outcome.books.isEmpty) {
      showSoftMessage(
        context,
        outcome.failures.isNotEmpty ? outcome.failures.first : '导入失败',
      );
      return;
    }

    // 让进度卡片完整显示「导入完成 + 打勾」再返回书架。
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) {
      return;
    }
    showSoftMessage(context, '已导入 ${outcome.books.length} 本书');
    Navigator.of(context).maybePop();
  }

  Future<_VolumeChoice?> _askVolumeMode(ImportPlan plan) {
    return showGlassDialog<_VolumeChoice>(
      context: context,
      dismissible: false,
      builder: (BuildContext dialogContext) {
        return GlassDialogCard(
          title: '选择导入方式',
          english: 'Volume mode',
          message: '本次解析出 ${plan.volumeCount} 卷，请选择入库方式。',
          content: Column(
            children: <Widget>[
              _ModeTile(
                title: '分卷单独入库',
                english: 'Separate',
                description: '每一卷生成一本书，书名自动追加 | NW-XXXX',
                onTap: () => Navigator.of(dialogContext)
                    .pop(const _VolumeChoice(VolumeImportMode.separate)),
              ),
              const SizedBox(height: 8),
              _ModeTile(
                title: '全部合并为一本书',
                english: 'Merge all',
                description: '所有卷按顺序合并为一本，章节目录连续',
                onTap: () => Navigator.of(dialogContext)
                    .pop(const _VolumeChoice(VolumeImportMode.mergeAll)),
              ),
              const SizedBox(height: 8),
              _ModeTile(
                title: '选择书籍合并',
                english: 'Choose & merge',
                description: '手动勾选若干卷合并，其余仍单独入库',
                onTap: () async {
                  final Set<int>? selection = await _askMergeSelection(plan);
                  if (selection == null || !dialogContext.mounted) {
                    return;
                  }
                  Navigator.of(dialogContext).pop(
                    _VolumeChoice(VolumeImportMode.mergeSelected, selection),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Set<int>?> _askMergeSelection(ImportPlan plan) {
    final Map<int, List<ImportedVolume>> bySource =
        <int, List<ImportedVolume>>{};
    for (final ImportedVolume volume in plan.volumes) {
      bySource.putIfAbsent(volume.sourceIndex, () => <ImportedVolume>[]).add(
            volume,
          );
    }
    final List<int> sources = bySource.keys.toList()..sort();

    return showGlassDialog<Set<int>>(
      context: context,
      dismissible: false,
      builder: (BuildContext dialogContext) {
        final Set<int> selected = <int>{};
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return GlassDialogCard(
              title: '选择要合并的书籍',
              english: 'Merge selection',
              message: '至少选择 2 卷才会合并；未勾选的仍按分卷单独入库。',
              content: SizedBox(
                height: 220,
                child: ListView.separated(
                  itemCount: sources.length,
                  separatorBuilder: (BuildContext context, int index) =>
                      const SizedBox(height: 4),
                  itemBuilder: (BuildContext context, int index) {
                    final int sourceIndex = sources[index];
                    final List<ImportedVolume> volumes = bySource[sourceIndex]!;
                    final bool isSelected = selected.contains(sourceIndex);
                    return PressableScale(
                      pressedScale: 0.99,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selected.remove(sourceIndex);
                          } else {
                            selected.add(sourceIndex);
                          }
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Row(
                          children: <Widget>[
                            Icon(
                              isSelected
                                  ? Icons.check_box_rounded
                                  : Icons.check_box_outline_blank_rounded,
                              size: 18,
                              color: isSelected
                                  ? AppColors.accent(
                                      Theme.of(context).brightness)
                                  : AppColors.textTertiary(
                                      Theme.of(context).brightness),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                volumes.first.sourceLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textPrimary(
                                      Theme.of(context).brightness),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${volumes.length} 卷',
                              style: TextStyle(
                                fontSize: 9.5,
                                color: AppColors.textTertiary(
                                    Theme.of(context).brightness),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: <Widget>[
                GlassDialogButton(
                  label: '取消',
                  onTap: () => Navigator.of(dialogContext).pop(),
                ),
                GlassDialogButton(
                  label: '合并所选',
                  primary: true,
                  onTap: selected.length < 2
                      ? () {}
                      : () => Navigator.of(dialogContext).pop(
                            Set<int>.from(selected),
                          ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// 多卷策略弹窗的返回值。
class _VolumeChoice {
  const _VolumeChoice(this.mode, [this.selection = const <int>{}]);

  final VolumeImportMode mode;
  final Set<int> selection;
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.english,
    required this.description,
    required this.onTap,
  });

  final String title;
  final String english;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return PressableScale(
      pressedScale: 0.98,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.alpha(AppColors.divider(brightness), 0.9),
            width: 0.8,
          ),
          color: AppColors.alpha(AppColors.surface(brightness), 0.32),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                ),
                Text(
                  english.toUpperCase(),
                  style: AppTypography.englishLabel(brightness, fontSize: 7.8)
                      .copyWith(color: AppColors.textTertiary(brightness)),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: TextStyle(
                fontSize: 10,
                height: 1.5,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return PressableScale(
      pressedScale: 0.94,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? AppColors.alpha(AppColors.accent(brightness), 0.13)
              : Colors.transparent,
          border: Border.all(
            color: selected
                ? AppColors.alpha(AppColors.accent(brightness), 0.55)
                : AppColors.alpha(AppColors.divider(brightness), 0.9),
            width: 0.85,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppColors.accent(brightness)
                : AppColors.textSecondary(brightness),
          ),
        ),
      ),
    );
  }
}

class _SmallTextButton extends StatelessWidget {
  const _SmallTextButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return PressableScale(
      pressedScale: 0.92,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            letterSpacing: 0.5,
            color: AppColors.accent(brightness),
          ),
        ),
      ),
    );
  }
}
