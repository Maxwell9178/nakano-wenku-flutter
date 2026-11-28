import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/services/chapter_repository.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/grid_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/thin_divider.dart';
import '../../core/platform/platform_image.dart';

/// 漫画阅读页。
///
/// 与文字书阅读器完全独立：章节正文里存的是图片绝对路径，
/// 这里只负责按页渲染，不涉及字号 / 行距 / 名言等文字排版能力。
/// * 上下翻页：竖向 `PageView`；
/// * 双页模式：两页并排显示（适合平板或横屏）；
/// * 缩放：`InteractiveViewer` 双指放大。
class ComicPage extends StatefulWidget {
  const ComicPage({super.key, required this.book, this.initialPage = 0});

  final Book book;
  final int initialPage;

  @override
  State<ComicPage> createState() => _ComicPageState();
}

class _ComicPageState extends State<ComicPage> {
  List<String> _pages = const <String>[];
  bool _loading = true;
  bool _doublePage = false;
  bool _immersive = false;
  int _index = 0;
  PageController? _controller;

  @override
  void initState() {
    super.initState();
    _index = widget.initialPage;
    _load();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final ChapterRepository repo = context.read<ChapterRepository>();
    List<String> pages = const <String>[];
    try {
      final List<Chapter> chapters = await repo.load(widget.book.number);
      pages = chapters.map((Chapter item) => item.content).toList();
    } catch (_) {
      pages = const <String>[];
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _pages = pages;
      _loading = false;
      _controller = PageController(
        initialPage: _clampIndex(_index, pages.length, _doublePage),
      );
    });
  }

  int _clampIndex(int index, int length, bool doublePage) {
    if (length <= 0) {
      return 0;
    }
    final int maxIndex = doublePage ? ((length + 1) ~/ 2) - 1 : length - 1;
    if (index < 0) {
      return 0;
    }
    return index > maxIndex ? maxIndex : index;
  }

  void _toggleDoublePage() {
    final int page = doublePageStep(_index, _doublePage);
    setState(() {
      _doublePage = !_doublePage;
      _index = _clampIndex(page, _pages.length, _doublePage);
      _controller?.dispose();
      _controller = PageController(initialPage: _index);
    });
  }

  /// 单页 / 双页切换时保持「当前页」大致不变。
  int doublePageStep(int index, bool currentDouble) {
    if (!currentDouble) {
      return index ~/ 2;
    }
    return index * 2;
  }

  void _jumpTo(int index) {
    final int target = _clampIndex(index, _pages.length, _doublePage);
    setState(() => _index = target);
    _controller?.jumpToPage(target);
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = AppColors.textPrimary(Theme.of(context).brightness);

    if (_loading) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
      );
    }

    if (_pages.isEmpty) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : AppColors.lightBackground,
        appBar: AppBar(title: Text(widget.book.title)),
        body: const Center(child: Text('这本漫画还没有页面')),
      );
    }

    final int step = _doublePage ? 2 : 1;
    final int total = _doublePage ? (_pages.length + 1) ~/ 2 : _pages.length;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : AppColors.lightBackground,
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              itemCount: total,
              onPageChanged: (int index) => setState(() => _index = index),
              itemBuilder: (BuildContext context, int index) {
                if (!_doublePage) {
                  return _buildImage(_pages[index]);
                }
                final int left = index * 2;
                final int right = left + 1;
                return Row(
                  children: <Widget>[
                    Expanded(child: _buildImage(_pages[left])),
                    if (right < _pages.length)
                      Expanded(child: _buildImage(_pages[right]))
                    else
                      const Spacer(),
                  ],
                );
              },
            ),
          ),
          if (!_immersive) ...<Widget>[
            Positioned(
              left: 12,
              right: 12,
              top: MediaQuery.of(context).padding.top + 6,
              child: LiquidGlass(
                borderRadius: 16,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  children: <Widget>[
                    PressableScale(
                      pressedScale: 0.92,
                      onTap: () => Navigator.of(context).maybePop(),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: AppFonts.serif,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '第 ${(_index * step + 1).toString().padLeft(3, '0')}'
                            ' / ${_pages.length.toString().padLeft(3, '0')} 页',
                            style: TextStyle(
                              fontSize: 9.5,
                              letterSpacing: 0.6,
                              color: AppColors.alpha(textColor, 0.66),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _ModeChip(
                      label: _doublePage ? '双页' : '单页',
                      onTap: _toggleDoublePage,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ),
          ],
          Positioned(
            right: 12,
            bottom: MediaQuery.of(context).padding.bottom + 14,
            child: Column(
              children: <Widget>[
                _RoundButton(
                  icon: Icons.arrow_upward_rounded,
                  tooltip: '上一页',
                  onTap: () {
                    if (_index > 0) {
                      _jumpTo(_index - 1);
                    }
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _RoundButton(
                  icon: Icons.arrow_downward_rounded,
                  tooltip: '下一页',
                  onTap: () {
                    if (_index < total - 1) {
                      _jumpTo(_index + 1);
                    }
                  },
                  isDark: isDark,
                ),
                const SizedBox(height: 8),
                _RoundButton(
                  icon: _immersive
                      ? Icons.fullscreen_exit_rounded
                      : Icons.fullscreen_rounded,
                  tooltip: '沉浸模式',
                  onTap: () => setState(() => _immersive = !_immersive),
                  isDark: isDark,
                ),
              ],
            ),
          ),
          if (!_immersive)
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              child: IgnorePointer(
                child: Column(
                  children: <Widget>[
                    ThinDivider(
                      width: 60,
                      thickness: 0.7,
                      color: AppColors.alpha(textColor, 0.18),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '上下滑动翻页 · 双指缩放',
                      style: TextStyle(
                        fontSize: 9,
                        letterSpacing: 1.2,
                        color: AppColors.alpha(textColor, 0.45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildImage(String path) {
    return InteractiveViewer(
      minScale: 1,
      maxScale: 4,
      child: Container(
        color: Colors.black,
        alignment: Alignment.center,
        child: PlatformImage(
          path: path,
          fit: BoxFit.contain,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stack) {
            return GridBackground(
              child: Center(
                child: Text(
                  '这一页图片丢失了',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.alpha(Colors.white, 0.7),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color textColor = AppColors.textPrimary(Theme.of(context).brightness);
    final Color accent = AppColors.accent(Theme.of(context).brightness);
    return PressableScale(
      pressedScale: 0.94,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.alpha(accent, 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: AppColors.alpha(
                  AppColors.textSecondary(Theme.of(context).brightness), 0.55),
              width: 0.8),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 10.5, color: textColor),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        pressedScale: 0.9,
        onTap: onTap,
        child: LiquidGlass(
          borderRadius: 999,
          padding: const EdgeInsets.all(9),
          child: Icon(
            icon,
            size: 18,
            color: AppColors.textPrimary(Theme.of(context).brightness),
          ),
        ),
      ),
    );
  }
}
