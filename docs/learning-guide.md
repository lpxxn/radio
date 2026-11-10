# 从这个项目学习 Dart、Flutter 和 Riverpod

## 1. 数据类与空安全

从 lib/models/station.dart 开始。class 描述电台，final 字段初始化后不重新赋值，const 构造允许创建编译期常量。required 是必填命名参数，List<String> 和 Map<String, dynamic> 是泛型容器。factory Station.fromJson 将 JSON 字典转换成对象，toJson 做反向转换。

String? 可以为空；station?.name 有值才读取；value ?? fallback 为空时使用默认值。非空断言 ! 只能在明确检查之后使用，不应当作处理异常的方式。

练习：给电台加 slogan 字段，为旧缓存提供默认值，再在列表中显示。

## 2. Future 与 Stream

Future<T> 是未来的一次结果，例如刷新目录；Stream<T> 是连续事件，例如播放器状态变化。async/await 让异步代码按易读顺序组织，并不会让网络操作阻塞 UI。timeout 限制等待时间，try/catch 处理失败，流订阅必须在生命周期结束时 cancel。

特别注意：just_audio.play() 的 Future 直到暂停或结束才完成。连接流程不能一直 await 它，所以 RadioHandler 使用 unawaited 并单独捕获错误。

## 3. Widget 与布局

build() 描述当前状态应该显示的界面，可能频繁执行，因此不要在 build 中连电台、发网络请求或写磁盘。

Row/Column 安排方向；Expanded/Flexible 分配有限空间；Wrap 在空间不足时让按钮换行；LayoutBuilder 根据宽度显示或收起装饰喇叭；ListView 让目录独立滚动。CustomPainter 用 Canvas 绘制格栅与刻度，不需要下载图片。

StatelessWidget 不保存局部状态；StatefulWidget 的 State 保存刷新中等 UI 状态；ConsumerWidget 和 ConsumerStatefulWidget 额外提供 Riverpod 的 ref。

## 4. Riverpod 数据流

| Provider | 职责 |
|---|---|
| preferencesProvider | 注入本机偏好存储 |
| radioProvider | 应用唯一播放服务 |
| catalogProvider | AsyncNotifier 管理异步目录 |
| playbackProvider | StreamProvider 订阅播放快照 |
| libraryProvider | Notifier 管理收藏、历史、筛选 |
| filteredStationsProvider | 根据目录与筛选计算结果 |
| skinProvider | 皮肤与保存 |

ref.watch 订阅数据，变化后重建消费者；ref.read 读取一次，常用于按钮回调；ref.read(provider.notifier) 获取状态管理器并调用方法。状态变更用新的 LibraryState 替换旧值，不原地修改旧集合。

```dart
final library = ref.watch(libraryProvider);
// 用户点击时：
ref.read(libraryProvider.notifier).favorite(station.id);
```

ProviderScope 的 overrides 是依赖注入：正式运行注入真实播放器，测试注入 FakeEngine，不需要声卡或公网。ref.onDispose 释放 Provider 创建的流订阅和 HTTP 客户端。应用级播放服务不因 Widget 重建而重新创建。

本项目不使用 Riverpod 代码生成，先学习核心 Provider/Notifier/异步数据流。

## 5. 业务放在哪里

UI 负责显示与发命令；Repository 负责目录从哪来；RadioHandler 负责播放与恢复。因此系统通知栏的下一台直接调用 handler，页面通过 StreamProvider 跟着更新，不需要先操作页面。

## 6. 推荐练习

1. 在 RadioSkin 枚举中新增皮肤，理解枚举构造参数。
2. 给 LibraryState 增加音乐筛选，修改派生 Provider。
3. 增加台名排序，明确车机换台顺序是否也改变。
4. 加手动重试按钮，复用同一个 handler。
5. 修改 FakeEngine，模拟连续失败两次再成功，观察 wantPlay 与 phase 区别。
6. 阅读 `data/playback_session.dart` 和 `test/playback_session_test.dart`，理解 JSON 序列化、Future 串行写入，以及如何用两个 handler 模拟关闭后重新打开。
7. 对比 `ui/mobile_radio_player.dart` 与 `ui/desktop_radio_player.dart`：布局不同，共用 RadioPalette、Riverpod 快照、StationLibrary 和播放命令。观察 LayoutBuilder 怎样切换宽窗口和紧凑布局。
8. 阅读 `platform/startup_appearance.dart` 和 Android MainActivity：理解 MethodChannel 为什么需要把配色交给 Dart 启动前就存在的原生系统启动屏。

每次修改后运行 flutter analyze 和 flutter test；界面同时检查窄屏、平板、矮窗口与桌面。

官方参考：[Dart](https://dart.dev/language)、[Flutter](https://docs.flutter.dev/get-started/fundamentals)、[Riverpod](https://riverpod.dev/docs/introduction/getting_started)。实际依赖版本以 pubspec.lock 为准。


主页菜单位于面板左上角铭牌。退出逻辑在 lib/platform/app_exit.dart：先取消睡眠定时并停止后台播放，再调用 Flutter 平台退出 API；不使用 dart:io exit 强杀进程。iOS 按系统规则停止播放并尝试返回上一界面。

