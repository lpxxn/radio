# 平台与 ICCOA CarLink

## Android

MainActivity 继承 AudioServiceActivity，与后台服务共用 FlutterEngine。Manifest 声明网络、唤醒锁、前台媒体服务、AudioService 与媒体按键接收器。

| 系统命令 | 行为 |
|---|---|
| play / pause / stop | 播放 / 暂停 / 停止 |
| skipToNext / skipToPrevious | 选台时的当前列表循环换台 |
| playFromMediaId | 根据电台 ID 选台 |
| getChildren | 返回可浏览电台队列 |

断网时保持用户播放意图。系统省电策略可能杀进程；被杀死或强制结束后不自行启动播放。需要真机验证熄屏、蓝牙、来电、音频焦点与网络切换。

## ICCOA CarLink 手机车联

目标明确为 ICCOA CarLink。当前已实现标准 Android MediaSession/MediaBrowserService 入口，并对换台业务进行逻辑测试；这不等于完成 CarLink 应用发现、准入、融合桌面或实车接入。

[ICCOA 官方互联技术要求](https://www.iccoa.cn/tech/68.html) 区分投屏与桌面融合场景；本项目没有获取合作方 SDK/指定机型材料，不加入猜测的私有权限或白名单。后续需：

1. 明确手机品牌、系统、车机型号和 CarLink 版本。
2. 依据对应合作方文档确认媒体会话发现、应用映射或专用 SDK 要求。
3. 必要时新增原生适配层，经 MethodChannel 调用现有播放命令，不另起播放器。
4. 验证车机上下台、手机通知栏与页面同步，以及断线恢复、用户暂停、来电和熄屏。
5. 完成实际要求的包名、签名、声明和分发流程。

蓝牙按键有效不能证明完整 CarLink 适配。没有集成 HiCar SDK，也不将 Android Auto 当作 CarLink。

## Windows

media_kit 直接使用 libmpv 播放。媒体键目前仅窗口焦点内处理，没有 SMTC 全局集成或托盘。发布时须分发 runner 目录内 exe、DLL、data，不能只复制 exe。

CMake 增加 MSVC /utf-8，防止中文 Windows 的默认代码页使依赖源码警告被当作错误。未改动 Pub 缓存。

## iOS / macOS

已生成工程，预留 just_audio 原生 Apple 播放、audio_service 系统媒体控制。iOS 配置后台 audio，macOS 配置 network.client；部分 HTTP 电台使用媒体网络例外，不关闭证书验证。

必须在 macOS + Xcode 构建、配置签名并验证后台、锁屏、蓝牙、音频打断。Windows 无法完成 Apple 平台编译或验收。CarPlay 接入未实现。

依赖参考：[audio_service](https://pub.dev/packages/audio_service)、[just_audio](https://pub.dev/packages/just_audio)、[Windows 后端](https://pub.dev/packages/media_kit)。


音频焦点被抢占（如来电）或拔出耳机时，统一暂停并取消网络重连。打断结束后由用户手动恢复，避免在通话中被重连抢播。


### Windows 无边框窗口

Windows runner 使用 WS_POPUP 并在 WM_NCCALCSIZE 中移除系统非客户区；不再显示系统标题栏、最小化/最大化/关闭按钮和系统装饰边线。任务栏和 Alt+F4 仍保留，窗口关闭也可用面板内的退出按钮。

拖动面板顶部空白区域移动窗口，可见面板边缘 10 个逻辑像素通过原生 WM_NCHITTEST 调整大小，Flutter 子 HWND 在边缘返回 HTTRANSPARENT，将命中交给父窗口。Flutter 经 cn.shiguang.radio/window MethodChannel 发送 move，Win32 交给原生移动循环处理；手机端不发送这些命令。最小窗口为 320×360 逻辑像素，最大化区域遵守系统工作区。

验证：flutter run -d windows -t tool/window_frame_smoke.dart。该探针查询真实 HWND 的窗口样式和客户区，断言 hasCaption=false 且 clientFillsWindow=true，再正常退出。Widget 预览本身不能证明系统标题栏已移除。

圆角与面板外留白通过 SetWindowRgn 裁剪，区域由 Flutter 面板实际绘制边界同步，不使用黑色矩形模拟透明。探针额外验证 cornerHidden=true、nativeResizeEdge=true；这验证区域与原生命中路径，不代替鼠标手感验收。


Android 全屏使用 WindowInsetsControllerCompat 隐藏系统栏，参照 [Android 官方沉浸式模式](https://developer.android.com/develop/ui/views/layout/immersive)。手机保留顶部安全区；Windows 现代布局占满原生客户区，移除了复古机身和外框。

Windows 顶部新增应用自己的最小化、最大化/还原和退出按钮，仍不使用系统装饰标题栏。窗口桥接的 minimize / toggleMaximize 分别调用 ShowWindow；拖动空白区仍使用原生窗口移动循环。

Android 12+ 在选择配色时持久化系统 SplashScreen 主题，冷启动背景和 Logo 跟随所选配色。Android 17 真机已验证松间绿、晴空蓝，结束后恢复原来的松间绿。图标入口仍保持固定品牌色，只有启动 Logo 跟随配色。详见架构文档的启动配色说明。

