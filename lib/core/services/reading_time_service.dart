import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/book.dart';
import 'book_repository.dart';
import 'tag_weight_repository.dart';

/// 单本书阅读时长累计服务（第 2 轮新增）。
///
/// 阅读页进入时 [start]，退到后台 / 退出阅读页时 [flush]，
/// 时长累加到 [Book.totalReadMs] 并落盘；每次落盘后顺带重算雷达图权重。
/// 只在本地记录，不上传任何数据。
class ReadingTimeService {
  ReadingTimeService({
    required BookRepository books,
    required TagWeightRepository tagWeights,
  })  : _books = books,
        _tagWeights = tagWeights;

  final BookRepository _books;
  final TagWeightRepository _tagWeights;

  int? _activeBookNumber;
  DateTime? _startedAt;
  bool _flushing = false;

  /// 当前正在计时的书（null 表示未计时）。
  int? get activeBookNumber => _activeBookNumber;

  /// 开始为某本书计时；切换到另一本书时会先把上一段时长落盘。
  Future<void> start(int bookNumber) async {
    if (_activeBookNumber == bookNumber && _startedAt != null) {
      return;
    }
    await flush();
    _activeBookNumber = bookNumber;
    _startedAt = DateTime.now();
  }

  /// 结束计时并把这一段时间写入书籍记录。
  Future<void> flush() async {
    final int? bookNumber = _activeBookNumber;
    final DateTime? startedAt = _startedAt;
    _activeBookNumber = null;
    _startedAt = null;

    if (bookNumber == null || startedAt == null || _flushing) {
      return;
    }

    final int elapsedMs = DateTime.now().difference(startedAt).inMilliseconds;
    if (elapsedMs <= 0) {
      return;
    }

    _flushing = true;
    try {
      final List<Book> books = _books.loadAll();
      final int index = books.indexWhere((Book b) => b.number == bookNumber);
      if (index < 0) {
        return;
      }
      final Book book = books[index];
      books[index] = book.copyWith(totalReadMs: book.totalReadMs + elapsedMs);
      await _books.saveAll(books);
      await _tagWeights.recompute(books);
    } catch (error) {
      // 计时是附加能力，失败不影响阅读体验。
      debugPrint('[NakanoWenku][reading-time] flush failed: $error');
    } finally {
      _flushing = false;
    }
  }
}
