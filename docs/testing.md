# 测试与验收

自动检查：dart format lib test、flutter analyze、flutter test。

radio_handler_test 使用 FakeEngine 验证断网恢复、暂停取消重试、媒体换台循环、缓冲停滞和睡眠停止。这是状态机验证，不代替公网、声卡或车机验收。layout_test 验证 320×640、390×844、800×600、1440×900 布局。

## 实际弱网验收

1. 播放可访问的电台，核对声音、标题与通知栏。
2. 断网，等待缓存耗尽并观察缓冲/重连提示，持续一分钟。
3. 恢复网络，确认无需手动点播放。
4. 再断网并主动暂停，然后联网，必须仍然静音。
5. 慢连接时快速连续换台再暂停，旧台不得突然出声。
6. 验证睡眠定时停止并取消自动恢复。
7. Android 熄屏后重复，验证通知栏与蓝牙上下台。
8. 在指定 ICCOA CarLink 手机车机链路重复媒体与弱网用例。

Wi-Fi 图标不代表互联网可用；进度递增不代替正确声音验收。不同 CDN 可用性需独立排查。

## 构建

flutter build windows --release；flutter build apk --release。Windows 分发整个 Release 文件夹，Android 正式发布配置自己的签名，当前模板 release 使用调试签名。Android 首次构建下载 Gradle/Maven/SDK，如失败应保留具体错误，不关闭 TLS 或修改全局代理。Apple 平台需 Mac + Xcode。

## 本机验证记录（2026-11-03）

Flutter 3.47.9 / Dart 3.13.7，Windows C++ 工具链已安装，JDK 17 与 Android SDK 可用。Windows 和 Android Debug 构建成功；Windows 真实后端对本机 WAV 静音解码成功（进度超过 3 秒）。部分公网直播可获取 HLS 列表与音频分片，但连续播放探针仍超时，不能据此声称已完成公网听感或实车验收。ICCOA CarLink 与 Apple 平台未真机验证。

可选视觉渲染工具：flutter test tool/render_previews_test.dart。预览使用确定性测试目录，不代表联网目录快照。

可选 Windows 静音探针：flutter run -d windows -t tool/audio_smoke.dart。RADIO_SMOKE_URL 环境变量可指定本机 file URI 或其他直播地址；默认使用经济之声 HTTPS。探针直接调用真实后端并检查解码位置，不操作页面。

最终版本 Windows Release 与 Android Debug APK 均构建成功；静态检查无问题，13 项自动测试通过。


面板主页变更：检查面板外无标题/页脚，左上角菜单能换肤与打开关于，右上角退出前停止播放、取消睡眠和重连。



Windows 原生退出探针已实际运行，退出请求返回 AppExitResponse.exit 并关闭进程。Android 退出顺序有模拟平台测试，尚未在实体手机点击验收。


原生窗口修正验证：frameInfo 返回 hasCaption=false、clientFillsWindow=true、cornerHidden=true、nativeResizeEdge=true。最后一次改动未进行交互式拖动/缩放验收。



Android 真机测试已完成一轮，详见 [2026-11-03 真机记录](android-device-test-2026-11-03.md)。国内播放、熄屏媒体换台、实际断网后自动恢复均有真机证据；声音由用户确认，待测项单独列出。


## 手机全屏与列表范围更新

Android 真机已安装新版并截图确认：屏幕由主页填满，系统状态栏/导航栏隐藏，外层木框、金色圆角线和阴影移除。截图 docs/previews/android-borderless.png。Windows 外观保留。

自动测试共 16 项通过，新增地区队列循环、收藏队列重排/删除、收藏排序持久化与筛选项位置保护；四种尺寸额外检查手机表面从顶部开始并占满宽高。排序回调更新到 onReorderItem 后已重新构建并安装。真机已观察到收藏拖动手柄显示；最终拖动与限定队列的完整实操回归尚未完成，不以截图代替该项验收。

安卓间距调整：取消逐行 spaceBetween，改为固定分组间距；主控制和辅助控制各三项一行。静态检查及四尺寸布局测试通过，按手机 360×792 逻辑尺寸完成 Flutter 渲染检查，已构建并安装更新。

## 2026-11-10 手机页面重做

上述安卓复古面板和间距记录属于旧版本。当前手机改为独立现代播放页，移除音量滑块，顶部安全区固定在滚动视图外，底部面板负责选台和收藏排序。内置中文字体确保不跟随厂商手写主题。完整验证见 [手机现代页面与恢复记录](android-modern-ui-2026-11-10.md)。

静态检查无问题，20 项回归测试通过。真实手机从收藏选择北京新闻广播、退出并冷启动后仍显示该台和收藏 11 台，下一台切到北京音乐广播。字体和最后的安全区排版调整后重新构建 APK，并重跑全部五种平台/尺寸布局用例。

## 2026-11-10 现代桌面与启动配色

桌面复古布局已替换，手机与桌面共用现代主题和电台资料库。当前 22 项测试、5 张 Widget 渲染预览、Windows Release / Android Debug 构建通过，真实 HWND 探针通过；安卓实测绿/蓝两种配色的原生冷启动并恢复原有松间绿。运行包与完整验证边界见 [现代桌面与启动配色记录](desktop-modern-and-startup-theme-2026-11-10.md)。

