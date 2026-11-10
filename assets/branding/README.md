# 时光收音机图标

原创图标：珊瑚橙渐变底、奶油白收音机机身、天线、扬声器与调台标记。小尺寸不使用文字，适配圆形和圆角方形裁切。桌面入口图标是固定品牌标识；启动 Logo 另生成珊瑚、蓝、绿三套，随所选配色切换。

- `app_icon.svg`：可编辑矢量母版。
- `app_icon.png`：1024×1024 不透明方形图，适用于图标源文件。
- `app_icon_preview.png`：圆角透明背景预览。
- 生成工具：`flutter test tool/generate_app_icons_test.dart`。直接使用 Flutter Canvas 和 PNG 编码，另生成包含 16–256 多尺寸 PNG 的 Windows ICO，无需额外依赖。

Android 使用分层 adaptive icon，前景保留在安全区域；API 33+ 提供单色主题图标，旧版本提供五种密度 PNG。Android 12+ 的 LaunchTheme 显式使用新图标，旧版本启动背景也使用同款 Logo，底色为暖白，未增加人为启动延迟。

Windows、iOS、macOS 的图标资源已同步替换；iOS LaunchImage 与启动底色也已同步。Apple 工程仍需在 Mac/Xcode 编译及真机确认；Windows 现代版已重新构建并包含新图标。

2026-11-10：资源生成成功，flutter analyze 无问题，Android Debug APK 构建/覆盖安装成功。PLJ110 真机冷启动捕获到原生启动屏，确认是新的收音机图标；截图见 `docs/previews/android-startup.png`。APK 资源检查确认应用入口指向 adaptive icon。未清空应用数据。

后续配色更新：Android 12+ 通过持久化 LaunchCoral / LaunchBlue / LaunchGreen 启动主题，同时切换背景和 Logo。真机截图见 `docs/previews/android-startup-forest.png` 和 `android-startup-blue.png`；切换测试后恢复松间绿。默认配色仍为暖日珊瑚。

参考：[Android 启动屏](https://developer.android.com/develop/ui/views/launch/splash-screen/)、[自适应图标](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive)。
