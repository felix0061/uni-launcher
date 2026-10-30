# UNI 桌面 —— release 混淆保留规则
#
# 现状：release 已显式关闭 minify（见 build.gradle.kts），本文件是双保险。
# 若日后重新开启 R8，必须保留以下规则，否则离线语音引擎会在 native 层加载失败：
#   RuntimeException: Failed to get field ID for maxActivePaths

# sherpa-onnx：JNI 用 GetFieldID 按原始名字访问 Kotlin data class 的私有字段，
# 类名/字段名一旦被重命名，native 侧就读不到配置对象。
-keep class com.k2fsa.sherpa.onnx.** { *; }
-keepclassmembers class com.k2fsa.sherpa.onnx.** { *; }

# JNI 入口类：方法名与 native 符号一一对应，不可重命名。
-keepclasseswithmembernames class * {
    native <methods>;
}
