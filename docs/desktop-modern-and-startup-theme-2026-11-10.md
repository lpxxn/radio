# 现代桌面界面与启动配色

## 最终行为

桌面从复古机身改为现代播放卡片，三种配色与手机统一。宽窗口并排显示播放区和电台资料库，更宽时增加发现/收藏/最近侧栏；窄或矮窗口通过选台按钮打开列表。矮窗口横向放置封面和台名，所有区域可随窗口大小调整，不对整个界面做比例缩放。桌面保留音量控制。

顶栏空白可拖动窗口，右侧提供配色/关于、最小化、最大化/还原和退出。继续保留原生窗口边缘缩放、无系统标题栏和圆角区域裁剪。收藏排序、搜索、播放范围及恢复逻辑沿用同一套 handler/Provider。

Android 12+ 的原生启动背景和 Logo 随所选配色一起改变。页面选择配色后，Flutter 保存偏好并通知原生 Activity；系统持久化稳定的启动主题名。Android 30 及以下的系统进程启动预览和 iOS 静态 LaunchScreen 存在平台边界，详见 architecture.md。

## 验证

- flutter analyze：无问题。
- flutter test：22 项通过，包含 Android/iOS 安全区、Windows 320×360、800×600、940×480、1440×900 布局和原有播放/收藏/恢复检查。
- 视觉渲染：三种桌面配色、800×600 紧凑窗口、手机页面均成功。使用内置目录和模拟引擎，图是实际 Widget 渲染，不代表联网播放或真实桌面抓屏。
- Windows Release 构建成功，最终程序和完整依赖复制至 dist/shiguang-radio-windows-modern，并打包为同名 zip。构建只出现既有临时构建目录增量生成警告。
- 独立 Windows 原生窗口探针运行成功，返回 FRAME_SMOKE_OK：clientFillsWindow=true、cornerHidden=true、hasCaption=false、nativeResizeEdge=true。此项核对真实 HWND；未做鼠标拖动手感的人工验收。
- Android Debug APK 构建/覆盖安装成功。PLJ110 / Android 17 上，松间绿冷启动背景和 Logo 均为绿色；菜单选择晴空蓝后，原生偏好变为 midnight，再次冷启动背景和 Logo 均为蓝色。验证后从菜单恢复原有松间绿，原生偏好为 forest。
- 未修改手机网络或清空应用数据，Apple 工程本轮未构建。

## 资源与入口

- 桌面预览：previews/desktop-walnut.png、desktop-midnight.png、desktop-forest.png、desktop-compact.png。
- 真实手机启动截图：previews/android-startup-forest.png、android-startup-blue.png。
- 桌面：lib/ui/desktop_radio_player.dart。
- 共用主题/封面/资料库：lib/ui/radio_theme.dart、radio_artwork.dart、station_library.dart。
- 启动配色：lib/platform/startup_appearance.dart、SkinNotifier、Android MainActivity 与 LaunchCoral/LaunchBlue/LaunchGreen 资源。

启动 API 参考：[Android SplashScreen.setSplashScreenTheme](https://developer.android.com/reference/android/window/SplashScreen#setSplashScreenTheme(int))。
