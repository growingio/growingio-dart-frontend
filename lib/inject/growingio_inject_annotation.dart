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

  final int injectType; //0：inject,1:superInject

  @pragma('vm:entry-point')
  const Inject(this.importUri, this.clsName, this.methodName,
      {this.isRegex = false, this.isStatic = false, this.isAfter = false, this.injectType = 0});
}

@pragma('vm:entry-point')
class PointCut {
  final dynamic target;
  dynamic result;

  @pragma('vm:entry-point')
  PointCut(this.target, {this.result});
}
