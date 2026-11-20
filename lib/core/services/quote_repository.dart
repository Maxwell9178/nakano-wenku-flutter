import 'dart:math';

import 'package:flutter/services.dart';

import '../constants/app_constants.dart';

/// 名言名句读取。
///
/// 素材来自 `assets/data/quotes.txt`（工作区根目录「名言名句.txt」的副本），
/// 一行一条；读取后缓存在内存里，沉浸模式底部细长条随机取用。
class QuoteRepository {
  QuoteRepository();

  List<String>? _cache;

  /// 按行读取并缓存；文件缺失时返回空列表而不是抛异常。
  Future<List<String>> load() async {
    final List<String>? cached = _cache;
    if (cached != null) {
      return cached;
    }

    List<String> quotes = <String>[];
    try {
      final String raw = await rootBundle.loadString(AppConstants.quotesAsset);
      quotes = raw
          .split(RegExp(r'\r?\n'))
          .map((String line) => line.trim())
          .map(_stripIndex)
          .where((String line) => line.isNotEmpty && !line.startsWith('#'))
          .toSet()
          .toList(growable: false);
    } catch (_) {
      // 资源缺失时保留空列表，界面会隐藏底部长条。
      quotes = <String>[];
    }

    _cache = quotes;
    return quotes;
  }

  /// 去掉素材里手写的行首序号（如「1 」「10、」），只保留名言正文。
  static String _stripIndex(String line) {
    return line.replaceFirst(RegExp(r'^\d{1,3}\s*[.、．)）:：]?\s*'), '').trim();
  }

  /// 从已有列表里随机挑一条，避免和上一条重复（列表长度 > 1 时）。
  String pickRandom(List<String> quotes, {String? previous, Random? random}) {
    if (quotes.isEmpty) {
      return '';
    }
    final Random rng = random ?? Random();
    if (quotes.length == 1) {
      return quotes.first;
    }
    String next = quotes[rng.nextInt(quotes.length)];
    int guard = 0;
    while (next == previous && guard < 8) {
      next = quotes[rng.nextInt(quotes.length)];
      guard++;
    }
    return next;
  }
}
