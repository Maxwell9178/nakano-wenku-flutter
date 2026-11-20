import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/services/app_services.dart';

/// 应用入口。
///
/// 启动顺序刻意保持简单：先完成本地服务初始化（SharedPreferences +
/// 账号资料 + 全局设置），再渲染首帧，避免页面在数据未就绪时取到空值。
/// 之后由开屏页负责 3~5 秒的随机停留与路由跳转。
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 竖屏为主：书架与阅读页的排版都按竖屏设计。
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);

  // 内容延伸到系统栏下方，配合各页面的 SafeArea 与毛玻璃材质。
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await AppServices.instance.bootstrap();

  runApp(const NakanoWenkuApp());
}
