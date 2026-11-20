import 'dart:convert';

import '../constants/storage_keys.dart';
import 'local_storage_service.dart';

/// 阅读时长与打卡记录的本地仓库。
///
/// 设计说明：
/// * 阅读页每次退出（或每 30 秒）把这段时间累加进来，最终得到
///   「累计阅读时长」；
/// * 每日阅读超过 [checkInThresholdSeconds] 秒即视为当天打卡成功，
///   打卡日历与「当月 / 累计阅读天数」都由这张每日表推算，
///   不额外存一份打卡表，避免两处数据不一致。
class ReadingStatsRepository {
  ReadingStatsRepository(this._storage);

  final LocalStorageService _storage;

  /// 当天阅读满 60 秒算一次打卡，避免误触进入阅读页就记一天。
  static const int checkInThresholdSeconds = 60;

  Map<String, int> _dailySeconds = <String, int>{};
  int _totalSeconds = 0;
  bool _loaded = false;

  // ---------------- 读取 ----------------

  /// 从本地存储恢复统计；启动或页面进入时调用。
  void load() {
    _dailySeconds = _decodeDaily(
      _storage.getString(StorageKeys.readingDailySeconds),
    );
    _totalSeconds = _storage.getInt(
      StorageKeys.readingTotalSeconds,
      fallback: 0,
    );
    _loaded = true;
  }

  void _ensureLoaded() {
    if (!_loaded) {
      load();
    }
  }

  /// 累计阅读秒数。
  int get totalSeconds {
    _ensureLoaded();
    return _totalSeconds;
  }

  /// 累计阅读时长的展示文案。
  String get totalDurationLabel {
    final int seconds = totalSeconds;
    if (seconds <= 0) {
      return '还没有阅读记录';
    }
    if (seconds < 60) {
      return '$seconds 秒';
    }
    if (seconds < 3600) {
      return '${seconds ~/ 60} 分钟';
    }
    final int hours = seconds ~/ 3600;
    final int minutes = (seconds % 3600) ~/ 60;
    return minutes == 0 ? '$hours 小时' : '$hours 小时 $minutes 分';
  }

  /// 今天已阅读的秒数。
  int get todaySeconds {
    _ensureLoaded();
    return _dailySeconds[_dateKey(DateTime.now())] ?? 0;
  }

  /// 今天是否已经打卡。
  bool get hasCheckedInToday {
    _ensureLoaded();
    return (_dailySeconds[_dateKey(DateTime.now())] ?? 0) >=
        checkInThresholdSeconds;
  }

  /// 累计打卡天数（有阅读记录且超过阈值的天数）。
  int get totalCheckInDays {
    _ensureLoaded();
    int count = 0;
    for (final int seconds in _dailySeconds.values) {
      if (seconds >= checkInThresholdSeconds) {
        count++;
      }
    }
    return count;
  }

  /// 某个月份的打卡天数。
  int checkInDaysInMonth(DateTime month) {
    _ensureLoaded();
    final String prefix = _monthPrefix(month);
    int count = 0;
    _dailySeconds.forEach((String key, int seconds) {
      if (key.startsWith(prefix) && seconds >= checkInThresholdSeconds) {
        count++;
      }
    });
    return count;
  }

  /// 某个月份里「已打卡」的日期数字集合，供日历格子填充判断。
  Set<int> checkedInDayNumbersOfMonth(DateTime month) {
    _ensureLoaded();
    final String prefix = _monthPrefix(month);
    final Set<int> days = <int>{};
    _dailySeconds.forEach((String key, int seconds) {
      if (!key.startsWith(prefix) || seconds < checkInThresholdSeconds) {
        return;
      }
      final int day = int.tryParse(key.substring(8)) ?? 0;
      if (day > 0) {
        days.add(day);
      }
    });
    return days;
  }

  /// 某一天是否已打卡。
  bool hasCheckInOn(DateTime day) {
    _ensureLoaded();
    return (_dailySeconds[_dateKey(day)] ?? 0) >= checkInThresholdSeconds;
  }

  /// 每日阅读秒数快照（`yyyy-MM-dd` → 秒）。
  Map<String, int> get dailySeconds {
    _ensureLoaded();
    return Map<String, int>.unmodifiable(_dailySeconds);
  }

  /// 连续打卡天数（今天没读则从昨天往前数）。
  int get currentStreakDays {
    _ensureLoaded();
    DateTime cursor = DateTime.now();
    if (!hasCheckInOn(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    int streak = 0;
    while (hasCheckInOn(cursor) && streak < 36500) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  // ---------------- 写入 ----------------

  /// 累加一段阅读时长。
  ///
  /// [seconds] 允许为 0（例如刚进入就退出），此时不写盘。
  Future<void> addReadingSeconds(int seconds) async {
    _ensureLoaded();
    final int safe = seconds.clamp(0, 24 * 3600).toInt();
    if (safe <= 0) {
      return;
    }

    final String key = _dateKey(DateTime.now());
    _dailySeconds[key] = (_dailySeconds[key] ?? 0) + safe;
    _totalSeconds += safe;

    await _storage.setString(
      StorageKeys.readingDailySeconds,
      jsonEncode(_dailySeconds),
    );
    await _storage.setInt(StorageKeys.readingTotalSeconds, _totalSeconds);
  }

  /// 清空全部阅读统计（删除账号时使用）。
  Future<void> reset() async {
    _dailySeconds = <String, int>{};
    _totalSeconds = 0;
    _loaded = true;
    await _storage.remove(StorageKeys.readingDailySeconds);
    await _storage.remove(StorageKeys.readingTotalSeconds);
  }

  /// 用备份包里的统计整体替换本地数据（「完全覆盖」导入）。
  Future<void> replaceAll({
    required Map<String, int> dailySeconds,
    required int totalSeconds,
  }) async {
    _loaded = true;
    _dailySeconds = <String, int>{};
    dailySeconds.forEach((String key, int seconds) {
      if (key.isNotEmpty && seconds > 0) {
        _dailySeconds[key] = seconds;
      }
    });
    _totalSeconds = totalSeconds.clamp(0, 1 << 40).toInt();
    await _persist();
  }

  /// 把备份包里的统计合并进本地（「合并导入」）。
  ///
  /// 同一天取两者较大值，总时长直接相加，避免重复导入导致时长翻倍过多。
  Future<void> mergeFrom({
    required Map<String, int> dailySeconds,
    required int totalSeconds,
  }) async {
    _ensureLoaded();
    dailySeconds.forEach((String key, int seconds) {
      if (key.isEmpty || seconds <= 0) {
        return;
      }
      final int current = _dailySeconds[key] ?? 0;
      _dailySeconds[key] = seconds > current ? seconds : current;
    });
    _totalSeconds = (_totalSeconds + totalSeconds).clamp(0, 1 << 40).toInt();
    await _persist();
  }

  Future<void> _persist() async {
    await _storage.setString(
      StorageKeys.readingDailySeconds,
      jsonEncode(_dailySeconds),
    );
    await _storage.setInt(StorageKeys.readingTotalSeconds, _totalSeconds);
  }

  // ---------------- 工具 ----------------

  static String _dateKey(DateTime day) {
    final String month = day.month.toString().padLeft(2, '0');
    final String date = day.day.toString().padLeft(2, '0');
    return '${day.year}-$month-$date';
  }

  static String _monthPrefix(DateTime month) {
    return '${month.year}-${month.month.toString().padLeft(2, '0')}';
  }

  static Map<String, int> _decodeDaily(String? raw) {
    if (raw == null || raw.isEmpty) {
      return <String, int>{};
    }
    try {
      final dynamic decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return <String, int>{};
      }
      final Map<String, int> result = <String, int>{};
      decoded.forEach((dynamic key, dynamic value) {
        if (key is String && value is num) {
          result[key] = value.toInt();
        }
      });
      return result;
    } catch (_) {
      // 脏数据直接丢弃：统计缺失比崩溃可接受。
      return <String, int>{};
    }
  }
}
