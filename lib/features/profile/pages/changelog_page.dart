import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/grid_background.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/page_top_bar.dart';
import '../../../core/widgets/section_header.dart';
import '../../../core/widgets/thin_divider.dart';

/// 更新日志页。
///
/// 日志随包内置（`assets/data/changelog.txt`），离线也能翻看每一版改了什么；
/// 格式是按 `## 版本号` 分段，段内每一行是一条改动。
class ChangelogPage extends StatefulWidget {
  const ChangelogPage({super.key});

  @override
  State<ChangelogPage> createState() => _ChangelogPageState();
}

class _ChangelogPageState extends State<ChangelogPage> {
  List<_ChangelogSection> _sections = const <_ChangelogSection>[];
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final String raw =
          await rootBundle.loadString('assets/data/changelog.txt');
      final List<_ChangelogSection> parsed = _parse(raw);
      if (!mounted) {
        return;
      }
      setState(() {
        _sections = parsed;
        _loading = false;
        _failed = parsed.isEmpty;
      });
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  List<_ChangelogSection> _parse(String raw) {
    final List<_ChangelogSection> result = <_ChangelogSection>[];
    String? current;
    final List<String> lines = <String>[];

    void flush() {
      if (current == null) {
        return;
      }
      result.add(
        _ChangelogSection(version: current, items: List<String>.of(lines)),
      );
      lines.clear();
    }

    for (final String line in const LineSplitter().convert(raw)) {
      final String trimmed = line.trim();
      if (trimmed.startsWith('## ')) {
        flush();
        current = trimmed.substring(3).trim();
        continue;
      }
      if (trimmed.isEmpty) {
        continue;
      }
      if (current == null) {
        continue;
      }
      lines.add(trimmed.startsWith('- ') ? trimmed.substring(2) : trimmed);
    }
    flush();
    return result;
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
              const PageTopBar(title: '更新日志', english: 'CHANGELOG'),
              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 1.6),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
                        children: <Widget>[
                          if (_failed)
                            _buildEmpty(brightness)
                          else
                            ..._sections.map(
                              (_ChangelogSection section) =>
                                  _buildSection(brightness, section),
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

  Widget _buildSection(Brightness brightness, _ChangelogSection section) {
    final bool isCurrent = section.version == AppConstants.versionName;
    final Color accent = AppColors.accent(brightness);

    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SectionHeader(
            title: 'v${section.version}',
            english: isCurrent ? 'CURRENT' : 'RELEASE',
            alignment: CrossAxisAlignment.start,
            trailing: isCurrent
                ? Text(
                    '当前版本',
                    style: TextStyle(
                      fontSize: 9.5,
                      letterSpacing: 1.0,
                      color: accent,
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          LiquidGlass(
            borderRadius: 20,
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (int i = 0; i < section.items.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: i == section.items.length - 1 ? 0 : 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: SizedBox(
                            width: 5,
                            height: 5,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.alpha(
                                    AppColors.textSecondary(brightness), 0.55),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            section.items[i],
                            style: TextStyle(
                              fontSize: 12.8,
                              height: 1.75,
                              color: AppColors.textPrimary(brightness),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(Brightness brightness) {
    return LiquidGlass(
      borderRadius: 20,
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
      child: Column(
        children: <Widget>[
          Icon(
            Icons.history_rounded,
            size: 26,
            color: AppColors.textTertiary(brightness),
          ),
          const SizedBox(height: 12),
          Text(
            '暂时没有更新日志',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const SizedBox(height: 6),
          ThinDivider(width: 40, thickness: 0.8),
          const SizedBox(height: 6),
          Text(
            'CHANGELOG UNAVAILABLE',
            style: TextStyle(
              fontSize: 8.4,
              letterSpacing: 2.0,
              color: AppColors.textTertiary(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChangelogSection {
  const _ChangelogSection({required this.version, required this.items});

  final String version;
  final List<String> items;
}
