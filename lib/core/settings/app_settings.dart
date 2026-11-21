import 'package:flutter/material.dart';

import '../constants/storage_keys.dart';
import '../theme/app_colors.dart';
import '../services/local_storage_service.dart';

/// 边框粗细档位（设置页第 4 项）。
enum GlassBorderLevel { none, thin, thick }

/// 档位对应的说明文字与线宽。
extension GlassBorderLevelX on GlassBorderLevel {
  String get label {
    switch (this) {
      case GlassBorderLevel.none:
        return '无';
      case GlassBorderLevel.thin:
        return '细';
      case GlassBorderLevel.thick:
        return '粗';
    }
  }

  /// 实际绘制线宽（逻辑像素）。
  double get strokeWidth {
    switch (this) {
      case GlassBorderLevel.none:
        return 0.0;
      case GlassBorderLevel.thin:
        return 0.9;
      case GlassBorderLevel.thick:
        return 2.2;
    }
  }
}

/// 从存储值还原边框档位。
GlassBorderLevel glassBorderLevelFromStorage(String? value) {
  for (final GlassBorderLevel level in GlassBorderLevel.values) {
    if (level.name == value) {
      return level;
    }
  }
  return GlassBorderLevel.thin;
}

/// 阅读字体来源（设置页第 5 项）。
///
/// 字体只作用于「阅读正文 / 书名等小字」；所有中文大标题固定宋体，
/// 不受这里的选项影响（见 AppTypography 里的强制衬线逻辑）。
/// custom 为用户导入的第三方字体包（运行时通过 FontLoader 注册）。
enum ReadingFontMode { system, hei, serif, kai, mono, light, medium, custom }

extension ReadingFontModeX on ReadingFontMode {
  String get label {
    switch (this) {
      case ReadingFontMode.system:
        return '系统字体';
      case ReadingFontMode.hei:
        return '黑体';
      case ReadingFontMode.serif:
        return '宋体';
      case ReadingFontMode.kai:
        return '楷体';
      case ReadingFontMode.mono:
        return '等宽';
      case ReadingFontMode.light:
        return '细黑';
      case ReadingFontMode.medium:
        return '中黑';
      case ReadingFontMode.custom:
        return '自定义';
    }
  }

  String get english {
    switch (this) {
      case ReadingFontMode.system:
        return 'SYSTEM';
      case ReadingFontMode.hei:
        return 'SANS';
      case ReadingFontMode.serif:
        return 'SERIF';
      case ReadingFontMode.kai:
        return 'KAI';
      case ReadingFontMode.mono:
        return 'MONO';
      case ReadingFontMode.light:
        return 'LIGHT';
      case ReadingFontMode.medium:
        return 'MEDIUM';
      case ReadingFontMode.custom:
        return 'CUSTOM';
    }
  }

  /// 供 TextStyle.fontFamily 使用的字体族；null 表示跟随系统。
  String? get family {
    switch (this) {
      case ReadingFontMode.system:
        return null;
      case ReadingFontMode.hei:
        return 'sans-serif';
      case ReadingFontMode.serif:
        return 'serif';
      case ReadingFontMode.kai:
        return 'cursive';
      case ReadingFontMode.mono:
        return 'monospace';
      case ReadingFontMode.light:
        return 'sans-serif-light';
      case ReadingFontMode.medium:
        return 'sans-serif-medium';
      case ReadingFontMode.custom:
        return 'NWCustomFont';
    }
  }
}

/// 从存储值还原阅读字体来源。
ReadingFontMode readingFontModeFromStorage(String? value) {
  for (final ReadingFontMode mode in ReadingFontMode.values) {
    if (mode.name == value) {
      return mode;
    }
  }
  return ReadingFontMode.system;
}

/// 阅读水印类型（设置页第 8 项）。
enum WatermarkType { poem, english }

extension WatermarkTypeX on WatermarkType {
  String get label {
    switch (this) {
      case WatermarkType.poem:
        return '古诗';
      case WatermarkType.english:
        return '英文短句';
    }
  }

  String get english {
    switch (this) {
      case WatermarkType.poem:
        return 'POETRY';
      case WatermarkType.english:
        return 'ENGLISH';
    }
  }

  /// 设置页预览用的示例文案。
  String get sample {
    switch (this) {
      case WatermarkType.poem:
        return '此间有书，静待人来';
      case WatermarkType.english:
        return 'Read slowly, live deeply.';
    }
  }
}

/// 从存储值还原水印类型。
WatermarkType watermarkTypeFromStorage(String? value) {
  for (final WatermarkType type in WatermarkType.values) {
    if (type.name == value) {
      return type;
    }
  }
  return WatermarkType.poem;
}

/// 帧率偏好（设置页第 10 项）。
///
/// 说明：Flutter 无法在纯 Dart 层强制改写屏幕刷新率，
/// 这里保存的是偏好档位；实际刷新率仍由系统调度决定。
/// 第一轮收敛为三档：30 Hz / 60 Hz / 系统自调，
/// 高刷档位在不支持设备上无效，已移除。
enum FrameRateOption { system, hz30, hz60 }

extension FrameRateOptionX on FrameRateOption {
  String get label {
    switch (this) {
      case FrameRateOption.system:
        return '系统自调';
      case FrameRateOption.hz30:
        return '30 Hz';
      case FrameRateOption.hz60:
        return '60 Hz';
    }
  }

  /// 目标帧率；0 表示交给系统。
  int get fps {
    switch (this) {
      case FrameRateOption.system:
        return 0;
      case FrameRateOption.hz30:
        return 30;
      case FrameRateOption.hz60:
        return 60;
    }
  }

  String get description {
    switch (this) {
      case FrameRateOption.system:
        return '跟随屏幕自身刷新率，兼顾流畅与省电';
      case FrameRateOption.hz30:
        return '最省电，适合只做静态阅读时使用';
      case FrameRateOption.hz60:
        return '主流流畅度，功耗表现均衡';
    }
  }
}

/// 从存储值还原帧率档位（兼容旧版本的多档位存储值）。
FrameRateOption frameRateOptionFromStorage(String? value) {
  for (final FrameRateOption option in FrameRateOption.values) {
    if (option.name == value) {
      return option;
    }
  }
  switch (value) {
    case 'hz30':
    case 'hz48':
    case 'hz50':
      return FrameRateOption.hz30;
    case 'hz60':
    case 'hz90':
    case 'hz120':
      return FrameRateOption.hz60;
    default:
      return FrameRateOption.system;
  }
}

/// 玻璃材质的计算结果。
///
/// 组件层只消费这个只读快照，不再各自做 0~100 到模糊/透明度的换算，
/// 保证全局所有毛玻璃、液态玻璃视觉一致。
@immutable
class GlassSpec {
  const GlassSpec({
    required this.blurSigma,
    required this.liquidTintOpacity,
    required this.panelOpacity,
    required this.borderWidth,
  });

  /// BackdropFilter 的高斯模糊强度。
  final double blurSigma;

  /// 液态玻璃的渐变底色透明度。
  final double liquidTintOpacity;

  /// 毛玻璃面板的填充不透明度（需要保证文字可读）。
  final double panelOpacity;

  /// 边框线宽。
  final double borderWidth;

  bool get hasBlur => blurSigma > 0.4;

  bool get hasBorder => borderWidth > 0.01;
}

/// 全局设置控制器。
///
/// 承载「主题 + 毛玻璃参数 + 阅读字体 + 水印 + 性能与动效」，
/// 是这些偏好的唯一数据源；页面只读，修改一律走 set* 方法，
/// 方法内部完成「内存更新 → notify → 落盘」三步。
class AppSettingsController extends ChangeNotifier {
  AppSettingsController(this._storage);

  final LocalStorageService _storage;

  // ---------------- 默认值 ----------------

  static const ThemeMode _defaultThemeMode = ThemeMode.system;
  static const int _defaultGlassBlur = 58;
  static const int _defaultGlassOpacity = 42;
  static const GlassBorderLevel _defaultBorder = GlassBorderLevel.thin;
  static const ReadingFontMode _defaultFontMode = ReadingFontMode.system;
  static const DecorationTone _defaultDecorationTone = DecorationTone.none;
  static const bool _defaultWatermarkEnabled = false;
  static const WatermarkType _defaultWatermarkType = WatermarkType.poem;
  static const FrameRateOption _defaultFrameRate = FrameRateOption.system;
  static const bool _defaultReduceMotion = false;

  /// 全局「减少动画」开关的静态快照。
  ///
  /// 目的：让 PressableScale / LiquidGlass / GlassSlider 这类高频组件
  /// 不必依赖一次 Provider 查找，就能把动画时长压到 0。
  static bool disableMotion = _defaultReduceMotion;

  /// 全局帧率偏好的静态快照（0 表示跟随系统）。
  static int activeFps = 0;

  /// 统一的动效时长换算。
  ///
  /// - 「减少动画」开启时返回 [Duration.zero]，让过渡直接跳到终态；
  /// - 帧率选 30Hz 时把过渡放慢一倍，使低帧率下的位移更连续、可感知；
  /// - 其余情况返回原始时长。
  static Duration motion(int milliseconds) {
    if (disableMotion) {
      return Duration.zero;
    }
    if (activeFps <= 0) {
      return Duration(milliseconds: milliseconds);
    }
    final int fps = activeFps.clamp(24, 60);
    if (fps >= 60) {
      return Duration(milliseconds: milliseconds);
    }
    final double factor = 60 / fps;
    return Duration(milliseconds: (milliseconds * factor).round());
  }

  ThemeMode _themeMode = _defaultThemeMode;
  int _glassBlur = _defaultGlassBlur;
  int _glassOpacity = _defaultGlassOpacity;
  GlassBorderLevel _glassBorder = _defaultBorder;
  ReadingFontMode _readingFontMode = _defaultFontMode;
  DecorationTone _decorationTone = _defaultDecorationTone;
  String? _customFontPath;
  bool _watermarkEnabled = _defaultWatermarkEnabled;
  WatermarkType _watermarkType = _defaultWatermarkType;
  FrameRateOption _frameRate = _defaultFrameRate;
  bool _reduceMotion = _defaultReduceMotion;

  // ---------------- 对外只读状态 ----------------

  ThemeMode get themeMode => _themeMode;

  /// 毛玻璃模糊程度 0~100。
  int get glassBlur => _glassBlur;

  /// 毛玻璃透明度 0~100。
  int get glassOpacity => _glassOpacity;

  GlassBorderLevel get glassBorder => _glassBorder;

  /// 阅读字体来源。
  ReadingFontMode get readingFontMode => _readingFontMode;

  /// 当前装饰配色。
  DecorationTone get decorationTone => _decorationTone;

  /// 已导入的第三方字体文件路径（未导入时为 null）。
  String? get customFontPath => _customFontPath;

  /// 阅读水印开关。
  bool get watermarkEnabled => _watermarkEnabled;

  /// 阅读水印类型。
  WatermarkType get watermarkType => _watermarkType;

  /// 帧率偏好。
  FrameRateOption get frameRate => _frameRate;

  /// 是否减少动画（关闭页面切换与卡片动画）。
  bool get reduceMotion => _reduceMotion;

  /// 当前是否需要覆盖全局字体（系统字体时返回 null）。
  String? get fontFamilyOverride {
    if (_readingFontMode == ReadingFontMode.custom) {
      return _customFontPath == null ? null : 'NWCustomFont';
    }
    return _readingFontMode.family;
  }

  /// 供所有玻璃组件消费的材质参数。
  GlassSpec get glassSpec {
    final double blurRatio = _glassBlur.clamp(0, 100) / 100;
    final double opacityRatio = _glassOpacity.clamp(0, 100) / 100;

    return GlassSpec(
      // 100 对应 36 sigma：区间拉大后，滑块从头拖到尾的视觉差异才明显。
      blurSigma: blurRatio * 36,
      // 液态玻璃 0~100 对应 5%~50% 底色，透明与厚实的边界都能看清。
      liquidTintOpacity: 0.05 + opacityRatio * 0.45,
      // 毛玻璃面板 0~100 对应 12%~90%，低值真正通透、高值真正压低。
      panelOpacity: 0.12 + opacityRatio * 0.78,
      borderWidth: _glassBorder.strokeWidth,
    );
  }

  // ---------------- 初始化 ----------------

  /// 从本地存储读取设置。启动阶段调用，读取完成前不 notify。
  void load() {
    _themeMode =
        _themeModeFromStorage(_storage.getString(StorageKeys.themeMode));
    _glassBlur = _storage
        .getInt(StorageKeys.glassBlur, fallback: _defaultGlassBlur)
        .clamp(0, 100)
        .toInt();
    _glassOpacity = _storage
        .getInt(StorageKeys.glassOpacity, fallback: _defaultGlassOpacity)
        .clamp(0, 100)
        .toInt();
    _glassBorder = glassBorderLevelFromStorage(
      _storage.getString(StorageKeys.glassBorder),
    );
    _readingFontMode = readingFontModeFromStorage(
      _storage.getString(StorageKeys.readingFontMode),
    );
    _customFontPath = _storage.getString(StorageKeys.customFontPath);
    _decorationTone = decorationToneFromStorage(
      _storage.getString(StorageKeys.decorationTone),
    );
    AppColors.decoration = _decorationTone.color;
    _watermarkEnabled = _storage.getBool(
      StorageKeys.watermarkEnabled,
      fallback: _defaultWatermarkEnabled,
    );
    _watermarkType = watermarkTypeFromStorage(
      _storage.getString(StorageKeys.watermarkType),
    );
    _frameRate = frameRateOptionFromStorage(
      _storage.getString(StorageKeys.frameRate),
    );
    _reduceMotion = _storage.getBool(
      StorageKeys.reduceMotion,
      fallback: _defaultReduceMotion,
    );
    disableMotion = _reduceMotion;
    activeFps = _frameRate.fps;
  }

  // ---------------- 修改 ----------------

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) {
      return;
    }
    _themeMode = mode;
    notifyListeners();
    await _storage.setString(StorageKeys.themeMode, _themeModeToStorage(mode));
  }

  /// 在深/浅之间切换（设置页开关使用）。
  Future<void> toggleBrightness(Brightness currentBrightness) {
    final bool isDark = currentBrightness == Brightness.dark;
    return setThemeMode(isDark ? ThemeMode.light : ThemeMode.dark);
  }

  Future<void> setGlassBlur(int value) async {
    final int safe = value.clamp(0, 100).toInt();
    if (_glassBlur == safe) {
      return;
    }
    _glassBlur = safe;
    notifyListeners();
    await _storage.setInt(StorageKeys.glassBlur, safe);
  }

  Future<void> setGlassOpacity(int value) async {
    final int safe = value.clamp(0, 100).toInt();
    if (_glassOpacity == safe) {
      return;
    }
    _glassOpacity = safe;
    notifyListeners();
    await _storage.setInt(StorageKeys.glassOpacity, safe);
  }

  Future<void> setGlassBorder(GlassBorderLevel level) async {
    if (_glassBorder == level) {
      return;
    }
    _glassBorder = level;
    notifyListeners();
    await _storage.setString(StorageKeys.glassBorder, level.name);
  }

  /// 切换阅读字体来源；已在其它来源时同时清空自定义字体路径以外的状态。
  Future<void> setReadingFontMode(ReadingFontMode mode) async {
    if (_readingFontMode == mode) {
      return;
    }
    _readingFontMode = mode;
    notifyListeners();
    await _storage.setString(StorageKeys.readingFontMode, mode.name);
  }

  /// 切换装饰配色：立即作用于毛玻璃与控件装饰，并写入本地存储。
  Future<void> setDecorationTone(DecorationTone tone) async {
    if (_decorationTone == tone) {
      return;
    }
    _decorationTone = tone;
    AppColors.decoration = tone.color;
    notifyListeners();
    await _storage.setString(StorageKeys.decorationTone, tone.name);
  }

  /// 记录新导入的第三方字体文件（仅当选择「自定义」时立刻生效）。
  Future<void> setCustomFontPath(String? path) async {
    _customFontPath = path;
    notifyListeners();
    if (path == null || path.isEmpty) {
      await _storage.remove(StorageKeys.customFontPath);
      return;
    }
    await _storage.setString(StorageKeys.customFontPath, path);
  }

  Future<void> setWatermarkEnabled(bool enabled) async {
    if (_watermarkEnabled == enabled) {
      return;
    }
    _watermarkEnabled = enabled;
    notifyListeners();
    await _storage.setBool(StorageKeys.watermarkEnabled, enabled);
  }

  Future<void> setWatermarkType(WatermarkType type) async {
    if (_watermarkType == type) {
      return;
    }
    _watermarkType = type;
    notifyListeners();
    await _storage.setString(StorageKeys.watermarkType, type.name);
  }

  Future<void> setFrameRate(FrameRateOption option) async {
    if (_frameRate == option) {
      return;
    }
    _frameRate = option;
    activeFps = option.fps;
    notifyListeners();
    await _storage.setString(StorageKeys.frameRate, option.name);
  }

  Future<void> setReduceMotion(bool value) async {
    if (_reduceMotion == value) {
      return;
    }
    _reduceMotion = value;
    disableMotion = value;
    notifyListeners();
    await _storage.setBool(StorageKeys.reduceMotion, value);
  }

  /// 恢复出厂设置（删除账号时调用）。
  ///
  /// 不直接清空 SharedPreferences：那里还有书籍、摘抄等其它模块的数据，
  /// 各自通过自己的仓库清理，主题与玻璃参数在这里复位。
  Future<void> resetToDefaults() async {
    _themeMode = ThemeMode.system;
    _glassBlur = _defaultGlassBlur;
    _glassOpacity = _defaultGlassOpacity;
    _glassBorder = GlassBorderLevel.thin;
    _readingFontMode = _defaultFontMode;
    _decorationTone = _defaultDecorationTone;
    AppColors.decoration = null;
    _watermarkEnabled = _defaultWatermarkEnabled;
    _watermarkType = _defaultWatermarkType;
    _frameRate = _defaultFrameRate;
    _reduceMotion = _defaultReduceMotion;
    disableMotion = _defaultReduceMotion;
    activeFps = _defaultFrameRate.fps;
    notifyListeners();

    await _storage.setString(
      StorageKeys.themeMode,
      _themeModeToStorage(_themeMode),
    );
    await _storage.setInt(StorageKeys.glassBlur, _glassBlur);
    await _storage.setInt(StorageKeys.glassOpacity, _glassOpacity);
    await _storage.setString(StorageKeys.glassBorder, _glassBorder.name);
    await _storage.setString(
      StorageKeys.readingFontMode,
      _readingFontMode.name,
    );
    await _storage.setString(
      StorageKeys.decorationTone,
      _decorationTone.name,
    );
    await _storage.setBool(StorageKeys.watermarkEnabled, _watermarkEnabled);
    await _storage.setString(StorageKeys.watermarkType, _watermarkType.name);
    await _storage.setString(StorageKeys.frameRate, _frameRate.name);
    await _storage.setBool(StorageKeys.reduceMotion, _reduceMotion);
    // 自定义字体路径保留：删除账号时由删除流程单独清理字体文件。
  }

  // ---------------- 序列化辅助 ----------------

  static ThemeMode _themeModeFromStorage(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _themeModeToStorage(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}

/// 装饰配色（第 3 轮清单第 5 项）。
///
/// 只作用在毛玻璃与控件装饰上，浅色、深色模式都支持；
/// 不修改两种模式原本的底色，阅读正文背景也不受影响。
enum DecorationTone { none, blush, sky, mint, sakura, butter, lilac, mocha }

extension DecorationToneX on DecorationTone {
  String get label {
    switch (this) {
      case DecorationTone.none:
        return '默认';
      case DecorationTone.blush:
        return '淡红';
      case DecorationTone.sky:
        return '天蓝';
      case DecorationTone.mint:
        return '浅绿';
      case DecorationTone.sakura:
        return '樱花粉';
      case DecorationTone.butter:
        return '淡黄';
      case DecorationTone.lilac:
        return '浅紫';
      case DecorationTone.mocha:
        return '深咖';
    }
  }

  /// 装饰色；none 返回 null 表示不启用装饰。
  Color? get color {
    switch (this) {
      case DecorationTone.none:
        return null;
      case DecorationTone.blush:
        return const Color(0xFFD98C8C);
      case DecorationTone.sky:
        return const Color(0xFF7FB1DA);
      case DecorationTone.mint:
        return const Color(0xFF95C7AC);
      case DecorationTone.sakura:
        return const Color(0xFFDFA8BE);
      case DecorationTone.butter:
        return const Color(0xFFD9C27C);
      case DecorationTone.lilac:
        return const Color(0xFFAFA4DA);
      case DecorationTone.mocha:
        return const Color(0xFF8E7059);
    }
  }
}

/// 从存储值还原装饰配色。
DecorationTone decorationToneFromStorage(String? value) {
  for (final DecorationTone tone in DecorationTone.values) {
    if (tone.name == value) {
      return tone;
    }
  }
  return DecorationTone.none;
}
