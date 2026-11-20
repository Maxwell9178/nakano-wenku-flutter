import 'package:flutter/material.dart';

import '../../../core/services/reading_stats_repository.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/grid_background.dart';
import '../../../core/widgets/liquid_glass.dart';
import '../../../core/widgets/page_top_bar.dart';
import '../../../core/widgets/pressable_scale.dart';
import '../../../core/widgets/thin_divider.dart';

/// 阅读打卡日历。
///
/// 表格为「三层带间隔方格」：
/// 1. 外层毛玻璃卡片描边；
/// 2. 网格之间留出统一间隔（使每格独立，不黏成一片）；
/// 3. 每个日期格再套一层细线描边，下方标注 MM.DD。
/// 当天有阅读记录（≥ [ReadingStatsRepository.checkInThresholdSeconds]）即实心填充。
class CheckInPage extends StatefulWidget {
  const CheckInPage({super.key, required this.stats});

  final ReadingStatsRepository stats;

  @override
  State<CheckInPage> createState() => _CheckInPageState();
}

class _CheckInPageState extends State<CheckInPage> {
  late DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  static const List<String> _weekLabels = <String>[
    '一',
    '二',
    '三',
    '四',
    '五',
    '六',
    '日',
  ];

  bool get _canGoNext {
    final DateTime now = DateTime.now();
    return _month.year < now.year ||
        (_month.year == now.year && _month.month < now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Brightness brightness = Theme.of(context).brightness;
    final Set<int> checkedDays = widget.stats.checkedInDayNumbersOfMonth(_month);
    final int monthDays = widget.stats.checkInDaysInMonth(_month);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GridBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            children: <Widget>[
              const PageTopBar(
                title: '阅读打卡',
                english: 'CHECK-IN CALENDAR',
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  children: <Widget>[
                    _buildSummary(brightness, monthDays),
                    const SizedBox(height: 18),
                    _buildMonthSwitcher(brightness),
                    const SizedBox(height: 14),
                    _buildCalendar(brightness, checkedDays),
                    const SizedBox(height: 16),
                    _buildLegend(brightness),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------- 顶部统计 ----------------

  Widget _buildSummary(Brightness brightness, int monthDays) {
    final int total = widget.stats.totalCheckInDays;
    final int streak = widget.stats.currentStreakDays;

    return LiquidGlass(
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _SummaryBlock(
              label: '本月阅读',
              value: '$monthDays',
              unit: '天',
              brightness: brightness,
              highlight: true,
            ),
          ),
          Container(
            width: 0.8,
            height: 34,
            color: AppColors.divider(brightness),
          ),
          Expanded(
            child: _SummaryBlock(
              label: '累计阅读',
              value: '$total',
              unit: '天',
              brightness: brightness,
            ),
          ),
          Container(
            width: 0.8,
            height: 34,
            color: AppColors.divider(brightness),
          ),
          Expanded(
            child: _SummaryBlock(
              label: '连续打卡',
              value: '$streak',
              unit: '天',
              brightness: brightness,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------- 月份切换 ----------------

  Widget _buildMonthSwitcher(Brightness brightness) {
    final Color accent = AppColors.accent(brightness);

    return Row(
      children: <Widget>[
        _MonthArrow(
          icon: Icons.chevron_left_rounded,
          onTap: () => _shiftMonth(-1),
          enabled: true,
          brightness: brightness,
        ),
        Expanded(
          child: Column(
            children: <Widget>[
              Text(
                '${_month.year}.${_month.month.toString().padLeft(2, '0')}',
                style: TextStyle(
                  fontFamily: AppFonts.serif,
                  fontFamilyFallback: AppFonts.serifFallback,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              const SizedBox(height: 6),
              ThinDivider(
                width: 34,
                gradient: LinearGradient(
                  colors: <Color>[
                    AppColors.alpha(accent, 0.8),
                    AppColors.alpha(accent, 0.12),
                  ],
                ),
              ),
            ],
          ),
        ),
        _MonthArrow(
          icon: Icons.chevron_right_rounded,
          onTap: _canGoNext ? () => _shiftMonth(1) : null,
          enabled: _canGoNext,
          brightness: brightness,
        ),
      ],
    );
  }

  // ---------------- 日历表格 ----------------

  Widget _buildCalendar(Brightness brightness, Set<int> checkedDays) {
    final int daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    // DateTime.weekday：周一 = 1，恰好与「一…日」表头一致。
    final int leading = DateTime(_month.year, _month.month, 1).weekday - 1;
    final int cellCount = leading + daysInMonth;
    final int rows = (cellCount / 7).ceil();

    return LiquidGlass(
      borderRadius: 22,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        children: <Widget>[
          Row(
            children: _weekLabels
                .map(
                  (String label) => Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 1.2,
                          color: AppColors.textTertiary(brightness),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          for (int row = 0; row < rows; row++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List<Widget>.generate(7, (int column) {
                  final int index = row * 7 + column;
                  final int dayNumber = index - leading + 1;
                  final bool inMonth =
                      index >= leading && dayNumber <= daysInMonth;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: inMonth
                          ? _DayCell(
                              day: dayNumber,
                              month: _month.month,
                              checked: checkedDays.contains(dayNumber),
                              brightness: brightness,
                            )
                          : const SizedBox(height: 62),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLegend(Brightness brightness) {
    return Row(
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            color: AppColors.alpha(AppColors.accent(brightness), 0.55),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          '当天有阅读记录',
          style: TextStyle(
            fontSize: 10,
            color: AppColors.textTertiary(brightness),
          ),
        ),
        const Spacer(),
        Text(
          '满 60 秒记一次打卡',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 0.3,
            color: AppColors.textTertiary(brightness),
          ),
        ),
      ],
    );
  }
}

/// 单个日期格：上方方格 + 下方 MM.DD。
class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.month,
    required this.checked,
    required this.brightness,
  });

  final int day;
  final int month;
  final bool checked;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final Color accent = AppColors.accent(brightness);
    final Color borderColor = checked
        ? AppColors.alpha(accent, 0.55)
        : AppColors.alpha(AppColors.divider(brightness), 0.8);

    return Column(
      children: <Widget>[
        AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 0.8),
            color: checked
                ? AppColors.alpha(accent, 0.30)
                : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: TextStyle(
              fontFamily: AppFonts.serif,
              fontFamilyFallback: AppFonts.serifFallback,
              fontSize: 12,
              fontWeight: checked ? FontWeight.w700 : FontWeight.w400,
              color: checked
                  ? AppColors.textPrimary(brightness)
                  : AppColors.textSecondary(brightness),
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          '${month.toString().padLeft(2, '0')}.${day.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 8,
            letterSpacing: 0.1,
            color: checked
                ? AppColors.alpha(accent, 0.9)
                : AppColors.textTertiary(brightness),
          ),
        ),
      ],
    );
  }
}

class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({
    required this.label,
    required this.value,
    required this.unit,
    required this.brightness,
    this.highlight = false,
  });

  final String label;
  final String value;
  final String unit;
  final Brightness brightness;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final Color accent = AppColors.accent(brightness);

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
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: <Widget>[
            Text(
              value,
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontFamilyFallback: AppFonts.serifFallback,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: highlight ? accent : AppColors.textPrimary(brightness),
              ),
            ),
            const SizedBox(width: 3),
            Text(
              unit,
              style: TextStyle(
                fontSize: 9.5,
                color: AppColors.textTertiary(brightness),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MonthArrow extends StatelessWidget {
  const _MonthArrow({
    required this.icon,
    required this.onTap,
    required this.enabled,
    required this.brightness,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      enabled: enabled,
      onTap: onTap,
      pressedScale: 0.92,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.alpha(
              AppColors.divider(brightness),
              enabled ? 1 : 0.45,
            ),
            width: 0.8,
          ),
        ),
        child: Icon(
          icon,
          size: 19,
          color: enabled
              ? AppColors.textSecondary(brightness)
              : AppColors.textTertiary(brightness),
        ),
      ),
    );
  }
}
