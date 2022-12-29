import 'growingio_inject_annotation.dart';

/// <p>
///   
/// @author cpacm 2022/12/12
@pragma("vm:entry-point")
class GrowingClickInject {
  @Inject("package:flutter/src/gestures/recognizer.dart", "GestureRecognizer",
      "invokeCallback")
  @pragma("vm:entry-point")
  void _invokeCallback(PointCut target, String name) {
    print(name);
  }
}