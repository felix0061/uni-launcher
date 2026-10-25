# 0.5 全局底栏与系统导航栏

全局底栏复用原来的 Flutter `BottomDock`：首页、全部应用、双区空调、播放控制、歌曲信息、车辆信息、360 入口。外层背景横向铺满、四角为零、底部无留白；内部按钮仍跟随主题圆角。高度保持 96 设计像素，在 1920 宽车机上占 96 个物理像素；移除旧版额外 16 像素底边空白。

## 两个独立开关

设置 → 功能接入：

- **全局底栏**：跨应用显示；首次需要系统允许悬浮显示。默认关闭。桌面中显示内嵌底栏，悬浮副本隐藏；切到其他应用才显示全局副本，避免出现两条。
- **隐藏系统原有导航栏**：独立控制原车 / Android 原有底栏。需要 `WRITE_SECURE_SETTINGS`；未获授权不启用。关闭时按记录恢复原设置。原厂影像包 `com.ecarx.parking` 排除在全局隐藏规则外。

全局底栏开启时同时执行 `wm overscan 0,0,0,96`（应用内 exec，平台签名已验证可行），把所有应用窗口收缩到 984，悬浮窗加 `FLAG_LAYOUT_NO_LIMITS` 以物理屏幕坐标贴底 984–1080——外部应用内容始终在底栏上方，底部无空白。关闭时恢复 overscan 与 policy。

系统原有导航栏显示时，全局底栏贴在其上边缘；隐藏后贴在屏幕底边。没有额外装饰性空隙。前台服务通知提供“关闭全局底栏”“显示系统导航栏”入口。

## 实现

`GlobalDockService` 使用 Android 9 `TYPE_APPLICATION_OVERLAY(2038)` 和透明 WindowManager 窗口，常态只占底部条带，条带外触控交给前台应用。打开空调、音乐、车辆或应用列表时临时扩展窗口承载同一套 Flutter 面板，关闭后回到条带；返回键也能关闭展开面板；外部 HOME 返回或宿主隐藏会清除旧面板，再进入外部应用时恢复为窄条带。首页、长按首页分别回到桌面和设置。应用选择或原厂入口启动前先收起悬浮面板。

第二个 Dart 入口 `globalDockMain` 通过明确的 package library URI 启动，避免集成测试或不同宿主入口下找错函数。独立 engine 只绘制底栏和面板；`LauncherRuntime` 在 Application 进程内唯一持有媒体、车辆、应用目录、偏好和命令分发。Activity 和 Service 按 owner 引用订阅；桌面在后台时仍只有一套原生读取，服务退出后释放自己的订阅。地图容器只归主 Activity。

启动使用前台 Service 和低优先级持续通知；只有用户已开启且有悬浮权限时，开机和回到应用才恢复服务。关闭时销毁 FlutterView/engine 并移除窗口。所有新增跨应用命令仍经既有媒体和车控检查，不绕过逐项 capability 或读回确认。

系统栏管理用 `Settings.Global.policy_control`，在保留其他 token 的前提下替换为 `immersive.full` 规则——实测 XCSystemUI 的 CarNavigationBar 只响应 full，navigation 仅清除占位。持久保存原值和本应用写入值；关闭时只有当前值仍属于本应用才恢复，避免覆盖其他应用后来的改动。原值为空时恢复为空。没有使用 overscan、改分辨率或共享 system UID。

## 嘟嘟参考证据

本地 Dudu `ui.statebar.k.j` 确认由 WindowManager/Service 承载跨应用栏，普通模式使用 2038；领克另一路 2024 需要更多系统权限，且带人工偏移 / overscan。其部分 `policy_control` 命令字符串实际调用空 helper，不能只按字符串认定有效。因此本实现参考独立窗口与前台服务结构，使用可授权的 2038 和直接的原生设置读写，不复制 50px 偏移或无原值恢复的操作。

Android/Flutter 依据：[Android 9 PhoneWindowManager](https://android.googlesource.com/platform/frameworks/base/+/android-9.0.0_r3/services/core/java/com/android/server/policy/PhoneWindowManager.java)、[PolicyControl](https://android.googlesource.com/platform/frameworks/base/+/android-9.0.0_r3/services/core/java/com/android/server/policy/PolicyControl.java)、本机 Flutter embedding 源码的 `FlutterEngine`、`FlutterView`、`DartEntrypoint`。APK 摘录只保留在本地忽略目录，本文不打包第三方实现。

## 已测与限制

API28 / 1920×1080 模拟器已验证（10 项界面检查、11 项跨应用检查、9 项发布包 AOT 检查）：桌面不重复显示、外部系统设置上真实绘制、跨应用媒体命令回到共享状态、空调面板展开、返回收起、首页回桌面、长按首页进入设置，未发现 fatal/Dart 布局异常。系统导航栏隐藏后条带到屏幕底边；关闭可恢复原 policy。详细结果与截图在 `app/verification/global-dock/`。

普通应用 overlay **不自动为所有外部应用保留工作区**，可能遮住它们最底部的内容；本版不以 overscan 强制移动整车画面。贴边外观已实现，但不是注册第二个系统导航栏服务。Android 9 半透明表面可透出外部应用，Flutter 的模糊不能承诺对另一个进程的画面采样。

点击原厂影像前暂停全局底栏，返回桌面后恢复；尚无已验收的倒挡 / camera 自动状态订阅，不能宣称硬件倒车时的显隐和恢复已完成。上述权限、原车常驻区归属、倒车优先级、休眠 / 开机恢复、长期内存和帧耗时，均留待白天实车验证。

## 复现

```sh
python3 app/tools/flutter_task.py drive \
  --driver=test_driver/global_dock_driver.dart \
  --target=integration_test/global_dock_test.dart -d emulator-5580
# 重新构建 / 安装普通 debug 主入口后做跨应用验证：
python3 app/tools/flutter_task.py build apk --debug --target-platform android-x64
adb -s emulator-5580 install -r -d app/build/app/outputs/flutter-apk/app-debug.apk
python3 tools/verify_global_dock.py
# 安装正常 x86_64 release 包并在隔离模拟器授权后：
python3 tools/verify_release_dock.py
```

全部验证均只接受模拟器。发布包验证通过界面开关操作，结束后恢复开关及原系统 policy。跨应用脚本在隔离模拟器中显式授予悬浮及系统设置权限，以适应 Flutter 重新安装后的权限重置。前者验证界面与原生开关并比较系统 policy 恢复；后者临时设置本应用 debug 演示 / 全局栏偏好，完成后恢复原偏好文件，不安装其他应用、不接受车机序列号、不发送车辆指令。
