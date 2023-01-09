/// <p>
///
/// @author cpacm 2022/12/12

import 'package:kernel/ast.dart';

import 'aop_iteminfo.dart';
import 'growingio_method_transformer.dart';
import 'aop_tranform_utils.dart';

class GrowingIOInjectTransformer extends RecursiveVisitor {
  GrowingIOInjectTransformer(this._aopItemInfoList);

  final List<GrowingioAopInfo> _aopItemInfoList;

  @override
  void visitLibrary(Library library) {
    String importUri = library.importUri.toString();
    bool matches = false;
    // match library,then match class
    for (int i = 0; i < _aopItemInfoList.length && !matches; i++) {
      GrowingioAopInfo info = _aopItemInfoList[i];
      matches = _judgeLibrary(info, importUri);
      if (matches) {
        library.visitChildren(this);
        break;
      }
    }
  }

  bool _judgeLibrary(GrowingioAopInfo info, String importUri) {
    if ((info.isRegex && RegExp(info.importUri).hasMatch(importUri)) ||
        (!info.isRegex && info.importUri == importUri)) {
      return true;
    }
    return false;
  }

  @override
  void visitClass(Class clazz) {
    String clsName = clazz.name;
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

      if (method.parent is Class) {
        bool matchClass =
            _judgeClass(aopItemInfo, (method.parent as Class).name);
        if (!matchClass) continue;

        String importUri =
            (method.parent!.parent as Library).importUri.toString();
        bool matchLibrary = _judgeLibrary(aopItemInfo, importUri);
        if (!matchLibrary) continue;
      }

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

    Logger.p(
        "GrowingIO Inject: ${matchedInfo.importUri}/${matchedInfo.clsName} ${matchedInfo.methodName}");
    _aopItemInfoList.remove(matchedInfo);

    if (AopUtils.manipulatedProcedureSet.contains(method)) {
      return;
    }

    method.visitChildren(
        GrowingIOSuperInjectMethodTransformer(method, matchedInfo));
  }
}
