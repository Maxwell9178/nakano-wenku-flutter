import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/grid_background.dart';
import '../../../core/widgets/page_top_bar.dart';
import '../../../core/widgets/section_header.dart';

/// 纯文本说明页（安全声明 / 技术说明共用）。
///
/// 文本来自随包 assets，完全离线渲染；读取失败时给出可读的兜底提示，
/// 不弹错误弹窗。
class AssetDocumentPage extends StatefulWidget {
  const AssetDocumentPage({
    super.key,
    required this.title,
    required this.english,
    required this.assetPath,
  });

  /// 中文标题。
  final String title;

  /// 小号英文标注。
  final String english;

  /// 随包文本资源路径。
  final String assetPath;

  @override
  State<AssetDocumentPage> createState() => _AssetDocumentPageState();
}

class _AssetDocumentPageState extends State<AssetDocumentPage> {
  String? _content;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final String text = await rootBundle.loadString(widget.assetPath);
      if (!mounted) {
        return;
      }
      setState(() => _content = text.trim());
    } on Object {
      if (!mounted) {
        return;
      }
      setState(() => _error = '文档读取失败，请重新安装应用后再试。');
    }
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
              PageTopBar(title: widget.title, english: widget.english),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 44),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      SectionHeader(
                        title: widget.title,
                        english: widget.english,
                      ),
                      const SizedBox(height: 18),
                      _buildBody(context, brightness),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, Brightness brightness) {
    final String? error = _error;
    if (error != null) {
      return Text(
        error,
        style: TextStyle(
          fontSize: 13,
          height: 1.8,
          color: AppColors.textSecondary(brightness),
        ),
      );
    }

    final String? content = _content;
    if (content == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final List<String> blocks = content
        .split(RegExp(r'\n\s*\n'))
        .map((String block) => block.trim())
        .where((String block) => block.isNotEmpty)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final String block in blocks) ...<Widget>[
          _buildBlock(brightness, block),
          const SizedBox(height: 14),
        ],
      ],
    );
  }

  /// 一行且较短、以序号或冒号结尾的段落视作小标题，其余按正文渲染。
  Widget _buildBlock(Brightness brightness, String block) {
    final bool singleLine = !block.contains('\n');
    final bool looksLikeHeading = singleLine &&
        block.length <= 24 &&
        RegExp(r'^[一二三四五六七八九十]+、').hasMatch(block);

    if (looksLikeHeading) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          block,
          style: AppTypography.chineseTitle(brightness, fontSize: 16)
              .copyWith(letterSpacing: 0.6),
        ),
      );
    }

    return Text(
      block,
      textAlign: TextAlign.justify,
      style: TextStyle(
        fontSize: 13,
        height: 1.9,
        letterSpacing: 0.2,
        color: AppColors.textSecondary(brightness),
      ),
    );
  }
}
