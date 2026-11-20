/// Appwrite 云同步预留层。
///
/// 本文件只负责把本地数据整理成**标准数据结构**，供后续独立的同步模块
/// （例如 Appwrite Functions / 自建服务）对接使用。
/// 按照项目约束，主程序内部不实现登录、鉴权、上传下载等任何联网业务，
/// 因此这里既没有 HTTP 客户端，也不引用任何网络依赖。
///
/// 数据映射约定：
/// - `users`          账号基础信息（昵称、入驻时间、聚合标签）
/// - `books`          书籍元数据
/// - `reading_progress` 每本书独立阅读进度
/// - `excerpts`       摘抄记录
/// - `reading_stats`  阅读时长 / 打卡天数
/// - `settings`       主题、毛玻璃参数、阅读偏好、水印等界面配置
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../models/book.dart';
import '../models/excerpt.dart';

/// 同步实体的种类，与 Appwrite 的 collection 一一对应。
enum SyncEntityKind {
  account,
  book,
  progress,
  excerpt,
  readingStats,
  settings;

  /// Appwrite collection 名称。
  String get collection {
    switch (this) {
      case SyncEntityKind.account:
        return 'users';
      case SyncEntityKind.book:
        return 'books';
      case SyncEntityKind.progress:
        return 'reading_progress';
      case SyncEntityKind.excerpt:
        return 'excerpts';
      case SyncEntityKind.readingStats:
        return 'reading_stats';
      case SyncEntityKind.settings:
        return 'settings';
    }
  }
}

/// 一条待同步的文档：`collection + documentId + 纯 JSON 数据`。
@immutable
class SyncDocument {
  const SyncDocument({
    required this.kind,
    required this.documentId,
    required this.updatedAt,
    required this.data,
  });

  final SyncEntityKind kind;
  final String documentId;

  /// 本地最后修改时间（毫秒时间戳），用于云端冲突合并。
  final int updatedAt;

  /// 只允许放 JSON 基础类型，便于直接写入 Appwrite 文档。
  final Map<String, dynamic> data;

  String get collection => kind.collection;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'collection': collection,
      'documentId': documentId,
      'updatedAt': updatedAt,
      'data': data,
    };
  }

  static SyncDocument? fromJson(Map<String, dynamic> json) {
    final String? name = json['collection'] as String?;
    if (name == null) {
      return null;
    }
    SyncEntityKind? kind;
    for (final SyncEntityKind item in SyncEntityKind.values) {
      if (item.collection == name) {
        kind = item;
        break;
      }
    }
    if (kind == null) {
      return null;
    }
    final dynamic rawData = json['data'];
    return SyncDocument(
      kind: kind,
      documentId: (json['documentId'] as String?) ?? '',
      updatedAt: (json['updatedAt'] as num?)?.toInt() ?? 0,
      data: rawData is Map
          ? rawData.map((dynamic k, dynamic v) => MapEntry('$k', v))
          : const <String, dynamic>{},
    );
  }
}

/// 一次同步上传的完整数据包。
@immutable
class AppwriteSyncPayload {
  const AppwriteSyncPayload({
    required this.userId,
    required this.generatedAt,
    required this.documents,
  });

  final String userId;
  final int generatedAt;
  final List<SyncDocument> documents;

  /// 按 collection 过滤，方便同步模块按需分批提交。
  List<SyncDocument> of(SyncEntityKind kind) {
    return documents
        .where((SyncDocument document) => document.kind == kind)
        .toList(growable: false);
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'generatedAt': generatedAt,
      'documents': documents
          .map((SyncDocument document) => document.toJson())
          .toList(growable: false),
    };
  }

  /// 备份包或调试日志里常见的使用方式：直接序列化成可读 JSON 文本。
  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  static AppwriteSyncPayload? fromJson(Map<String, dynamic> json) {
    final List<SyncDocument> documents = <SyncDocument>[];
    final dynamic rawDocuments = json['documents'];
    if (rawDocuments is List) {
      for (final dynamic item in rawDocuments) {
        if (item is Map) {
          final SyncDocument? document = SyncDocument.fromJson(
            item.map((dynamic k, dynamic v) => MapEntry('$k', v)),
          );
          if (document != null) {
            documents.add(document);
          }
        }
      }
    }
    return AppwriteSyncPayload(
      userId: (json['userId'] as String?) ?? '',
      generatedAt: (json['generatedAt'] as num?)?.toInt() ?? 0,
      documents: documents,
    );
  }
}

/// 同步回调接口。
///
/// 后续接入 Appwrite 时，实现 [push] / [pull] 即可；
/// 主程序默认使用 [NoopSyncBridge]，永远不会发起网络请求。
abstract class SyncBridge {
  /// 上传一次本地快照。
  Future<void> push(AppwriteSyncPayload payload);

  /// 拉取云端快照；没有数据时返回 null。
  Future<AppwriteSyncPayload?> pull();
}

/// 空实现：本地优先模式下的默认桥接，什么也不做。
class NoopSyncBridge implements SyncBridge {
  const NoopSyncBridge();

  @override
  Future<void> push(AppwriteSyncPayload payload) async {}

  @override
  Future<AppwriteSyncPayload?> pull() async => null;
}

/// 把本地数据整理成同步数据包的构建器。
///
/// 全部方法都是纯函数，不读写存储、不访问网络，方便单元测试与复用。
class SyncSnapshotBuilder {
  const SyncSnapshotBuilder._();

  /// 生成一份完整快照。
  ///
  /// - [books] 书籍列表（含阅读进度字段）
  /// - [excerpts] 摘抄记录
  /// - [dailySeconds] 每日阅读秒数（键为 `yyyy-MM-dd`）
  /// - [settings] 界面配置（主题、毛玻璃、水印等）
  /// - [readingPreferences] 阅读偏好（字号、行距、页边距等）
  static AppwriteSyncPayload build({
    required String userId,
    required String userName,
    required int? accountCreatedAt,
    required List<Book> books,
    required List<Excerpt> excerpts,
    required Map<String, int> dailySeconds,
    required int totalSeconds,
    required int checkInDays,
    required int currentStreakDays,
    required Map<String, dynamic> settings,
    required Map<String, dynamic> readingPreferences,
  }) {
    final int now = DateTime.now().millisecondsSinceEpoch;
    final List<SyncDocument> documents = <SyncDocument>[];

    documents.add(
      SyncDocument(
        kind: SyncEntityKind.account,
        documentId: userId,
        updatedAt: now,
        data: <String, dynamic>{
          'userId': userId,
          'userName': userName,
          'createdAt': accountCreatedAt,
          'tags': collectTags(books),
          'bookCount': books.length,
          'finishedCount': books.where((Book book) => book.isFinished).length,
          'appVersionName': AppConstants.versionName,
          'appVersionCode': AppConstants.versionCode,
          'updatedAt': now,
        },
      ),
    );

    for (final Book book in books) {
      final String bookId = _documentId(userId, book.id);
      documents.add(
        SyncDocument(
          kind: SyncEntityKind.book,
          documentId: bookId,
          updatedAt: (book.lastReadAt ?? book.addedAt ?? DateTime.now())
              .millisecondsSinceEpoch,
          data: <String, dynamic>{
            ...book.toJson(),
            'userId': userId,
            // 封面是纯本地文件路径，云端只记录是否有封面。
            'hasCover': book.coverPath != null && book.coverPath!.isNotEmpty,
          },
        ),
      );
      documents.add(
        SyncDocument(
          kind: SyncEntityKind.progress,
          documentId: bookId,
          updatedAt: (book.lastReadAt ?? book.addedAt ?? DateTime.now())
              .millisecondsSinceEpoch,
          data: <String, dynamic>{
            'userId': userId,
            'bookNumber': book.number,
            'bookId': book.id,
            'bookTitle': book.title,
            'progress': book.progress,
            'percent': (book.progress * 100).round(),
            'lastChapterTitle': book.lastChapterTitle,
            'isFinished': book.isFinished,
            'lastReadAt': book.lastReadAt?.millisecondsSinceEpoch,
          },
        ),
      );
    }

    for (final Excerpt excerpt in excerpts) {
      documents.add(
        SyncDocument(
          kind: SyncEntityKind.excerpt,
          documentId: _documentId(userId, excerpt.id),
          updatedAt: excerpt.createdAt.millisecondsSinceEpoch,
          data: <String, dynamic>{
            ...excerpt.toJson(),
            'userId': userId,
            'createdAt': excerpt.createdAt.millisecondsSinceEpoch,
          },
        ),
      );
    }

    documents.add(
      SyncDocument(
        kind: SyncEntityKind.readingStats,
        documentId: userId,
        updatedAt: now,
        data: <String, dynamic>{
          'userId': userId,
          'dailySeconds': dailySeconds,
          'totalSeconds': totalSeconds,
          'checkInDays': checkInDays,
          'currentStreakDays': currentStreakDays,
          'updatedAt': now,
        },
      ),
    );

    documents.add(
      SyncDocument(
        kind: SyncEntityKind.settings,
        documentId: userId,
        updatedAt: now,
        data: <String, dynamic>{
          'userId': userId,
          'settings': settings,
          'readingPreferences': readingPreferences,
          'updatedAt': now,
        },
      ),
    );

    return AppwriteSyncPayload(
      userId: userId,
      generatedAt: now,
      documents: documents,
    );
  }

  /// 汇总全部书籍标签（去重、保持出现顺序）。
  static List<String> collectTags(List<Book> books) {
    final Set<String> tags = <String>{};
    for (final Book book in books) {
      for (final String tag in book.tags) {
        final String trimmed = tag.trim();
        if (trimmed.isNotEmpty) {
          tags.add(trimmed);
        }
      }
    }
    return tags.toList(growable: false);
  }

  /// Appwrite 文档 ID 只保留字母、数字、下划线与短横线。
  static String _documentId(String userId, String localId) {
    final String raw = '${userId}_$localId';
    return raw.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
  }
}
