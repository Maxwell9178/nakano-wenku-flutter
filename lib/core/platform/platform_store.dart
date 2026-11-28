/// 跨平台存储入口。
///
/// Android 上落在应用私有目录（和以前的 `library/` 目录结构一致），
/// 网页版上没有文件系统，改为写入浏览器的 IndexedDB。
///
/// 对外统一用「key」寻址，key 是相对路径形式，例如：
/// `chapters/NW-0001.json`、`covers/NW-0001.png`。
export 'platform_store_io.dart'
    if (dart.library.html) 'platform_store_web.dart';
