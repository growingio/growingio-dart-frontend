Growingio Dart Frontend AOP Project

## 安装方式

该AOP方式基于修改 Flutter 源代码的方式进行，需要拉取GitHub 上的 [Flutter SDK](https://github.com/flutter/flutter)。
具体安装可以参考官方引导：[install flutter](https://docs.flutter.dev/get-started/install/macos#downloading-straight-from-github-instead-of-using-an-archive)

### 下载AOP文件
请根据自己项目的flutter版本下载对应tag的 `frontend_server.dart.snapshot`.
比如说 flutter 3.3.9版本，需要下载 tag 3.3.9 下的 `frontend_server.dart.snapshot` 文件。

### 覆盖源文件
需要在 flutter sdk下进行替换，位置分别为：
1. flutter/bin/cache/artifacts/engine/darwin-x64/frontend_server.dart.snapshot （macos）
2. flutter/bin/cache/dart-sdk/bin/snapshots/frontend_server.dart.snapshot

### 清除缓存
覆盖 `frontend_server.dart.snapshot` 后需要清理缓存
```cmd
flutter clean
```
一般在 growingio 插件中会引用 `growingio_inject_impl.dart`,之后就能通过注解实现无埋点技术了。

### 反编译
可以通过反编译查看是否Hook成功。
使用项目下的 `dump_dill.dart` ，直接run main方法即可。
需要将 app.dill放在项目下，会生成out.dill.txt文件，可以查看文件中是否有注入成功。

> app.dill 是flutter编译后的产物，一般位于 `/.dart_tool/flutter_build/<一串长参数>/app.dill`

## 无埋点使用方式

可以将项目中的`inject`目录下的文件加入你的项目中，这两个文件是 Dart 编译过程中实现AOP的关键文件。

### 声明注解
固定文件名为 `growingio_inject_annotation.dart`. 
注解为 @Inject，参数为importUri，clsName，methodName；可选为isRegex，isStatic。

### 注解插入
固定文件名为 `growingio_inject_impl.dart`.
插入统一为插入方法的入口处，可以接收原方法的所有参数或者少于原方法的参数个数。

## 如何编译

### Hook VM代码
修改 dart sdk pkg下的vm代码，路径为 <dart sdk>/pkg/vm/lib/target/flutter.dart
能使外部的transformer在dart代码优化前参与到Flutter代码的编译中。
参考如下：https://github.com/XianyuTech/sdk/commit/0b75bb256761342d321b92540a477d6e59301a48
```dart
abstract class FlutterProgramTransformer {
  void transform(Component component);
}

  static List<FlutterProgramTransformer> _flutterProgramTransformers = [];
  static List<FlutterProgramTransformer> get flutterProgramTransformers => _flutterProgramTransformers;

	if (_flutterProgramTransformers.length > 0) {
	int flutterProgramTransformersLen = _flutterProgramTransformers.length;
	for (int i=0; i<flutterProgramTransformersLen; i++) {
	_flutterProgramTransformers[i].transform(component);
	}
    
```

### 创建 flutter_frontend_server
使用自己的 flutter_frontend_server 生成 frontend_server.dart.snapshot 来替换 dart 默认的snapshot,使其具有 AOP 的能力。

生成命令：首先进入 flutter_frontend_server 目录
```cmd
dart --deterministic --no-sound-null-safety --snapshot=frontend_server.dart.snapshot frontend_server_starter.dart
```
> 在 dart 2.18.5 tag的源码中，frontend_server 还停留在 dart=2.9 (<2.12)，所以只能忽略空安全编译


### Widget路径修改
修改组件的路径，参考 widget inspect transform。
源码位置：https://github.com/dart-lang/sdk/blob/main/pkg/kernel/lib/transformations/track_widget_constructor_locations.dart
修改的几个重要关键词：
```dart
const String _locationFieldName = r'_gio_location';


  if (importUri.path.contains('growingio_autotracker.dart')) {
    for (Class class_ in library.classes) {
      if (class_.name == '_GIOHasCreationLocation') {
        _hasCreationLocationClass = class_;
        foundHasCreationLocationClass = true;
      } else if (class_.name == '_GIOLocation') {
        _locationClass = class_;
        foundLocationClass = true;
      }
    }
  }
```
Inspecttor_service 位置：https://github.com/flutter/devtools/blob/master/packages/devtools_app/lib/src/screens/inspector/inspector_service.dart

## Growingio 无埋点需要HOOK的点

### 点击事件

> call
> package:flutter/src/gestures/hit_test.dart  HitTestTarget  -handleEvent
> 插入 GrowingHelper.getInstance().handleEvent(RenderObject, pointerEvent);

> Execute
> package:flutter/src/gestures/recognizer.dart  GestureRecognizer  -invokeCallback
> GrowingHelper.getInstance().handleClickEvent(eventName);

### widget 路径优化

> Execute
> package:flutter/src/widgets/framework.dart  RenderObjectElement  -mount || -update
> element.renderObject?.debugCreator = DebugCreator(element);


### path 页面

> Execute
> package:flutter/src/widgets/navigator.dart **_RouteEntry** -handlePush
> GrowingHelper.getInstance().handlePush(target.route,previous);

> Execute
> package:flutter/src/widgets/navigator.dart  **_RouteEntry** -handlePop
> GrowingHelper.getInstance().handlePop(target.route,previous);

> Execute
> package:flutter/src/material/page.dart  MaterialRouteTransitionMixin  -buildPage
> GrowingHelper.getInstance().handleBuildPage(target,widgetResult.child!, pointCut.positionalParams[0]);

> Execute
> package:flutter/src/widgets/framework.dart  Element  -deactivateChild
> GrowingHelper.getInstance().handleDeactivate(target,pointCut.positionalParams[0]);

> Execute
> package:flutter/src/cupertino/route.dart  CupertinoRouteTransitionMixin  -buildPage
> GrowingHelper.getInstance().handleBuildPage(target,widgetResult.child!, pointCut.positionalParams[0]);


### 页面刷新
> Execute
> package:flutter/src/scheduler/binding.dart  SchedulerBinding  -handleDrawFrame
> GrowingHelper.getInstance().handleDrawFrame();

> Execute
> package:flutter/src/widgets/editable_text.dart  EditableTextState  -updateEditingValue
> GrowingHelper.getInstance().handleTextChanged(pointCut.target as EditableTextState, pointCut.positionalParams[0]);


