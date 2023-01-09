/// <p>
///
/// @author cpacm 2022/12/12


import 'package:kernel/ast.dart';


import 'aop_iteminfo.dart';
import 'aop_tranform_utils.dart';
import 'growingio_method_transformer.dart';

class GrowingIOSuperInjectTransformer extends RecursiveVisitor {
  GrowingIOSuperInjectTransformer(this._aopItemInfoList);

  final List<GrowingioAopInfo> _aopItemInfoList;

  @override
  void visitClass(Class clazz) {
    Class? superClass = clazz.superclass;
    if (superClass == null) return;
    String clsName = superClass.name;
    bool matches = false;
    // match class，then match method
    for (int i = 0; i < _aopItemInfoList.length && !matches; i++) {
      GrowingioAopInfo info = _aopItemInfoList[i];
      if ((info.isRegex && RegExp(info.clsName).hasMatch(clsName)) ||
          (!info.isRegex && info.clsName == clsName)) {
        matches = _judgeClass(info, clsName);
        if (matches) {
          clazz.visitChildren(this);
          break;
        }
      }
    }
  }

  bool _judgeClass(GrowingioAopInfo aopItemInfo, String clsName) {
    if ((aopItemInfo.isRegex &&
            RegExp(aopItemInfo.clsName).hasMatch(clsName)) ||
        (!aopItemInfo.isRegex && clsName == aopItemInfo.clsName)) {
      return true;
    }
    return false;
  }

  @override
  void visitProcedure(Procedure method) {
    String methodName = method.name.text;
    GrowingioAopInfo? matchedInfo;
    // match method, and inject
    for (int i = 0; i < _aopItemInfoList.length; i++) {
      GrowingioAopInfo aopItemInfo = _aopItemInfoList[i];

      if ((aopItemInfo.isRegex &&
              RegExp(aopItemInfo.methodName).hasMatch(methodName)) ||
          (!aopItemInfo.isRegex && methodName == aopItemInfo.methodName)) {
        matchedInfo = aopItemInfo;
        break;
      }
    }

    if (matchedInfo == null) {
      return;
    }

    String printMsg = "";
    if (method.parent is Class) {
      printMsg += "${(method.parent as Class).name} ";
      if (method.parent!.parent is Library) {
        printMsg =
            "${(method.parent!.parent as Library).importUri.toString()} $printMsg";
      }
    } else if (method.parent is Library) {
      printMsg = "${(method.parent as Library).importUri.toString()} $printMsg";
    }
    printMsg += methodName;
    Logger.p("GrowingIO SuperInject: $printMsg");

    if (AopUtils.manipulatedProcedureSet.contains(method)) {
      return;
    }

    method.visitChildren(GrowingIOSuperInjectMethodTransformer(method, matchedInfo));
  }
}
