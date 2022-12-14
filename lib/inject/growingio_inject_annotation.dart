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

  @pragma('vm:entry-point')
  const Inject(this.importUri, this.clsName, this.methodName,
      {this.isRegex = false, this.isStatic = false});
}
