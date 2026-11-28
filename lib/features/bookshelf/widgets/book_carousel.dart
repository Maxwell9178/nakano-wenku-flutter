import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/book.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/pressable_scale.dart';
import 'book_cover_art.dart';

/// 上半区 3D 立体横向轮播书架。
///
/// 视觉参数（对应需求文档）：
/// * 多本书记极小间隔横排，书本绕 X 轴固定下倾 13°；
/// * 侧边书籍通过 Y 轴旋转（最大 60°）+ 宽度收窄，只保留黑色书脊；
/// * 居中书籍正面朝向读者（X 轴倾斜不变，Y 轴转正），并向斜上方 45°
///   方向移动，抬升高度为自身书高的 60%；
/// * 抬升采用 smootherstep 平滑插值：距中心提前 3 本开始小幅抬起，
///   2 本增加，1 本继续，正中最大，全程无跳变；
/// * 滑动惯性沿用 PageView 的 PageScrollPhysics（快滑续滚、慢滑停稳）。
class BookCarousel extends StatefulWidget {
  const BookCarousel({
    super.key,
    required this.books,
    required this.initialIndex,
    required this.onCenterChanged,
    required this.onBookTap,
    this.stageHeight = 320,
    this.onFractionChanged,
  });

  final List<Book> books;

  /// 初始居中书籍下标（上一次阅读的书籍）。
  final int initialIndex;

  /// 居中书籍变化回调，用于信息区实时同步。
  final ValueChanged<int> onCenterChanged;

  final ValueChanged<Book> onBookTap;

  final double stageHeight;

  /// 一轮书架的滑动位置（0 = 第一本，1 = 最后之后），
  /// 用于同步底部的滑动条。
  final ValueChanged<double>? onFractionChanged;

  @override
  State<BookCarousel> createState() => BookCarouselState();
}

/// 书架轮播的状态，暴露 [seekToFraction] 供底部滑动条驱动。
class BookCarouselState extends State<BookCarousel> {
  /// 单页占视口比例：单屏同时看清中间一本 + 左右各一本。
  static const double _viewportFraction = 0.26;

  /// 书本 X 轴固定下倾角度（需求硬性规定 13°）。
  static const double _tiltXDegree = 13;

  /// 侧边书籍最大 Y 轴旋转角。
  ///
  /// 之前 52° 时两侧几乎转成一条线，只剩一条窄书脊；收到 38° 后
  /// 左右两本仍然能看清封面主体，三本一起构成一个环。
  static const double _maxYawDegree = 38;

  late final PageController _controller;

  double _page = 0;

  /// 无限循环用的偏移量：初始页放在很靠后的位置，两侧都能一直滑。
  static const int _loopBase = 2000;

  int get _count => widget.books.length;

  /// 书太少时不做循环：否则一本/两本会被重复画成三本。
  bool get _loopEnabled => _count > 2;

  int _bookIndexOf(int rawIndex) {
    if (_count <= 0) {
      return 0;
    }
    return ((rawIndex % _count) + _count) % _count;
  }

  @override
  void initState() {
    super.initState();
    final int initial = widget.books.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.books.length - 1).toInt();
    final int start = _loopEnabled ? initial + _count * _loopBase : initial;
    _page = start.toDouble();
    _controller = PageController(
      viewportFraction: _viewportFraction,
      initialPage: start,
    );
    _controller.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant BookCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 书籍数量变化（导入 / 删除）后重新落到循环中段的合法位置，
    // 避免取模后落到缺书的下标上。
    if (oldWidget.books.length != widget.books.length &&
        _count > 0 &&
        _controller.hasClients) {
      final int target = _loopEnabled
          ? widget.initialIndex.clamp(0, _count - 1).toInt() +
              _count * _loopBase
          : widget.initialIndex.clamp(0, _count - 1).toInt();
      _page = target.toDouble();
      _controller.jumpToPage(target);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) {
      return;
    }
    final double next = _controller.page ?? _page;
    if ((next - _page).abs() < 0.0001) {
      return;
    }

    final bool centerChanged = next.round() != _page.round();
    // 平滑滚动中的几何变化由 items 内的 AnimatedBuilder 直接读取
    // controller.page 计算，这里不触发整页重建，避免每帧抖动。
    _page = next;

    // 滑动条跟随：连续汇报一轮内的位置（0~1）。
    widget.onFractionChanged?.call(_fractionOf(next));

    // 只在跨过整数本时通知外部，信息区按书籍变化淡入刷新。
    if (centerChanged) {
      widget.onCenterChanged(_bookIndexOf(next.round()));
    }
  }

  /// 当前页在一轮书架里的位置（0~1）。
  double _fractionOf(double page) {
    if (_count <= 0) {
      return 0;
    }
    final double wrapped = ((page % _count) + _count) % _count;
    return (wrapped / _count).clamp(0.0, 1.0).toDouble();
  }

  /// 外部（底部滑动条）驱动书架：直接定位到一轮内的指定位置。
  ///
  /// 不带动画地跟手，滑到头由调用方决定是否回卷到开头。
  void seekToFraction(double fraction) {
    if (_count <= 0 || !_controller.hasClients) {
      return;
    }
    final double clamped = fraction.clamp(0.0, 1.0).toDouble();
    final double current = _controller.page ?? _page;
    // 保持在当前这一轮里移动，避免跨轮跳动造成视觉跳变。
    final double cycleStart = current - ((current % _count) + _count) % _count;
    final double target = cycleStart + clamped * _count;
    // 这里用像素直接定位（而不是 jumpToPage(int)）：
    // PageView 会停在两本书之间，3D 几何按小数页连续插值，
    // 拖动滑动条时书是「转过去」的，而不是封面一张张硬切。
    // 不预先改 _page，交给 _handleScroll 统一更新，
    // 否则信息区收不到 onCenterChanged，书名会停在滑动前的那本。
    final double viewport = _controller.position.viewportDimension;
    if (viewport <= 0) {
      return;
    }
    _controller.position.jumpTo(target * viewport);
    widget.onFractionChanged?.call(clamped);
  }

  /// 滑到头后回到「第一本」：整体前移一轮，视觉上是同一本书，
  /// 但滑动条重新从最左边开始。
  void wrapToStart() {
    if (_count <= 0 || !_controller.hasClients) {
      return;
    }
    final double current = _controller.page ?? _page;
    final double wrapped = ((current % _count) + _count) % _count;
    final double target = current - wrapped + _count;
    _page = target;
    _controller.jumpToPage(target.round());
    widget.onFractionChanged?.call(0);
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;

    return SizedBox(
      height: widget.stageHeight,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final double stageWidth = constraints.maxWidth;
          final double stageHeight = constraints.maxHeight;

          return Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              // 书架上的一条极淡托底光带，让悬浮书本有落点。
              Positioned(
                left: stageWidth * 0.08,
                right: stageWidth * 0.08,
                bottom: stageHeight * 0.02,
                child: Container(
                  height: 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: <Color>[
                        AppColors.alpha(
                          brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF6E6E6E),
                          0,
                        ),
                        AppColors.alpha(
                          brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF6E6E6E),
                          0.07,
                        ),
                        AppColors.alpha(
                          brightness == Brightness.dark
                              ? Colors.white
                              : const Color(0xFF6E6E6E),
                          0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 书本层：PageView 负责手势与惯性，几何变换在每帧内计算。
              Positioned.fill(
                child: PageView.builder(
                  controller: _controller,
                  // itemCount 传 null = 无限循环；书太少时退回有限列表。
                  itemCount: _loopEnabled ? null : _count,
                  itemBuilder: (BuildContext context, int index) {
                    return AnimatedBuilder(
                      animation: _controller,
                      builder: (BuildContext context, Widget? child) {
                        return _buildBook(
                          index: index,
                          stageHeight: stageHeight,
                        );
                      },
                    );
                  },
                ),
              ),

              // 底部页码：<0001/0020>，随滑动实时更新。
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (BuildContext context, Widget? child) {
                      final int total = widget.books.length;
                      final double page = _controller.hasClients
                          ? (_controller.page ?? _page)
                          : _page;
                      final int current =
                          total == 0 ? 1 : _bookIndexOf(page.round()) + 1;
                      return Center(
                        child: Text(
                          '<${current.toString().padLeft(4, '0')}/'
                          '${total.toString().padLeft(4, '0')}>',
                          style: TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize: 9.5,
                            letterSpacing: 1.8,
                            color: AppColors.textTertiary(brightness),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBook({
    required int index,
    required double stageHeight,
  }) {
    final Book book = widget.books[_bookIndexOf(index)];
    final double page =
        _controller.hasClients ? (_controller.page ?? _page) : _page;

    // 相对居中的连续偏移量：0 = 正中，±1 = 左右相邻。
    final double offset = index - page;
    final double distance = offset.abs();

    // 距离中心 3 本开始抬升，逐本增加，正中最大 → smootherstep 平滑过渡。
    final double proximity = (1 - distance / 3).clamp(0.0, 1.0).toDouble();
    final double liftRatio = _smootherStep(proximity);

    // 转正程度：正中 1，离开约 1.2 本后才完全转侧。
    // 窗口从 0.82 放宽到 1.2，左右相邻的封面不会被压成一条线。
    final double turn =
        _smoothStep((1 - distance / 1.2).clamp(0.0, 1.0).toDouble());

    // Y 轴旋转角：随距离增加，侧边书籍最大 38°。
    final double yawRatio =
        _smoothStep((distance / 0.86).clamp(0.0, 1.0).toDouble());
    final double yaw = -offset.sign * _maxYawDegree * math.pi / 180 * yawRatio;

    // 透视缩放：离中心越远整体略小，强化前后层次（幅度收窄，避免缩太小）。
    final double depthScale = 1 - 0.12 * (distance / 2).clamp(0.0, 1.0);

    // 几何尺寸：正中最大，侧边只轻微收窄，保证三本都能看到封面。
    final double coverHeight =
        stageHeight * 0.46 * (1 + 0.10 * turn) * depthScale;
    final double baseWidth = coverHeight * 0.70;
    final double coverWidth = baseWidth * (0.70 + 0.30 * turn);

    // 抬升高度 = 书高的 60%，并在斜上方 45° 方向偏移。
    final double lift = coverHeight * 0.60 * liftRatio;
    final double diagonal = lift * 0.707 * turn * -1;

    final Matrix4 transform = Matrix4.identity()
      ..setEntry(3, 2, 0.0015)
      ..rotateX(_tiltXDegree * math.pi / 180)
      ..rotateY(yaw)
      ..translate(diagonal, -lift, 0);

    // 超出可视范围的书本淡出，避免边缘突然出现 / 消失。
    final double fadeOut = distance <= 3.0
        ? 1.0
        : (1 - (distance - 3.0) / 1.2).clamp(0.0, 1.0).toDouble();

    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        width: baseWidth,
        height: stageHeight,
        child: Stack(
          alignment: Alignment.bottomCenter,
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: (baseWidth - coverWidth) / 2,
              bottom: stageHeight * 0.085,
              width: coverWidth,
              height: coverHeight,
              child: Opacity(
                opacity: fadeOut,
                child: Transform(
                  alignment: Alignment.bottomCenter,
                  transform: transform,
                  child: PressableScale(
                    pressedScale: 0.97,
                    onTap: () => widget.onBookTap(book),
                    child: RepaintBoundary(
                      child: BookCoverArt(
                        book: book,
                        width: coverWidth,
                        height: coverHeight,
                        // 侧边只做轻微压暗（原来 1.0 会把封面压成纯黑书脊，
                        // 看起来就是「只剩一条窄书脊」）。
                        sideFade: (1 - turn) * 0.30,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 三阶平滑：两端一阶、二阶导数为 0，过渡不会出现生硬折角。
  static double _smootherStep(double t) {
    final double x = t.clamp(0.0, 1.0).toDouble();
    return x * x * x * (x * (x * 6 - 15) + 10);
  }

  static double _smoothStep(double t) {
    final double x = t.clamp(0.0, 1.0).toDouble();
    return x * x * (3 - 2 * x);
  }
}
