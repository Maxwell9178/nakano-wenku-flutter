# NakanoWenku release 混淆规则
#
# Flutter 引擎与插件都自带 keep 规则，这里只保留本工程会被反射/序列化访问的部分。

# 保留 Flutter embedding 的入口。
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# MainActivity 由清单声明，必须保留类名。
-keep class com.maxwell.nakanowenku.MainActivity { *; }

# file_picker / path_provider / url_launcher / shared_preferences 使用平台通道，
# 保留方法签名避免 R8 移除调用点。
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-keepattributes JavascriptInterface
-keepattributes *Annotation*

# 去掉 release 包里不需要的日志实现。
-assumenosideeffects class android.util.Log {
    public static *** v(...);
    public static *** d(...);
}

# Flutter 引擎内置了 Play Core 的「延迟组件」相关类，本工程不使用该能力，
# 依赖里自然没有 com.google.android.play.core，R8 会报 missing class。
# 直接忽略这些引用即可，不影响包内任何功能。
-dontwarn com.google.android.play.core.**
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
