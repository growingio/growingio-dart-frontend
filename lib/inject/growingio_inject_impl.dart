import 'growingio_inject_annotation.dart';

/// <p>
///   
/// @author cpacm 2022/12/12
@pragma("vm:entry-point")
class GrowingClickInject {

  @Inject("package:growingio_sdk_flutter/main.dart", "_MyHomePageState", "_incrementCounter")
  @pragma("vm:entry-point")
  void _incrementCounter() {
    print('KWLM called!');
  }
}