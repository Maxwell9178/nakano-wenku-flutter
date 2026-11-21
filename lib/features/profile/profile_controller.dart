import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../../core/models/book.dart';
import '../../core/services/book_repository.dart';
import '../../core/services/reading_stats_repository.dart';
import '../../core/services/tag_weight_repository.dart';
import '../../core/services/user_profile_controller.dart';

/// 「我的」页面的展示层数据聚合。
///
/// 只做读取与换算，不写业务数据：
/// * 书籍数量 / 标签占比来自 [BookRepository]；
/// * 入驻天数来自账号创建时间；
/// * 阅读时长、打卡来自 [ReadingStatsRepository]。
///
/// 这样「我的」页面不需要知道任何存储细节，后续接 Appwrite 同步时
/// 也可以直接复用这份聚合结果。
class ProfileController extends ChangeNotifier {
  ProfileController({
    required BookRepository books,
    required ReadingStatsRepository stats,
    required UserProfileController profile,
    required TagWeightRepository tagWeights,
  })  : _booksRepository = books,
        _stats = stats,
        _profile = profile,
        _tagWeights = tagWeights;

  final BookRepository _booksRepository;
  final ReadingStatsRepository _stats;
  final UserProfileController _profile;
  final TagWeightRepository _tagWeights;

  List<Book> _books = const <Book>[];
  bool _loading = true;

  bool get loading => _loading;

  /// 全部书籍（按编号升序，BookRepository 已排好）。
  List<Book> get books => List<Book>.unmodifiable(_books);

  ReadingStatsRepository get stats => _stats;

  UserProfileController get profile => _profile;

  /// 重新读取本地数据；从子页面返回、切换到本标签页时调用。
  void load() {
    _books = _booksRepository.loadAll();
    _stats.load();
    _loading = false;
    notifyListeners();
  }

  // ---------------- 账号 ----------------

  String get displayName => _profile.displayName;

  String? get avatarPath => _profile.avatarPath;

  /// 入驻总天数：创建当天算第 1 天。
  int get joinedDays {
    final DateTime? createdAt = _profile.createdAt;
    if (createdAt == null) {
      return 1;
    }
    final DateTime start = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );
    final DateTime today = DateTime.now();
    final int days =
        DateTime(today.year, today.month, today.day).difference(start).inDays +
            1;
    return days < 1 ? 1 : days;
  }

  // ---------------- 阅读统计 ----------------

  String get readingDurationLabel => _stats.totalDurationLabel;

  int get totalCheckInDays => _stats.totalCheckInDays;

  int get monthCheckInDays => _stats.checkInDaysInMonth(DateTime.now());

  int get todaySeconds => _stats.todaySeconds;

  // ---------------- 书籍统计 ----------------

  int get totalBooks => _books.length;

  int get finishedBooks => _books.where((Book book) => book.isFinished).length;

  int get unfinishedBooks => totalBooks - finishedBooks;

  /// 内置六类标签的书籍占比（0~1），用于雷达图。
  ///
  /// 分母统一使用「全部藏书数量」，因此六个值相加不一定等于 1
  /// （一本书可以同时带多个标签，也允许没有标签）。
  Map<String, double> get tagRatios {
    final Map<String, double> ratios = <String, double>{};
    for (final String tag in AppConstants.presetTags) {
      final int count =
          _books.where((Book book) => book.tags.contains(tag)).length;
      ratios[tag] = totalBooks == 0 ? 0 : count / totalBooks;
    }
    return ratios;
  }

  /// 已读完 / 未读完各自的书籍列表，供统计子页面使用。
  List<Book> booksByFinished({required bool finished}) {
    return _books
        .where((Book book) => book.isFinished == finished)
        .toList(growable: false);
  }

  // ---------------- 阅读兴趣雷达 ----------------

  /// 八维兴趣分值（0~1，顺序见 [TagWeightRepository.dimensions]）。
  ///
  /// 权重由「书籍标签 × 阅读时长」累加而来，阅读页每次退出都会刷新，
  /// 这里只读已持久化的结果并归一化。
  List<double> get tagRadar {
    final Map<String, int> raw = _tagWeights.loadRaw();
    return _tagWeights.normalized(raw);
  }

  /// 八维分值里最高的一项对应的维度名；全为 0 时返回 null。
  String? get topTag {
    final Map<String, int> raw = _tagWeights.loadRaw();
    String? top;
    int best = 0;
    raw.forEach((String key, int value) {
      if (value > best) {
        best = value;
        top = key;
      }
    });
    return best > 0 ? top : null;
  }
}
