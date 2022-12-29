/// <p>
///
/// @author cpacm 2022/12/12

@pragma('vm:entry-point')
class Inject {
  /// Indicating which dart file to operate on.
  final String importUri;

  /// Indicating which dart class to operate on.
  final String clsName;

  /// Indicating which dart method to operate on.
  final String methodName;

  /// Indicating whether those specification above should be regarded as
  /// regex expressions.
  final bool isRegex;

  final bool isStatic;

  /// When set to true, you need to ensure that the type returned by the method is consistent with the returned type of the hook method.
  final bool isAfter;

  @pragma('vm:entry-point')
  const Inject(this.importUri, this.clsName, this.methodName,
      {this.isRegex = false, this.isStatic = false, this.isAfter = false});
}

@pragma('vm:entry-point')
class SuperInject extends Inject {
  @pragma('vm:entry-point')
  const SuperInject(String importUri, String clsName, String methodName,
      {bool isRegex = false, bool isStatic = false, bool isAfter = false})
      : super(importUri, clsName, methodName,
            isRegex: isRegex, isStatic: isStatic, isAfter: isAfter);
}

@pragma('vm:entry-point')
class PointCut {
  final dynamic target;
  dynamic result;

  @pragma('vm:entry-point')
  PointCut(this.target, {this.result});
}
