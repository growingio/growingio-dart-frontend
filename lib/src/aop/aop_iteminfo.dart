/// <p>
///
/// @author cpacm 2022/12/12
import 'package:kernel/ast.dart';

class GrowingioAopInfo {
  GrowingioAopInfo(this.importUri, this.clsName, this.methodName, this.member,
      {this.isStatic = false,
      this.isRegex = false,
      this.isAfter = false,
      this.gioInjectType = 0});

  final String importUri;
  final String clsName;
  final String methodName;
  final Member member;
  final bool isStatic;
  final bool isRegex;
  final bool isAfter;
  final int gioInjectType;
}
