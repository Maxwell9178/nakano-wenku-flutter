import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/models/book.dart';
import '../../../core/theme/app_colors.dart';
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
  });

  final List<Book> books;

  /// 初始居中书籍下标（上一次阅读的书籍）。
  final int initialIndex;

  /// 居中书籍变化回调，用于信息区实时同步。
  final ValueChanged<int> onCenterChanged;

  final ValueChanged<Book> onBookTap;

  final double stageHeight;

  @override
  State<BookCarousel> createState() => _BookCarouselState();
}

class _BookCarouselState extends State<BookCarousel> {
  /// 单页占视口比例：约 1/3，保证单屏同时看清中间一本 + 左右各一本。
  static const double _viewportFraction = 0.34;

  /// 书本 X 轴固定下倾角度（需求硬性规定 13°）。
  static const double _tiltXDegree = 13;

  /// 侧边书籍最大 Y 轴旋转角，转到 52° 时以书脊 + 少量封面示人。
  static const double _maxYawDegree = 52;

  late final PageController _controller;

  double _page = 0;

  @override
  void initState() {
    super.initState();
    final int initial = widget.books.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.books.length - 1).toInt();
    _page = initial.toDouble();
    _controller = PageController(
      viewportFraction: _viewportFraction,
      initialPage: initial,
    );
    _controller.addListener(_handleScroll);
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

    // 只在跨过整数本时通知外部，信息区按书籍变化淡入刷新。
    if (centerChanged) {
      final int index = next.round().clamp(0, widget.books.length - 1).toInt();
      widget.onCenterChanged(index);
    }
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
                  itemCount: widget.books.length,
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
                          (page.round() + 1).clamp(1, total).toInt();
                      return Center(
                        child: Text(
                          '<${current.toString().padLeft(4, '0')}/'
                          '${total.toString().padLeft(4, '0')}>',
                          style: TextStyle(
                            fontFamily: 'serif',
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
    final Book book = widget.books[index];
    final double page =
        _controller.hasClients ? (_controller.page ?? _page) : _page;

    // 相对居中的连续偏移量：0 = 正中，±1 = 左右相邻。
    final double offset = index - page;
    final double distance = offset.abs();

    // 距离中心 3 本开始抬升，逐本增加，正中最大 → smootherstep 平滑过渡。
    final double proximity = (1 - distance / 3).clamp(0.0, 1.0).toDouble();
    final double liftRatio = _smootherStep(proximity);

    // 转正程度：正中 1，离开约 0.8 本后为 0。
    final double turn =
        _smoothStep((1 - distance / 0.82).clamp(0.0, 1.0).toDouble());

    // Y 轴旋转角：随距离增加，侧边书籍最大 52°。
    final double yawRatio =
        _smoothStep((distance / 0.86).clamp(0.0, 1.0).toDouble());
    final double yaw = -offset.sign * _maxYawDegree * math.pi / 180 * yawRatio;

    // 透视缩放：离中心越远整体越小，强化前后层次。
    final double depthScale = 1 - 0.16 * (distance / 2).clamp(0.0, 1.0);

    // 几何尺寸：正中书籍略大；侧边书籍宽度收窄到书脊厚度。
    final double coverHeight =
        stageHeight * 0.50 * (1 + 0.12 * turn) * depthScale;
    final double baseWidth = coverHeight * 0.70;
    final double coverWidth = baseWidth * (0.34 + 0.66 * turn);

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
                        sideFade: 1 - turn,
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
