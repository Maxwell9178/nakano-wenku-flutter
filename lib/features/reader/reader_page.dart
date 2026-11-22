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
import '../../core/services/bookmark_repository.dart';
import '../../core/services/chapter_repository.dart';
import '../../core/services/excerpt_repository.dart';
import '../../core/services/quote_repository.dart';
import '../../core/services/reading_preferences_repository.dart';
import '../../core/services/reading_stats_repository.dart';
import '../../core/services/reading_time_service.dart';
import '../../core/services/user_profile_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/image_picker_helper.dart';
import '../../core/widgets/frosted_glass.dart';
import '../../core/widgets/glass_dialog.dart';
import '../../core/widgets/glass_input.dart';
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

class _ReaderPageState extends State<ReaderPage> with WidgetsBindingObserver {
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

  /// 是否由「目录 / 章节列表」明确指定章节进入：这类进入只停在章首。
  bool _explicitEntry = false;

  /// 章节名同步的最小间隔：滚动很快时不必每帧都去量 RenderBox。
  static const Duration _chapterSyncInterval = Duration(milliseconds: 120);
  DateTime _lastChapterSync = DateTime.fromMillisecondsSinceEpoch(0);

  String? _hint;
  Timer? _hintTimer;

  /// 阅读时长累加：进入阅读页开始计时，每 30 秒与退出时各结算一次。
  ReadingStatsRepository? _readingStats;
  DateTime? _sessionStart;
  Timer? _timeFlushTimer;

  /// 单本书累计阅读时长（榜单排序与详情页展示的数据源）。
  ReadingTimeService? _readingTime;
  BookmarkRepository? _bookmarks;

  /// 分页模式下淡入 / 无动画时使用的当前页序号。
  int _fadeIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scroll.addListener(_handleScroll);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startReadingClock();
      _readingTime?.start(widget.book.number);
      return;
    }
    _flushReadingSeconds();
    _readingTime?.flush();
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
    _readingTime = context.read<ReadingTimeService>();
    _bookmarks = context.read<BookmarkRepository>();
    // 从目录 / 详情页章节列表点进来的属于「明确指定章节」，
    // 这种进入方式必须停在该章开头，绝不能再按上次进度把用户拽回去。
    _explicitEntry = widget.chapterIndex > 0 ||
        (widget.chapterTitle != null && widget.chapterTitle!.trim().isNotEmpty);
    _readingTime?.start(widget.book.number);
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
    _readingTime?.flush();
    _timeFlushTimer?.cancel();
    _hintTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
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

  /// 恢复上次读到的地方。
  ///
  /// 旧实现只跳章节开头，用户续读永远要重新往下翻。现在按整本书的滚动
  /// 比例还原到**同一处文字**：首帧拿到 maxScrollExtent 后直接定位，
  /// 布局还没完成（高度为 0）时再等一帧重试。
  void _restorePosition() {
    final ReaderController? controller = _controller;
    if (controller == null) {
      return;
    }
    _percent.value = controller.progressPercent;
    // 明确指定章节进入：只停在该章开头。
    if (_explicitEntry) {
      final int chapter = widget.chapterIndex;
      if (chapter < 0 || chapter >= controller.chapterCount) {
        return;
      }
      if (controller.preferences.pageMode == ReaderPageMode.horizontal) {
        _syncPageToChapter(chapter);
      } else {
        _jumpToChapter(chapter, animate: false);
      }
      return;
    }
    final double ratio = controller.progress.clamp(0.0, 1.0).toDouble();
    if (ratio <= 0) {
      return;
    }
    if (controller.preferences.pageMode == ReaderPageMode.horizontal) {
      _syncPageToChapter(controller.currentChapter);
      return;
    }
    _restoreByProgress(ratio, attempts: 3);
  }

  /// 按「整本书进度」还原到具体文字位置。
  ///
  /// 进度现在是章节加权的，所以先还原到对应章节，再按章内比例往下偏移，
  /// 这样续读落在上次读到的同一段文字上，而不是章节开头。
  void _restoreByProgress(double progress, {required int attempts}) {
    if (!mounted) {
      return;
    }
    final ReaderController? controller = _controller;
    if (controller == null || controller.chapterCount <= 0) {
      return;
    }
    if (!_scroll.hasClients || _scroll.position.maxScrollExtent <= 0) {
      if (attempts > 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _restoreByProgress(progress, attempts: attempts - 1);
        });
      }
      return;
    }
    final int total = controller.chapterCount;
    final double scaled = progress.clamp(0.0, 1.0).toDouble() * total;
    final int index = scaled.floor().clamp(0, total - 1);
    final double intra = (scaled - index).clamp(0.0, 1.0).toDouble();
    _jumpToChapter(index, animate: false);
    if (intra <= 0.001) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) {
        return;
      }
      final RenderBox? area = _listRenderBox();
      if (area == null) {
        return;
      }
      final double? top = _chapterTop(index, area);
      if (top == null) {
        return;
      }
      final double? nextTop = index + 1 < total
          ? _chapterTop(index + 1, area)
          : _chapterEndBottom(index, area);
      final double height =
          nextTop == null ? area.size.height : math.max(1.0, nextTop - top);
      final ScrollPosition position = _scroll.position;
      final double target = (position.pixels + intra * height)
          .clamp(0.0, position.maxScrollExtent)
          .toDouble();
      _scroll.jumpTo(target);
    });
  }

  /// 滚动时更新进度。
  ///
  /// 进度直接取「滚动偏移 / 可滚动总长」：
  /// 读到最底部就是精确的 100%，不依赖章节高度的估算，
  /// 也不会出现「读完只显示 90%」。章节名同步按 ~120ms 节流，
  /// 不再每帧遍历所有章节的 RenderBox（那是卡顿的主要来源）。
  void _handleScroll() {
    final ReaderController? controller = _controller;
    if (controller == null || !_scroll.hasClients) {
      return;
    }

    final DateTime now = DateTime.now();
    if (_positionSyncQueued) {
      return;
    }
    if (now.difference(_lastChapterSync) < _chapterSyncInterval) {
      return;
    }
    _positionSyncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _positionSyncQueued = false;
      _lastChapterSync = DateTime.now();
      if (!mounted) {
        return;
      }
      _syncReadingPosition();
      _updateScrollProgress();
      _detectChapterEnding();
    });
  }

  /// 按「第几章 + 章内比例」计算整本书进度。
  ///
  /// 以前用「滚动偏移 / 可滚动总长」，各章长短差很多时会出现
  /// 「显示第 3 章、进度却已经 40%」这种对不上的情况；
  /// 改成章节加权后，进度与顶部章节名永远一致，读到最后一章末尾正好 100%。
  void _updateScrollProgress() {
    final ReaderController? controller = _controller;
    if (controller == null) {
      return;
    }
    final int total = controller.chapterCount;
    if (total <= 0) {
      return;
    }
    final RenderBox? area = _listRenderBox();
    double progress = controller.progress;
    if (area != null) {
      final int current = controller.currentChapter.clamp(0, total - 1);
      final double? top = _chapterTop(current, area);
      if (top != null) {
        final double? nextTop = current + 1 < total
            ? _chapterTop(current + 1, area)
            : _chapterEndBottom(current, area);
        final double height =
            (nextTop == null) ? area.size.height : math.max(1.0, nextTop - top);
        // 章首已经滚出视口多少（top 为负值），除以本章高度就是章内比例。
        final double intra = (-top / height).clamp(0.0, 1.0).toDouble();
        progress = (current + intra) / total;
      }
    }
    controller.updateProgress(progress.clamp(0.0, 1.0).toDouble());
    final int percent = controller.progressPercent;
    if (_percent.value != percent) {
      _percent.value = percent;
    }
  }

  /// 找出视口顶部附近的章节，只服务「顶部章节名」与章节末提示。
  void _syncReadingPosition() {
    final ReaderController? controller = _controller;
    final RenderBox? area = _listRenderBox();
    if (controller == null || area == null) {
      return;
    }
    final double probe = area.size.height * 0.28;
    final int total = controller.chapterCount;
    final int current = controller.currentChapter;

    // 只扫当前章前后各两章：滚动时开销与全书章节数无关。
    int candidate = current;
    for (int i = math.max(0, current - 2);
        i < math.min(total, current + 3);
        i++) {
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
    // 同样只看当前章与下一章，避免每帧遍历全部章节。
    final int total = controller.chapterCount;
    for (int i = controller.currentChapter;
        i < math.min(total, controller.currentChapter + 2);
        i++) {
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
    _pageIndex = index;
    _syncPagedProgress(index);
  }

  /// 分页模式下把「第几页」翻译成整本书的进度。
  ///
  /// 只在 onPageChanged 里写进度会导致「章节名已经变了、百分比还在原位」，
  /// 所以所有会改页码的入口（点击翻页、目录跳转、续读还原）都走这里。
  void _syncPagedProgress(int index) {
    final ReaderController? controller = _controller;
    if (controller == null || _slices.isEmpty) {
      return;
    }
    final _ReaderSlice slice = _slices[index];
    controller.setCurrentChapter(slice.chapterIndex);
    final double ratio =
        _slices.length <= 1 ? 1.0 : index / (_slices.length - 1);
    controller.updateProgress(ratio);
    _percent.value = controller.progressPercent;
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
      // 淡入 / 无动画 / PageView 还没挂载时都不走 PageView，直接切页序号。
      final bool usePageView =
          controller.preferences.turnAnimation == ReaderTurnAnimation.slide &&
              _pages != null &&
              _pages!.hasClients;
      if (!usePageView) {
        if (forward) {
          if (_pageIndex + 1 < _slices.length) {
            _setFadeIndex(_pageIndex + 1);
          } else {
            _showHint('已经是最后一页了');
          }
        } else if (_pageIndex > 0) {
          _setFadeIndex(_pageIndex - 1);
        } else {
          _showHint('已经是第一页了');
        }
        return;
      }
      final PageController pages = _pages!;
      if (forward) {
        if (_pageIndex + 1 < _slices.length) {
          _pageIndex += 1;
          _syncPagedProgress(_pageIndex);
          pages.nextPage(duration: _turnDuration, curve: Curves.easeOutCubic);
        } else {
          _showHint('已经是最后一页了');
        }
      } else if (_pageIndex > 0) {
        _pageIndex -= 1;
        _syncPagedProgress(_pageIndex);
        pages.previousPage(duration: _turnDuration, curve: Curves.easeOutCubic);
      } else {
        _showHint('已经是第一页了');
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

  /// 淡入 / 无动画模式下的翻页。
  void _setFadeIndex(int index) {
    if (index < 0 || index >= _slices.length) {
      return;
    }
    setState(() {
      _fadeIndex = index;
      _pageIndex = index;
    });
    _syncPagedProgress(index);
    if (index == _slices.length - 1) {
      _showHint('本章节已读完了哦！');
    }
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
              label: '添加书签',
              onTap: () {
                Navigator.of(context).pop();
                _addBookmark();
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

  /// 当前阅读位置（0..1），书签与进度共用同一套比例。
  double _currentRatio() {
    final ReaderController? controller = _controller;
    if (controller == null) {
      return 0;
    }
    if (controller.preferences.pageMode == ReaderPageMode.horizontal) {
      if (_slices.length <= 1) {
        return 0;
      }
      return (_pageIndex / (_slices.length - 1)).clamp(0.0, 1.0);
    }
    if (_scroll.hasClients) {
      final ScrollPosition position = _scroll.position;
      if (position.maxScrollExtent > 0) {
        return (position.pixels / position.maxScrollExtent).clamp(0.0, 1.0);
      }
    }
    return 0;
  }

  Future<void> _addBookmark() async {
    final ReaderController? controller = _controller;
    final BookmarkRepository? repo = _bookmarks;
    if (controller == null || repo == null) {
      return;
    }
    final String? note = await showGlassInputDialog(
      context: context,
      title: '添加书签',
      english: 'ADD BOOKMARK',
      hint: '给这一页写一句备注（可留空）',
      confirmLabel: '保存',
    );
    if (note == null) {
      return;
    }
    await repo.add(
      bookNumber: controller.book.number,
      chapterIndex: controller.currentChapter,
      chapterTitle: controller.chapterTitle,
      ratio: _currentRatio(),
      note: note,
    );
    if (!mounted) {
      return;
    }
    _showHint('书签已保存');
  }

  /// 正文段落。
  ///
  /// 这里刻意使用普通 [Text]：上一版每段都是 [SelectableText]，
  /// 每段都会建一套独立的文本编辑/手势/选择层，一章几十段时滚动直接掉帧，
  /// 长按还会弹出系统放大镜 —— 这两点都不符合需求。
  /// 现在正文只做渲染，长按菜单改由整页手势统一接管。
  Widget _buildParagraph(
    String text,
    ReadingPreferences prefs,
    Color textColor,
  ) {
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: TextStyle(
        fontSize: prefs.fontSize,
        height: prefs.lineHeight,
        letterSpacing: 0.2,
        color: textColor,
        // 显式关闭下划线：正文不需要任何装饰线，
        // 避免主题/继承样式把每行字都画上一条线。
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
        decorationStyle: TextDecorationStyle.solid,
        // 正文跟随设置里的字体来源；大标题一律走宋体，不受这里影响。
        fontFamily: context.watch<AppSettingsController>().fontFamilyOverride,
      ),
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

    int initial = _slices.indexWhere(
      (_ReaderSlice slice) => slice.chapterIndex == controller.currentChapter,
    );
    if (initial < 0) {
      initial = 0;
    }
    _pageIndex = initial;
    _fadeIndex = initial;

    // PageController 只在第一次创建；之后重排只把当前页定位回去。
    // 之前每次重排都新建并 dispose 旧的，切页瞬间会出现空白帧。
    final PageController? existing = _pages;
    if (existing == null) {
      _pages = PageController(initialPage: initial);
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !existing.hasClients) {
        return;
      }
      if (existing.page?.round() != initial) {
        existing.jumpToPage(initial);
      }
    });
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
          _buildParagraph(paragraphs[i], prefs, textColor),
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

    // 淡入 / 无动画：单页渲染 + 切换，不再使用 PageView。
    if (controller.preferences.turnAnimation != ReaderTurnAnimation.slide) {
      final int index =
          _slices.isEmpty ? 0 : _fadeIndex.clamp(0, _slices.length - 1);
      final Widget page =
          _buildSlice(controller, _slices[index], textColor, subColor);
      if (controller.preferences.turnAnimation == ReaderTurnAnimation.none) {
        return page;
      }
      return AnimatedSwitcher(
        duration: AppSettingsController.motion(240),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        child: KeyedSubtree(key: ValueKey<int>(index), child: page),
      );
    }

    return PageView.builder(
      controller: pages,
      itemCount: _slices.length,
      onPageChanged: (int index) {
        _pageIndex = index;
        _fadeIndex = index;
        _syncPagedProgress(index);
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
      // 分页模式不再套滚动视图：切页只按左右翻，页面内不允许上下滑动。
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
          _buildParagraph(slice.text, prefs, textColor),
          if (slice.isLastOfBook)
            _buildFinishBlock(controller, textColor, subColor),
        ],
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
                    // 背景压暗：阅读设置里的「背景微调」。
                    if (controller.preferences.backgroundDim > 0)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: ColoredBox(
                            color: AppColors.alpha(
                              Colors.black,
                              controller.preferences.backgroundDim / 100,
                            ),
                          ),
                        ),
                      ),
                    // 阅读水印已整体移除：阅读页只保留正文文字。
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
                        // 名言条只做展示：点击不切换名言，交给下层阅读区处理。
                        child: IgnorePointer(
                          child: QuoteStrip(
                            quote: controller.quote,
                            backgroundId: controller.backgroundId,
                          ),
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
    final Widget raw =
        paged ? _buildPagedBody(controller) : _buildScrollBody(controller);
    // 兜底：正文区域内的所有文字都不带下划线，
    // 避免任何上层样式把「每行字下面一条线」带进来。
    final Widget content = DefaultTextStyle.merge(
      style: const TextStyle(
        decoration: TextDecoration.none,
        decorationColor: Colors.transparent,
      ),
      child: raw,
    );
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
          borderRadius: BorderRadius.circular(16),
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
      onExcerpt: _openExcerpt,
      onCatalog: _openCatalog,
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
