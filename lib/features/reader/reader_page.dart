import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/models/book.dart';
import '../../core/models/chapter.dart';
import '../../core/models/reading_preferences.dart';
import '../../core/settings/app_settings.dart';
import '../../core/services/book_repository.dart';
import '../../core/services/chapter_repository.dart';
import '../../core/services/excerpt_repository.dart';
import '../../core/services/quote_repository.dart';
import '../../core/services/reading_preferences_repository.dart';
import '../../core/services/reading_stats_repository.dart';
import '../../core/services/user_profile_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_picker_helper.dart';
import '../../core/widgets/frosted_glass.dart';
import '../../core/widgets/glass_dialog.dart';
import '../../core/widgets/grid_background.dart';
import '../../core/widgets/liquid_glass.dart';
import '../../core/widgets/page_top_bar.dart';
import '../../core/widgets/placeholder_panel.dart';
import '../../core/widgets/pressable_scale.dart';
import '../../core/widgets/thin_divider.dart';
import 'reader_controller.dart';
import 'widgets/excerpt_picker_sheet.dart';
import 'widgets/finished_share_card.dart';
import 'widgets/quote_strip.dart';
import 'widgets/reader_background.dart';
import 'widgets/reader_settings_sheet.dart';
import 'widgets/reader_sidebar.dart';

/// 阅读页。
///
/// 设计要点：
/// * 默认「向下流式滚动」，可在阅读设置里切换成「左右分页」；
/// * 滚动过程的进度更新不触发整页重建，百分比由 [ValueNotifier] 单独驱动；
/// * 沉浸模式只隐藏侧边条与文字控件，正文与偏好全部保留；
/// * 章节定位用 [GlobalKey] + [Scrollable.ensureVisible]，不依赖固定行高估算。
class ReaderPage extends StatefulWidget {
  const ReaderPage({
    super.key,
    required this.book,
    this.chapterIndex = 0,
    this.chapterTitle,
  });

  final Book book;
  final int chapterIndex;
  final String? chapterTitle;

  @override
  State<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends State<ReaderPage> {
  static const Duration _turnDuration = Duration(milliseconds: 340);

  ReaderController? _controller;
  final ScrollController _scroll = ScrollController();
  final GlobalKey _listAreaKey = GlobalKey();
  final ValueNotifier<int> _percent = ValueNotifier<int>(0);

  /// 每章标题所在位置的 key，用于章节定位。
  final List<GlobalKey> _chapterKeys = <GlobalKey>[];

  /// 每章正文末尾的 key，用于「本章节已读完了哦！」提示。
  final List<GlobalKey> _chapterEndKeys = <GlobalKey>[];
  final Set<int> _reportedEndings = <int>{};

  PageController? _pages;
  List<_ReaderSlice> _slices = const <_ReaderSlice>[];
  String _sliceSignature = '';
  int _pageIndex = 0;

  bool _immersive = false;
  bool _loaded = false;
  bool _positionSyncQueued = false;
  String? _hint;
  Timer? _hintTimer;
  Timer? _quoteTimer;

  /// 阅读时长累加：进入阅读页开始计时，每 30 秒与退出时各结算一次。
  ReadingStatsRepository? _readingStats;
  DateTime? _sessionStart;
  Timer? _timeFlushTimer;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_handleScroll);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) {
      return;
    }
    _controller = ReaderController(
      books: context.read<BookRepository>(),
      chapterRepository: context.read<ChapterRepository>(),
      preferencesRepository: context.read<ReadingPreferencesRepository>(),
      excerptRepository: context.read<ExcerptRepository>(),
      quoteRepository: context.read<QuoteRepository>(),
      book: widget.book,
      initialChapterIndex: widget.chapterIndex,
    );
    _readingStats = context.read<ReadingStatsRepository>();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final ReaderController? controller = _controller;
    if (controller == null) {
      return;
    }
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    await controller.load(darkTheme: dark);
    if (!mounted) {
      return;
    }
    _ensureChapterKeys(controller.chapterCount);
    _percent.value = controller.progressPercent;
    setState(() => _loaded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
    _quoteTimer = Timer.periodic(const Duration(seconds: 26), (Timer timer) {
      if (!mounted || !_immersive) {
        return;
      }
      _controller?.rotateQuote();
    });
    _startReadingClock();
  }

  /// 开始累计本次阅读时长。
  void _startReadingClock() {
    _sessionStart = DateTime.now();
    _timeFlushTimer?.cancel();
    _timeFlushTimer = Timer.periodic(
      const Duration(seconds: 30),
      (Timer timer) => _flushReadingSeconds(),
    );
  }

  /// 把上次结算到现在的时间写进统计，然后重新开始计时。
  void _flushReadingSeconds() {
    final DateTime? start = _sessionStart;
    if (start == null) {
      return;
    }
    final DateTime now = DateTime.now();
    final int seconds = now.difference(start).inSeconds;
    _sessionStart = now;
    if (seconds <= 0) {
      return;
    }
    _readingStats?.addReadingSeconds(seconds);
  }

  @override
  void dispose() {
    _flushReadingSeconds();
    _timeFlushTimer?.cancel();
    _hintTimer?.cancel();
    _quoteTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _scroll.removeListener(_handleScroll);
    _scroll.dispose();
    _pages?.dispose();
    _percent.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- 数据同步

  void _ensureChapterKeys(int count) {
    while (_chapterKeys.length < count) {
      _chapterKeys.add(GlobalKey());
      _chapterEndKeys.add(GlobalKey());
    }
    while (_chapterKeys.length > count) {
      _chapterKeys.removeLast();
      _chapterEndKeys.removeLast();
    }
  }

  void _restorePosition() {
    final ReaderController? controller = _controller;
    if (controller == null) {
      return;
    }
    _percent.value = controller.progressPercent;
    if (controller.preferences.pageMode == ReaderPageMode.scroll &&
        controller.currentChapter > 0) {
      _jumpToChapter(controller.currentChapter, animate: false);
    }
  }

  void _handleScroll() {
    final ReaderController? controller = _controller;
    if (controller == null || !_scroll.hasClients) {
      return;
    }
    final ScrollPosition position = _scroll.position;
    final double max = position.maxScrollExtent;
    final double ratio =
        max <= 0 ? 1.0 : (position.pixels / max).clamp(0.0, 1.0).toDouble();
    controller.updateProgress(ratio);
    _percent.value = controller.progressPercent;

    if (_positionSyncQueued) {
      return;
    }
    _positionSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionSyncQueued = false;
      if (!mounted) {
        return;
      }
      _syncReadingPosition();
      _detectChapterEnding();
    });
  }

  RenderBox? _listRenderBox() {
    final BuildContext? context = _listAreaKey.currentContext;
    if (context == null) {
      return null;
    }
    final RenderObject? object = context.findRenderObject();
    return object is RenderBox ? object : null;
  }

  double? _chapterTop(int index, RenderBox area) {
    if (index < 0 || index >= _chapterKeys.length) {
      return null;
    }
    final BuildContext? context = _chapterKeys[index].currentContext;
    if (context == null) {
      return null;
    }
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox) {
      return null;
    }
    return object.localToGlobal(Offset.zero, ancestor: area).dy;
  }

  double? _chapterEndBottom(int index, RenderBox area) {
    if (index < 0 || index >= _chapterEndKeys.length) {
      return null;
    }
    final BuildContext? context = _chapterEndKeys[index].currentContext;
    if (context == null) {
      return null;
    }
    final RenderObject? object = context.findRenderObject();
    if (object is! RenderBox) {
      return null;
    }
    final Offset top = object.localToGlobal(Offset.zero, ancestor: area);
    return top.dy + object.size.height;
  }

  void _syncReadingPosition() {
    final ReaderController? controller = _controller;
    final RenderBox? area = _listRenderBox();
    if (controller == null || area == null) {
      return;
    }
    final double probe = area.size.height * 0.28;
    int candidate = controller.currentChapter;
    for (int i = 0; i < _chapterKeys.length; i++) {
      final double? top = _chapterTop(i, area);
      if (top == null) {
        continue;
      }
      if (top <= probe) {
        candidate = i;
      }
    }
    if (candidate != controller.currentChapter) {
      controller.setCurrentChapter(candidate);
    }
  }

  void _detectChapterEnding() {
    final ReaderController? controller = _controller;
    final RenderBox? area = _listRenderBox();
    if (controller == null || area == null) {
      return;
    }
    final double bottomLimit = area.size.height - 34;
    for (int i = 0; i < _chapterEndKeys.length; i++) {
      if (_reportedEndings.contains(i)) {
        continue;
      }
      final double? bottom = _chapterEndBottom(i, area);
      if (bottom == null) {
        continue;
      }
      if (bottom <= bottomLimit) {
        _reportedEndings.add(i);
        if (i == controller.currentChapter) {
          _showHint('本章节已读完了哦！');
        }
      }
    }
  }

  // ---------------------------------------------------------------- 章节跳转

  void _jumpToChapter(int index, {bool animate = true}) {
    final ReaderController? controller = _controller;
    if (controller == null || !_scroll.hasClients) {
      return;
    }
    final int target = index.clamp(0, math.max(0, controller.chapterCount - 1));
    final BuildContext? context = target < _chapterKeys.length
        ? _chapterKeys[target].currentContext
        : null;
    if (context != null) {
      Scrollable.ensureVisible(
        context,
        alignment: 0,
        duration: animate ? _turnDuration : Duration.zero,
        curve: Curves.easeOutCubic,
      );
      return;
    }

    final ScrollPosition position = _scroll.position;
    final double approximate = controller.chapterCount <= 1
        ? 0
        : position.maxScrollExtent * target / controller.chapterCount;
    _scroll.jumpTo(approximate.clamp(0.0, position.maxScrollExtent).toDouble());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final BuildContext? landing = target < _chapterKeys.length
          ? _chapterKeys[target].currentContext
          : null;
      if (landing != null) {
        Scrollable.ensureVisible(
          landing,
          alignment: 0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  void _goToChapter(int index) {
    final ReaderController? controller = _controller;
    if (controller == null || controller.chapterCount == 0) {
      return;
    }
    final int target = index.clamp(0, controller.chapterCount - 1);
    controller.setCurrentChapter(target);
    _percent.value = controller.progressPercent;
    if (controller.preferences.pageMode == ReaderPageMode.horizontal) {
      _syncPageToChapter(target, animate: true);
    } else {
      _jumpToChapter(target);
    }
  }

  void _stepChapter(int delta) {
    final ReaderController? controller = _controller;
    if (controller == null) {
      return;
    }
    final int target = controller.currentChapter + delta;
    if (target < 0) {
      _showHint('已经是第一章了');
      return;
    }
    if (target >= controller.chapterCount) {
      _showHint('已经是最后一章了');
      return;
    }
    _goToChapter(target);
  }

  void _syncPageToChapter(int chapterIndex, {bool animate = false}) {
    final PageController? pages = _pages;
    if (pages == null || !pages.hasClients) {
      return;
    }
    final int index = _slices.indexWhere(
      (_ReaderSlice slice) => slice.chapterIndex == chapterIndex,
    );
    if (index < 0) {
      return;
    }
    if (animate) {
      pages.animateToPage(index,
          duration: _turnDuration, curve: Curves.easeOutCubic);
    } else if (index != _pageIndex) {
      pages.jumpToPage(index);
    }
  }

  // ---------------------------------------------------------------- 交互动作

  void _handleTapUp(TapUpDetails details) {
    final ReadingPreferences? prefs = _controller?.preferences;
    if (prefs == null || !prefs.tapToTurnPage) {
      return;
    }
    final double width = MediaQuery.of(context).size.width;
    _turnPage(forward: details.localPosition.dx >= width * 0.32);
  }

  void _turnPage({required bool forward}) {
    final ReaderController? controller = _controller;
    if (controller == null) {
      return;
    }
    if (controller.preferences.pageMode == ReaderPageMode.horizontal) {
      final PageController? pages = _pages;
      if (pages == null || !pages.hasClients) {
        return;
      }
      if (forward) {
        if (_pageIndex + 1 < _slices.length) {
          pages.nextPage(duration: _turnDuration, curve: Curves.easeOutCubic);
        } else {
          _showHint('已经是最后一页了');
        }
      } else if (_pageIndex > 0) {
        pages.previousPage(duration: _turnDuration, curve: Curves.easeOutCubic);
      }
      return;
    }
    if (!_scroll.hasClients) {
      return;
    }
    final ScrollPosition position = _scroll.position;
    final double delta = position.viewportDimension * 0.82;
    final double target = (position.pixels + (forward ? delta : -delta))
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    _scroll.animateTo(target,
        duration: _turnDuration, curve: Curves.easeOutCubic);
  }

  bool _handleKeyEvent(KeyEvent event) {
    final ReadingPreferences? prefs = _controller?.preferences;
    if (prefs == null || !prefs.volumeKeyTurn || event is! KeyDownEvent) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      _turnPage(forward: false);
      return true;
    }
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      _turnPage(forward: true);
      return true;
    }
    return false;
  }

  void _toggleImmersive() {
    HapticFeedback.lightImpact();
    setState(() => _immersive = !_immersive);
  }

  void _showHint(String message) {
    _hintTimer?.cancel();
    setState(() => _hint = message);
    _hintTimer = Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) {
        return;
      }
      setState(() => _hint = null);
    });
  }

  // ---------------------------------------------------------------- 设置与弹窗

  Future<void> _openSettings() async {
    final ReaderController? controller = _controller;
    if (controller == null) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ReaderSettingsSheet(
          preferences: controller.preferences,
          backgroundId: controller.backgroundId,
          backgrounds: controller.allBackgrounds,
          onPreferencesChanged: (ReadingPreferences prefs) {
            _applyPreferences(controller, prefs);
          },
          onBackgroundSelected: (String id) {
            controller.selectBackground(id);
          },
          onImportBackground: () async {
            final String? path = await pickImagePath(prefix: 'reader_bg');
            if (path == null) {
              return null;
            }
            return controller.importBackground(path);
          },
          onRemoveBackground: (String id) async {
            await controller.removeBackground(id);
          },
        );
      },
    );
  }

  Future<void> _applyPreferences(
    ReaderController controller,
    ReadingPreferences prefs,
  ) async {
    final ReaderPageMode previous = controller.preferences.pageMode;
    await controller.applyPreferences(prefs);
    if (!mounted) {
      return;
    }
    setState(() {});
    if (previous == prefs.pageMode) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (prefs.pageMode == ReaderPageMode.horizontal) {
        _syncPageToChapter(controller.currentChapter);
      } else {
        _jumpToChapter(controller.currentChapter);
      }
    });
  }

  Future<void> _openCatalog() async {
    final ReaderController? controller = _controller;
    if (controller == null) {
      return;
    }
    final Brightness brightness = Theme.of(context).brightness;
    final int? selected = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return FrostedGlass(
          borderRadius: 26,
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.66,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      '目录',
                      style:
                          AppTypography.chineseTitle(brightness, fontSize: 17),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'CONTENTS',
                      style: AppTypography.englishLabel(brightness,
                              fontSize: 8.4)
                          .copyWith(color: AppColors.textTertiary(brightness)),
                    ),
                    const Spacer(),
                    PressableScale(
                      onTap: () => Navigator.of(context).pop(),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          Icons.close_rounded,
                          size: 17,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ThinDivider(thickness: 0.7),
                const SizedBox(height: 4),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: controller.chapterCount,
                    itemBuilder: (BuildContext context, int index) {
                      return _CatalogRow(
                        index: index,
                        title: controller.chapters[index].title,
                        selected: index == controller.currentChapter,
                        onTap: () => Navigator.of(context).pop(index),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) {
      _goToChapter(selected);
    }
  }

  Future<void> _openExcerpt() async {
    final ReaderController? controller = _controller;
    if (controller == null || controller.chapterCount == 0) {
      return;
    }
    final int index = controller.currentChapter;
    final Chapter chapter = controller.chapters[index];
    final String? text = await showExcerptPickerSheet(
      context,
      chapterTitle: chapter.title,
      paragraphs: _paragraphsOf(chapter),
    );
    if (text == null || text.trim().isEmpty) {
      return;
    }
    final bool ok = await controller.saveExcerpt(text.trim()) != null;
    if (!mounted) {
      return;
    }
    _showHint(ok ? '已加入摘抄库' : '摘抄保存失败');
  }

  Future<void> _handleLongPress() async {
    final ReadingPreferences? prefs = _controller?.preferences;
    if (prefs == null || !prefs.longPressMenu) {
      return;
    }
    await showGlassDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return GlassDialogCard(
          title: '阅读菜单',
          english: 'READING MENU',
          message: '选择要执行的操作',
          actions: <Widget>[
            GlassDialogButton(
              label: '目录',
              onTap: () {
                Navigator.of(context).pop();
                _openCatalog();
              },
            ),
            GlassDialogButton(
              label: '摘抄这一段',
              onTap: () {
                Navigator.of(context).pop();
                _openExcerpt();
              },
            ),
            GlassDialogButton(
              label: '阅读设置',
              onTap: () {
                Navigator.of(context).pop();
                _openSettings();
              },
            ),
            GlassDialogButton(
              label: _immersive ? '退出沉浸模式' : '进入沉浸模式',
              primary: true,
              onTap: () {
                Navigator.of(context).pop();
                _toggleImmersive();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _markFinished(ReaderController controller) async {
    final String userName = context.read<UserProfileController>().displayName;
    await controller.markFinished();
    if (!mounted) {
      return;
    }
    await showFinishedShareDialog(
      context,
      book: controller.book,
      userName: userName,
    );
  }

  // ---------------------------------------------------------------- 正文构建

  List<String> _paragraphsOf(Chapter chapter) {
    final List<String> lines = chapter.content.split(RegExp(r'\r?\n'));
    final List<String> paragraphs = <String>[];
    final StringBuffer buffer = StringBuffer();
    for (final String line in lines) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) {
        if (buffer.isNotEmpty) {
          paragraphs.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      if (buffer.isNotEmpty) {
        buffer.write('\n');
      }
      buffer.write(trimmed);
    }
    if (buffer.isNotEmpty) {
      paragraphs.add(buffer.toString());
    }
    if (paragraphs.isEmpty) {
      final String fallback = chapter.content.trim();
      if (fallback.isNotEmpty) {
        paragraphs.add(fallback);
      }
    }
    return paragraphs;
  }

  void _ensureSlices(ReaderController controller, Size size) {
    final ReadingPreferences prefs = controller.preferences;
    final String signature = <Object>[
      controller.chapterCount,
      controller.chapters.fold<int>(
        0,
        (int sum, Chapter chapter) => sum + chapter.content.length,
      ),
      prefs.fontSize,
      prefs.lineHeight,
      prefs.leftMargin,
      prefs.rightMargin,
      prefs.topMargin,
      prefs.bottomMargin,
      size.width.round(),
      size.height.round(),
    ].join('|');
    if (signature == _sliceSignature) {
      return;
    }
    _sliceSignature = signature;
    _slices = _paginate(controller, size);

    final PageController? previous = _pages;
    int initial = _slices.indexWhere(
      (_ReaderSlice slice) => slice.chapterIndex == controller.currentChapter,
    );
    if (initial < 0) {
      initial = 0;
    }
    _pageIndex = initial;
    _pages = PageController(initialPage: initial);
    if (previous != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => previous.dispose());
    }
  }

  List<_ReaderSlice> _paginate(ReaderController controller, Size size) {
    final ReadingPreferences prefs = controller.preferences;
    final double usableWidth = math.max(
      120.0,
      size.width - prefs.leftMargin - prefs.rightMargin,
    );
    final double usableHeight = math.max(
      80.0,
      size.height - prefs.topMargin - prefs.bottomMargin,
    );
    final int charsPerLine =
        (usableWidth / (prefs.fontSize * 1.02)).floor().clamp(8, 400);
    final int linesPerPage =
        (usableHeight / (prefs.fontSize * prefs.lineHeight))
            .floor()
            .clamp(4, 400);
    final int capacity = charsPerLine * linesPerPage;

    final List<_ReaderSlice> slices = <_ReaderSlice>[];
    for (int i = 0; i < controller.chapters.length; i++) {
      final String text = controller.chapters[i].content.trim();
      if (text.isEmpty) {
        continue;
      }
      int start = 0;
      while (start < text.length) {
        int end = math.min(text.length, start + capacity);
        if (end < text.length) {
          final int newline = text.lastIndexOf('\n', end);
          if (newline > start + capacity ~/ 2) {
            end = newline;
          }
        }
        final bool sliceEndsChapter = end >= text.length;
        slices.add(
          _ReaderSlice(
            chapterIndex: i,
            text: text.substring(start, end),
            isChapterStart: start == 0,
            isLastOfBook:
                sliceEndsChapter && i == controller.chapters.length - 1,
          ),
        );
        start = end;
      }
    }
    return slices;
  }

  Widget _buildScrollBody(ReaderController controller) {
    final ReadingPreferences prefs = controller.preferences;
    final Color textColor =
        ReaderBackgroundView.textColor(controller.backgroundId);
    final Color subColor =
        ReaderBackgroundView.secondaryTextColor(controller.backgroundId);
    return ListView.builder(
      key: _listAreaKey,
      controller: _scroll,
      padding: EdgeInsets.fromLTRB(
        prefs.leftMargin,
        prefs.topMargin,
        prefs.rightMargin,
        prefs.bottomMargin + (_immersive ? 56 : 84),
      ),
      itemCount: controller.chapters.length,
      itemBuilder: (BuildContext context, int index) {
        return _buildChapterChunk(controller, index, textColor, subColor);
      },
    );
  }

  Widget _buildChapterChunk(
    ReaderController controller,
    int index,
    Color textColor,
    Color subColor,
  ) {
    final Chapter chapter = controller.chapters[index];
    final ReadingPreferences prefs = controller.preferences;
    final List<String> paragraphs = _paragraphsOf(chapter);
    final bool isLast = index == controller.chapters.length - 1;
    final String heading =
        chapter.title.isEmpty ? '第 ${index + 1} 章' : chapter.title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(key: _chapterKeys[index], height: 1),
        Text(
          'CHAPTER ${(index + 1).toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 8.6,
            letterSpacing: 2.4,
            color: AppColors.alpha(subColor, 0.72),
          ),
        ),
        const SizedBox(height: 7),
        Text(
          heading,
          style: TextStyle(
            fontFamily: AppFonts.serif,
            fontSize: 17.5,
            height: 1.4,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: textColor,
          ),
        ),
        const SizedBox(height: 10),
        ThinDivider(
          width: 26,
          thickness: 1.1,
          color: AppColors.alpha(textColor, 0.32),
        ),
        const SizedBox(height: 18),
        for (int i = 0; i < paragraphs.length; i++) ...<Widget>[
          SelectableText(
            paragraphs[i],
            textAlign: TextAlign.justify,
            style: TextStyle(
              fontSize: prefs.fontSize,
              height: prefs.lineHeight,
              letterSpacing: 0.2,
              color: textColor,
            ),
          ),
          if (i != paragraphs.length - 1)
            SizedBox(height: prefs.paragraphSpacing),
        ],
        const SizedBox(height: 24),
        SizedBox(key: _chapterEndKeys[index], height: 1),
        if (!isLast) _buildChapterFooter(subColor),
        if (isLast) _buildFinishBlock(controller, textColor, subColor),
        if (isLast) const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildChapterFooter(Color subColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 22),
      child: Center(
        child: Text(
          '· 本章完 ·',
          style: TextStyle(
            fontSize: 10.5,
            letterSpacing: 3.4,
            color: AppColors.alpha(subColor, 0.66),
          ),
        ),
      ),
    );
  }

  Widget _buildFinishBlock(
    ReaderController controller,
    Color textColor,
    Color subColor,
  ) {
    final bool finished = controller.isFinished;
    final String lastChapter = controller.chapterTitle;
    return Padding(
      padding: const EdgeInsets.only(top: 26, bottom: 16),
      child: Column(
        children: <Widget>[
          Text(
            '· 全书完 ·',
            style: TextStyle(
              fontSize: 10.5,
              letterSpacing: 3.4,
              color: AppColors.alpha(subColor, 0.7),
            ),
          ),
          const SizedBox(height: 16),
          ThinDivider(
            width: 56,
            thickness: 0.9,
            color: AppColors.alpha(textColor, 0.24),
          ),
          const SizedBox(height: 20),
          Text(
            finished ? '这本书已经读完啦' : '故事读到这里就结束了',
            style: TextStyle(
              fontSize: 13.5,
              height: 1.6,
              letterSpacing: 0.5,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),
          LiquidGlass(
            borderRadius: 16,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
            onTap: finished ? null : () => _markFinished(controller),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  finished
                      ? Icons.check_circle_outline_rounded
                      : Icons.done_all_rounded,
                  size: 17,
                  color: finished
                      ? AppColors.alpha(textColor, 0.7)
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  finished ? '已标记为已读完' : '标记本书为已读完',
                  style: TextStyle(
                    fontSize: 12.5,
                    letterSpacing: 0.6,
                    color:
                        finished ? AppColors.alpha(textColor, 0.7) : textColor,
                  ),
                ),
              ],
            ),
          ),
          if (finished) ...<Widget>[
            const SizedBox(height: 10),
            Text(
              '读到 $lastChapter',
              style: TextStyle(
                fontSize: 9.5,
                letterSpacing: 0.8,
                color: AppColors.alpha(subColor, 0.72),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPagedBody(ReaderController controller) {
    final PageController? pages = _pages;
    if (pages == null || _slices.isEmpty) {
      return const SizedBox.shrink();
    }
    final Color textColor =
        ReaderBackgroundView.textColor(controller.backgroundId);
    final Color subColor =
        ReaderBackgroundView.secondaryTextColor(controller.backgroundId);
    return PageView.builder(
      controller: pages,
      itemCount: _slices.length,
      onPageChanged: (int index) {
        _pageIndex = index;
        final _ReaderSlice slice = _slices[index];
        controller.setCurrentChapter(slice.chapterIndex);
        final double ratio =
            _slices.length <= 1 ? 1.0 : index / (_slices.length - 1);
        controller.updateProgress(ratio);
        _percent.value = controller.progressPercent;
        if (index == _slices.length - 1) {
          _showHint('本章节已读完了哦！');
        }
      },
      itemBuilder: (BuildContext context, int index) {
        return _buildSlice(controller, _slices[index], textColor, subColor);
      },
    );
  }

  Widget _buildSlice(
    ReaderController controller,
    _ReaderSlice slice,
    Color textColor,
    Color subColor,
  ) {
    final ReadingPreferences prefs = controller.preferences;
    final Chapter chapter = controller.chapters[slice.chapterIndex];
    final String heading =
        chapter.title.isEmpty ? '第 ${slice.chapterIndex + 1} 章' : chapter.title;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        prefs.leftMargin,
        prefs.topMargin,
        prefs.rightMargin,
        prefs.bottomMargin,
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (slice.isChapterStart) ...<Widget>[
              Text(
                'CHAPTER ${(slice.chapterIndex + 1).toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontSize: 8.6,
                  letterSpacing: 2.4,
                  color: AppColors.alpha(subColor, 0.72),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                heading,
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 16.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 10),
              ThinDivider(
                width: 26,
                thickness: 1.1,
                color: AppColors.alpha(textColor, 0.32),
              ),
              const SizedBox(height: 16),
            ],
            SelectableText(
              slice.text,
              textAlign: TextAlign.justify,
              style: TextStyle(
                fontSize: prefs.fontSize,
                height: prefs.lineHeight,
                letterSpacing: 0.2,
                color: textColor,
              ),
            ),
            if (slice.isLastOfBook)
              _buildFinishBlock(controller, textColor, subColor),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- 页面骨架

  @override
  Widget build(BuildContext context) {
    final ReaderController? controller = _controller;
    if (controller == null || !_loaded) {
      return const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(strokeWidth: 1.6)),
      );
    }
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, Widget? child) {
        final AppSettingsController settings =
            context.watch<AppSettingsController>();
        if (!controller.hasChapters) {
          return _buildEmpty(controller);
        }
        _ensureChapterKeys(controller.chapterCount);
        return ReaderBackgroundView(
          backgroundId: controller.backgroundId,
          customPath: _customBackgroundPath(controller),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final Size size =
                    Size(constraints.maxWidth, constraints.maxHeight);
                final bool paged = controller.preferences.pageMode ==
                    ReaderPageMode.horizontal;
                if (paged) {
                  _ensureSlices(controller, size);
                }
                return Stack(
                  children: <Widget>[
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTapUp: _handleTapUp,
                        onDoubleTap: _toggleImmersive,
                        onLongPress: _handleLongPress,
                        child: _buildReadingSurface(controller, size),
                      ),
                    ),
                    // 阅读水印：设置页开关打开后才出现，默认关闭，保持整页干净。
                    if (settings.watermarkEnabled)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _ReaderWatermark(
                            text: settings.watermarkType.sample,
                            color: ReaderBackgroundView.textColor(
                              controller.backgroundId,
                            ),
                          ),
                        ),
                      ),
                    if (!_immersive)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        child: _buildHeader(controller),
                      ),
                    if (!_immersive)
                      Positioned(
                        right: 8,
                        top: 0,
                        bottom: 0,
                        child: Center(child: _buildSidebar(controller)),
                      ),
                    if (_immersive)
                      Positioned(
                        left: 18,
                        right: 18,
                        bottom: 12,
                        child: QuoteStrip(
                          quote: controller.quote,
                          backgroundId: controller.backgroundId,
                        ),
                      ),
                    Positioned(
                      right: 14,
                      bottom: _immersive ? 58 : 20,
                      child: _buildProgressPill(controller),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: _immersive ? 96 : 88,
                      child: Center(child: _buildHint()),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildReadingSurface(ReaderController controller, Size size) {
    final bool paged =
        controller.preferences.pageMode == ReaderPageMode.horizontal;
    final Widget content =
        paged ? _buildPagedBody(controller) : _buildScrollBody(controller);
    if (_immersive) {
      return content;
    }
    final bool dark =
        ReaderBackgroundView.isDarkBackground(controller.backgroundId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 52, 8, 8),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.alpha(dark ? Colors.black : Colors.white, 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.alpha(dark ? Colors.white : Colors.black, 0.13),
            width: 0.8,
          ),
        ),
        child: content,
      ),
    );
  }

  Widget _buildHeader(ReaderController controller) {
    final Color textColor =
        ReaderBackgroundView.textColor(controller.backgroundId);
    final Color subColor =
        ReaderBackgroundView.secondaryTextColor(controller.backgroundId);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              PressableScale(
                onTap: () => Navigator.of(context).maybePop(),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.arrow_back_rounded,
                      size: 18, color: textColor),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      controller.book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.chapterTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 9.5,
                        letterSpacing: 0.6,
                        color: AppColors.alpha(subColor, 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              PressableScale(
                onTap: _toggleImmersive,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.fullscreen_rounded,
                    size: 18,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ThinDivider(
            thickness: 0.7,
            color: AppColors.alpha(textColor, 0.16),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(ReaderController controller) {
    return ReaderSidebar(
      bookLabel: '${controller.book.title} - ${controller.book.author}',
      textColor: ReaderBackgroundView.textColor(controller.backgroundId),
      onSettings: _openSettings,
      onPrevious: () => _stepChapter(-1),
      onNext: () => _stepChapter(1),
      onExcerpt: _openExcerpt,
      onCatalog: _openCatalog,
      canPrevious: controller.currentChapter > 0,
      canNext: controller.currentChapter < controller.chapterCount - 1,
    );
  }

  Widget _buildProgressPill(ReaderController controller) {
    return ValueListenableBuilder<int>(
      valueListenable: _percent,
      builder: (BuildContext context, int value, Widget? child) {
        return LiquidGlass(
          borderRadius: 11,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          shadows: false,
          child: Text(
            '$value%',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 0.8,
              color: ReaderBackgroundView.textColor(controller.backgroundId),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHint() {
    final ReaderController? controller = _controller;
    final bool visible = _hint != null;
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
      child: visible
          ? LiquidGlass(
              borderRadius: 13,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shadows: false,
              child: Text(
                _hint!,
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 0.6,
                  color: controller == null
                      ? null
                      : ReaderBackgroundView.textColor(controller.backgroundId),
                ),
              ),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildEmpty(ReaderController controller) {
    return GridBackground(
      child: SafeArea(
        child: Column(
          children: <Widget>[
            PageTopBar(title: controller.book.title, english: 'Reader'),
            const Expanded(
              child: Center(
                child: PlaceholderPanel(
                  title: '还没有正文',
                  english: 'No chapters',
                  description: '这本书的章节内容是空的，回到详情页重新导入或检查源文件。',
                  icon: Icons.menu_book_outlined,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? _customBackgroundPath(ReaderController controller) {
    final String id = controller.backgroundId;
    for (final ReadingBackground background in controller.customBackgrounds) {
      if (background.id == id) {
        return background.path;
      }
    }
    return null;
  }
}

/// 左右分页模式中的一页。
class _ReaderSlice {
  const _ReaderSlice({
    required this.chapterIndex,
    required this.text,
    required this.isChapterStart,
    required this.isLastOfBook,
  });

  final int chapterIndex;
  final String text;
  final bool isChapterStart;
  final bool isLastOfBook;
}

/// 目录弹窗中的一行。
class _CatalogRow extends StatelessWidget {
  const _CatalogRow({
    required this.index,
    required this.title,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final String title;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Color color = selected
        ? AppColors.accent(brightness)
        : AppColors.textPrimary(brightness);
    return PressableScale(
      onTap: onTap,
      pressedScale: 0.99,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 11),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: AppColors.alpha(AppColors.divider(brightness), 0.28),
              width: 0.7,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 30,
              child: Text(
                (index + 1).toString().padLeft(2, '0'),
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontSize: 10,
                  letterSpacing: 0.6,
                  color: AppColors.textTertiary(brightness),
                ),
              ),
            ),
            Expanded(
              child: Text(
                title.isEmpty ? '第 ${index + 1} 章' : title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  letterSpacing: 0.3,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ),
            if (selected)
              Icon(
                Icons.play_arrow_rounded,
                size: 15,
                color: AppColors.accent(brightness),
              ),
          ],
        ),
      ),
    );
  }
}

/// 阅读页水印层：极低透明度、轻微倾斜，仅在设置页开启「阅读水印」后渲染。
///
/// 文案取自 [WatermarkType] 的示例文本（古诗 / 英文短句），
/// 位置平铺在正文之上但不拦截任何手势。
class _ReaderWatermark extends StatelessWidget {
  const _ReaderWatermark({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (text.isEmpty) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = (constraints.maxHeight / 150).ceil().clamp(3, 8);
        return Transform.rotate(
          angle: -0.16,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List<Widget>.generate(
              columns,
              (int index) => Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(
                  fontSize: 26,
                  letterSpacing: 6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.alpha(color, 0.055),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
