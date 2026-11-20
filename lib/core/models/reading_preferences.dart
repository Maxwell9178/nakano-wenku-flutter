import 'package:flutter/foundation.dart';

/// 阅读页的翻页模式。
///
/// * [scroll]：长页连续滚动（默认）；
/// * [horizontal]：左右分页逐页滑动。
enum ReaderPageMode { scroll, horizontal }

/// 翻页模式的中文名称（设置项与状态栏共用）。
extension ReaderPageModeLabel on ReaderPageMode {
  String get label => this == ReaderPageMode.scroll ? '滚动阅读' : '左右分页';
}

/// 从本地存储的字符串还原翻页模式，遇到未知值一律回落到滚动阅读。
ReaderPageMode readerPageModeFromValue(String? value) {
  return ReaderPageMode.values.firstWhere(
    (ReaderPageMode mode) => mode.name == value,
    orElse: () => ReaderPageMode.scroll,
  );
}

/// 阅读背景。
///
/// 内置背景用固定 id 描述（不占存储、不依赖图片文件）；
/// 用户上传的背景会先拷贝进应用私有目录，这里只保存 id / 名称 / 路径。
@immutable
class ReadingBackground {
  const ReadingBackground({
    required this.id,
    required this.name,
    this.path,
  });

  final String id;
  final String name;

  /// 自定义背景的本地文件路径；内置背景为 null。
  final String? path;

  bool get isBuiltIn => path == null || path!.isEmpty;

  // ---------------- 内置背景 ----------------

  static const String blackId = 'builtin.black';
  static const String lightId = 'builtin.light';
  static const String paperId = 'builtin.paper';
  static const String navyId = 'builtin.navy';

  /// 与需求文档一致的四种内置背景。
  static const List<ReadingBackground> builtIns = <ReadingBackground>[
    ReadingBackground(id: blackId, name: '纯黑灰格'),
    ReadingBackground(id: lightId, name: '纯白灰格'),
    ReadingBackground(id: paperId, name: '淡黄'),
    ReadingBackground(id: navyId, name: '深蓝'),
  ];

  static const ReadingBackground fallback = ReadingBackground(
    id: lightId,
    name: '纯白灰格',
  );

  /// 按 id 查找内置背景。
  static ReadingBackground? findBuiltIn(String id) {
    for (final ReadingBackground background in builtIns) {
      if (background.id == id) {
        return background;
      }
    }
    return null;
  }

  // ---------------- 序列化 ----------------

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'path': path,
      };

  factory ReadingBackground.fromJson(Map<String, dynamic> json) {
    final String id = (json['id'] as String?)?.trim() ?? '';
    final String name = (json['name'] as String?)?.trim() ?? '';
    final String? path = (json['path'] as String?)?.trim();
    return ReadingBackground(
      id: id.isEmpty ? 'background-${name.hashCode}' : id,
      name: name.isEmpty ? '自定义背景' : name,
      path: (path == null || path.isEmpty) ? null : path,
    );
  }
}

/// 阅读偏好（排版 + 操作）。
///
/// 需求约定：排版与操作内的设置保存为「阅读偏好」，全局共享；
/// 只有背景图配置是「每本书独立」的，存放在 [ReadingPreferencesRepository]。
@immutable
class ReadingPreferences {
  const ReadingPreferences({
    this.fontSize = 17.5,
    this.lineHeight = 1.85,
    this.paragraphSpacing = 12,
    this.leftMargin = 22,
    this.rightMargin = 22,
    this.topMargin = 26,
    this.bottomMargin = 30,
    this.pageMode = ReaderPageMode.scroll,
    this.tapToTurnPage = true,
    this.longPressMenu = true,
    this.volumeKeyTurn = false,
    this.defaultBackgroundId = '',
  });

  // 取值范围（与需求文档一致，设置页滑块共用同一份限制）。
  static const double fontSizeMin = 10;
  static const double fontSizeMax = 30;
  static const double lineHeightMin = 1.0;
  static const double lineHeightMax = 3.0;
  static const double marginMin = 0;
  static const double marginMax = 60;
  static const double paragraphSpacingMin = 0;
  static const double paragraphSpacingMax = 40;

  /// 字号，单位 pt。
  final double fontSize;

  /// 行距，单位倍。
  final double lineHeight;

  /// 段落间距，单位 px。
  final double paragraphSpacing;

  /// 左右页边距，单位 px（左右分开保存，便于「左 / 右」快捷设置）。
  final double leftMargin;
  final double rightMargin;

  /// 上下页边距，单位 px。
  final double topMargin;
  final double bottomMargin;

  final ReaderPageMode pageMode;

  /// 点击翻页、长按菜单、音量键翻页三个开关。
  final bool tapToTurnPage;
  final bool longPressMenu;
  final bool volumeKeyTurn;

  /// 「设置 → 阅读偏好」里选的默认阅读背景。
  ///
  /// 空串表示不指定、跟随主题（深色用纯黑、浅色用纯白）；
  /// 单本书在阅读页单独换过背景后，以那本书自己的记录优先。
  final String defaultBackgroundId;

  ReadingPreferences copyWith({
    double? fontSize,
    double? lineHeight,
    double? paragraphSpacing,
    double? leftMargin,
    double? rightMargin,
    double? topMargin,
    double? bottomMargin,
    ReaderPageMode? pageMode,
    bool? tapToTurnPage,
    bool? longPressMenu,
    bool? volumeKeyTurn,
    String? defaultBackgroundId,
  }) {
    return ReadingPreferences(
      fontSize: _clamp(fontSize ?? this.fontSize, fontSizeMin, fontSizeMax),
      lineHeight:
          _clamp(lineHeight ?? this.lineHeight, lineHeightMin, lineHeightMax),
      paragraphSpacing: _clamp(
        paragraphSpacing ?? this.paragraphSpacing,
        paragraphSpacingMin,
        paragraphSpacingMax,
      ),
      leftMargin: _clamp(leftMargin ?? this.leftMargin, marginMin, marginMax),
      rightMargin:
          _clamp(rightMargin ?? this.rightMargin, marginMin, marginMax),
      topMargin: _clamp(topMargin ?? this.topMargin, marginMin, marginMax),
      bottomMargin:
          _clamp(bottomMargin ?? this.bottomMargin, marginMin, marginMax),
      pageMode: pageMode ?? this.pageMode,
      tapToTurnPage: tapToTurnPage ?? this.tapToTurnPage,
      longPressMenu: longPressMenu ?? this.longPressMenu,
      volumeKeyTurn: volumeKeyTurn ?? this.volumeKeyTurn,
      defaultBackgroundId: defaultBackgroundId ?? this.defaultBackgroundId,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'fontSize': fontSize,
        'lineHeight': lineHeight,
        'paragraphSpacing': paragraphSpacing,
        'leftMargin': leftMargin,
        'rightMargin': rightMargin,
        'topMargin': topMargin,
        'bottomMargin': bottomMargin,
        'pageMode': pageMode.name,
        'tapToTurnPage': tapToTurnPage,
        'longPressMenu': longPressMenu,
        'volumeKeyTurn': volumeKeyTurn,
        'defaultBackgroundId': defaultBackgroundId,
      };

  factory ReadingPreferences.fromJson(Map<String, dynamic> json) {
    const ReadingPreferences defaults = ReadingPreferences();
    return ReadingPreferences(
      fontSize: _clamp(
        _asDouble(json['fontSize'], defaults.fontSize),
        fontSizeMin,
        fontSizeMax,
      ),
      lineHeight: _clamp(
        _asDouble(json['lineHeight'], defaults.lineHeight),
        lineHeightMin,
        lineHeightMax,
      ),
      paragraphSpacing: _clamp(
        _asDouble(json['paragraphSpacing'], defaults.paragraphSpacing),
        paragraphSpacingMin,
        paragraphSpacingMax,
      ),
      leftMargin: _clamp(
        _asDouble(json['leftMargin'], defaults.leftMargin),
        marginMin,
        marginMax,
      ),
      rightMargin: _clamp(
        _asDouble(json['rightMargin'], defaults.rightMargin),
        marginMin,
        marginMax,
      ),
      topMargin: _clamp(
        _asDouble(json['topMargin'], defaults.topMargin),
        marginMin,
        marginMax,
      ),
      bottomMargin: _clamp(
        _asDouble(json['bottomMargin'], defaults.bottomMargin),
        marginMin,
        marginMax,
      ),
      pageMode: readerPageModeFromValue(json['pageMode'] as String?),
      tapToTurnPage: _asBool(json['tapToTurnPage'], defaults.tapToTurnPage),
      longPressMenu: _asBool(json['longPressMenu'], defaults.longPressMenu),
      volumeKeyTurn: _asBool(json['volumeKeyTurn'], defaults.volumeKeyTurn),
      defaultBackgroundId:
          (json['defaultBackgroundId'] as String?)?.trim() ?? '',
    );
  }
}

// ---------------- 内部小工具 ----------------

double _clamp(double value, double min, double max) {
  if (value.isNaN) {
    return min;
  }
  return value.clamp(min, max).toDouble();
}

double _asDouble(dynamic value, double fallback) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? fallback;
  }
  return fallback;
}

bool _asBool(dynamic value, bool fallback) {
  if (value is bool) {
    return value;
  }
  return fallback;
}
