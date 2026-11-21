import 'package:flutter_test/flutter_test.dart';
import 'package:nakanowenku/core/models/app_update.dart';
import 'package:nakanowenku/core/models/book.dart';
import 'package:nakanowenku/core/models/excerpt.dart';
import 'package:nakanowenku/core/sync/appwrite_sync.dart';

/// 同步预留层与版本号的纯逻辑测试。
///
/// 这些用例不依赖任何平台通道，可在 `flutter test` 中直接运行，
/// 用于保证「只输出标准数据结构」的约定不被后续改动破坏。
void main() {
  group('SyncSnapshotBuilder', () {
    final Book book = Book(
      number: 1,
      title: '测试书籍',
      author: '作者',
      wordCount: 12000,
      chapterCount: 3,
      tags: const <String>['文学', ' 悬疑 ', ''],
      progress: 0.42,
      lastChapterTitle: '第三章',
      lastReadAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
      addedAt: DateTime.fromMillisecondsSinceEpoch(1690000000000),
    );

    final Excerpt excerpt = Excerpt(
      id: 'excerpt-1',
      bookNumber: 1,
      bookTitle: '测试书籍',
      chapterIndex: 2,
      chapterTitle: '第三章',
      text: '摘抄内容',
      createdAt: DateTime.fromMillisecondsSinceEpoch(1700000001000),
    );

    test('生成账号 / 书籍 / 进度 / 摘抄 / 统计 / 设置六类文档', () {
      final AppwriteSyncPayload payload = SyncSnapshotBuilder.build(
        userId: 'user-1',
        userName: '书友',
        accountCreatedAt: 1690000000000,
        books: <Book>[book],
        excerpts: <Excerpt>[excerpt],
        dailySeconds: <String, int>{'2026-11-20': 600},
        totalSeconds: 600,
        checkInDays: 1,
        currentStreakDays: 1,
        settings: <String, dynamic>{'themeMode': 'system'},
        readingPreferences: <String, dynamic>{'fontSize': 17.5},
      );

      expect(payload.of(SyncEntityKind.account).length, 1);
      expect(payload.of(SyncEntityKind.book).length, 1);
      expect(payload.of(SyncEntityKind.progress).length, 1);
      expect(payload.of(SyncEntityKind.excerpt).length, 1);
      expect(payload.of(SyncEntityKind.readingStats).length, 1);
      expect(payload.of(SyncEntityKind.settings).length, 1);
      expect(
          payload.of(SyncEntityKind.book).first.documentId, 'user-1_NW-0001');
      expect(payload.of(SyncEntityKind.progress).first.data['percent'], 42);
    });

    test('标签去重并去掉空白项', () {
      expect(
          SyncSnapshotBuilder.collectTags(<Book>[book]), <String>['文学', '悬疑']);
    });

    test('payload 可以 JSON 往返', () {
      final AppwriteSyncPayload payload = SyncSnapshotBuilder.build(
        userId: 'user-1',
        userName: '书友',
        accountCreatedAt: null,
        books: <Book>[book],
        excerpts: const <Excerpt>[],
        dailySeconds: const <String, int>{},
        totalSeconds: 0,
        checkInDays: 0,
        currentStreakDays: 0,
        settings: const <String, dynamic>{},
        readingPreferences: const <String, dynamic>{},
      );
      final AppwriteSyncPayload? decoded = AppwriteSyncPayload.fromJson(
        Map<String, dynamic>.from(payload.toJson()),
      );
      expect(decoded, isNotNull);
      expect(decoded!.userId, 'user-1');
      expect(decoded.documents.length, payload.documents.length);
    });
  });

  group('AppVersionInfo', () {
    test('版本号逐段比较', () {
      expect(AppVersionInfo.compareVersionNames('1.0.10', '1.0.9'), 1);
      expect(AppVersionInfo.compareVersionNames('1.0.0', '1.0.0'), 0);
      expect(AppVersionInfo.compareVersionNames('0.9.9', '1.0.0'), -1);
    });

    test('versionCode 更大时判定为新版本', () {
      const AppVersionInfo remote = AppVersionInfo(
        versionName: '1.0.0',
        versionCode: 2,
        changelog: '',
        downloadUrl: '/update/nakano-wenku.apk',
      );
      expect(remote.isNewerThan(localName: '1.0.0', localCode: 1), isTrue);
      expect(remote.isNewerThan(localName: '1.0.0', localCode: 2), isFalse);
    });
  });
}
