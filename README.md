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
注解为 @Inject，注入到对象方法中，参数为importUri，clsName，methodName；可选为isRegex，isStatic，isAfter，injectType。

### 注解插入
固定文件名为 `growingio_inject_impl.dart`.
注入有两种方式，注入方式和参数如下所示：

@Inject 各个参数解释如下表：

|  参数   |  默认值  | 解释 |
| ----  | ---- | ---- |
| importUri  | - | 注入指定的 library 路径 |
| clsName  | - | 指定的类名 |
| methodName | - | 指定的方法名 |
| isRegex | false | 是否需要对路径进行正则匹配 | 
| isStatic | false | 指定的方法是否是静态方法 |
| isAfter | false | 是否注入方法的最后一行 |
| injectType | 0 | 注入方式 0:普通注入，1：SuperInject |

@SuperInject 通过指定父类的路径和类名，所有继承该父类的子类中若包含指定的方法都会被Hook注入。
> importUri变为指定父类的路径 clsName变为指定指定父类的类名

关于参数说明，第一个参数统一规定为 `PointCut`，它包含 **target=>this** 和 **result=>方法返回值** 两个属性。其中只有isAfter为true且hook注入的方法有返回值时**result**才会有值。
其他剩余参数一一对应原方法的参数。注：可以少于原方法的参数个数。

如下方的方法
```dart
  /// 原方法为 "package:flutter/src/widgets/navigator.dart" 文件下的类 "_RouteEntry"的"handlePop"方法。
    @Inject(
      "package:flutter/src/widgets/navigator.dart", "_RouteEntry", "handlePop",
      isAfter: true)
  @pragma("vm:entry-point")
  /// 第一个参数统一为 PointCut,剩余的参数为原方法的入参，可以原封不动的挪过来。
  dynamic _routeHandlePop(PointCut pointCut,
      {required NavigatorState navigator,
      required Route<dynamic>? previousPresent}) {
    /// PointCut的target参数代表原方法中this
    dynamic target = pointCut.target;
    GrowingPageProvider.getInstance().handlePop(target.route, previousPresent);
    /// PointCut的result方法代表原方法的返回值。
    return pointCut.result;
  }
```

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
  for (int i = 0; i < _flutterProgramTransformers.length; i++) {
    _flutterProgramTransformers[i].transform(component);
  }
}
```

### 创建 flutter_frontend_server
使用自己的 flutter_frontend_server 生成 frontend_server.dart.snapshot 来替换 dart 默认的snapshot,使其具有 AOP 的能力。

生成命令：首先进入 flutter_frontend_server 目录
#### dart version < 2.19.0

```cmd
dart --deterministic --no-sound-null-safety --snapshot=frontend_server.dart.snapshot frontend_server_starter.dart
```
#### dart version >= 2.19.0 (Flutter version 3.7.0)

```cmd
dart --deterministic --snapshot=frontend_server.dart.snapshot frontend_server_starter.dart
```
> 在 dart 2.18.5 tag的源码中，frontend_server 还停留在 dart=2.9 (<2.12)，所以只能忽略空安全编译


### Widget路径修改
修改组件的路径，参考 widget inspect transform。
源码位置：https://github.com/dart-lang/sdk/blob/main/pkg/kernel/lib/transformations/track_widget_constructor_locations.dart
修改的几个重要关键词：
```dart
const String _locationFieldName = r'_gio_location';

if (importUri.path.contains('growingio_local_element.dart')) {
  for (Class class_ in library.classes) {
    if (class_.name == '_CustomHasCreationLocation') {
      _hasCreationLocationClass = class_;
      foundHasCreationLocationClass = true;
    } else if (class_.name == '_CustomLocation') {
      _locationClass = class_;
      foundLocationClass = true;
    }
  }
}
```
Inspector_service 位置：https://github.com/flutter/devtools/blob/d2d6b5b7f4b92972aff3cab320c206d00bcdd6a9/packages/devtools_app/lib/src/shared/diagnostics/inspector_service.dart