/// 导入页「网站快捷访问小球」的数据模型。
///
/// 需求约定：小球内部展示罗马数字序号、下方展示自定义站名，
/// 网址只在本地存储中保存，不在界面上直接暴露。
class ImportSite {
  const ImportSite({
    required this.id,
    required this.name,
    required this.url,
  });

  /// 本地唯一 id（时间戳字符串即可，不与 url 绑定）。
  final String id;

  /// 展示名（用户自定义）。
  final String name;

  /// 目标网址，仅在点击时读取。
  final String url;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'name': name,
      'url': url,
    };
  }

  factory ImportSite.fromJson(Map<String, dynamic> json) {
    final dynamic rawId = json['id'];
    final dynamic rawName = json['name'];
    final dynamic rawUrl = json['url'];
    final String url = rawUrl is String ? rawUrl.trim() : '';
    final String name = rawName is String ? rawName.trim() : '';

    return ImportSite(
      id: rawId is String && rawId.isNotEmpty
          ? rawId
          : DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.isEmpty ? '未命名站点' : name,
      url: url,
    );
  }

  /// 罗马数字序号（I、II、III…），供小球内部展示。
  static String romanLabel(int index) {
    if (index <= 0) {
      return 'I';
    }
    const List<String> numerals = <String>[
      'I',
      'II',
      'III',
      'IV',
      'V',
      'VI',
      'VII',
      'VIII',
      'IX',
      'X',
      'XI',
      'XII',
      'XIII',
      'XIV',
      'XV',
      'XVI',
      'XVII',
      'XVIII',
      'XIX',
      'XX',
    ];
    if (index <= numerals.length) {
      return numerals[index - 1];
    }
    return '$index';
  }
}
