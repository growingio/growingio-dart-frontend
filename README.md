Flutter AOP 方案

https://juejin.cn/post/7036352267389239303

flutter 与 dart 版本对照表
https://docs.flutter.dev/development/tools/sdk/releases


## 创建项目
dart create <Project Folder>
dart pub get
// 若是无法找到package，可以拉取dart源代码，然后在 pubspec.yaml 配置依赖。
```
dependency_overrides:
  kernel:
    path: ../flutter_aspectd_dart_sdk/pkg/kernel
  meta:
    path: ../flutter_aspectd_dart_sdk/pkg/meta
  frontend_server:
    path: ../flutter_aspectd_dart_sdk/pkg/frontend_server
  front_end:
    path: ../flutter_aspectd_dart_sdk/pkg/front_end
  dev_compiler:
    path: ../flutter_aspectd_dart_sdk/pkg/dev_compiler
  _fe_analyzer_shared:
    path: ../flutter_aspectd_dart_sdk/pkg/_fe_analyzer_shared
  js_shared:
    path: ../flutter_aspectd_dart_sdk/pkg/js_shared
  build_integration:
    path: ../flutter_aspectd_dart_sdk/pkg/build_integration
  _js_interop_checks:
    path: ../flutter_aspectd_dart_sdk/pkg/_js_interop_checks
  package_config: any
  compiler:
    path: ../flutter_aspectd_dart_sdk/pkg/compiler
  js_runtime:
    path: ../flutter_aspectd_dart_sdk/pkg/js_runtime
  js_ast:
    path: ../flutter_aspectd_dart_sdk/pkg/js_ast
  vm:
    path: ../flutter_aspectd_dart_sdk/pkg/vm
```


## Hook VM代码
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

## 创建 flutter_frontend_server
使用自己的 flutter_frontend_server 生成 frontend_server.dart.snapshot 来替换 dart 默认的snapshot,使其具有 AOP 的能力。


生成命令：首先进入 flutter_frontend_server 目录
```cmd
dart --deterministic --no-sound-null-safety --snapshot=frontend_server.dart.snapshot frontend_server_starter.dart
```
> 在 dart 2.18.5 tag的源码中，frontend_server 还停留在 dart=2.9 (<2.12)，所以只能忽略空安全编译

生成后需要在 flutter 源代码下进行替换，分别为：
1. flutter/bin/cache/artifacts/engine/darwin-x64/frontend_server.dart.snapshot
2. flutter/bin/cache/dart-sdk/bin/snapshots/frontend_server.dart.snapshot

> 覆盖 frontend_server.dart.snapshot 后需要清理缓存， **flutter clean**
> 记得在 main.dart 中引入 growingio_inject_impl.dart 文件。

查看是否Hook成功：使用项目下的 dump_dill.dart，直接run main方法即可。需要将 app.dill放在项目下，会生成out.dill.txt文件，可以查看文件中是否有注入成功。


## AOP 代码库

widget inspect transform 源码位置：https://github.com/dart-lang/sdk/blob/main/pkg/kernel/lib/transformations/track_widget_constructor_locations.dart
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



## 需要HOOK的点

https://github.com/sensorsdata/sa_aspectd_impl/blob/master/lib/sensorsdata_aop_impl.dart

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


