///  GrowingAnalytics
///  @author cpacm 2022/12/12
///  Copyright (C) 2023 Beijing Yishu Technology Co., Ltd.
///
///  Licensed under the Apache License, Version 2.0 (the "License");
///  you may not use this file except in compliance with the License.
///  You may obtain a copy of the License at
///
///      http://www.apache.org/licenses/LICENSE-2.0
///
///  Unless required by applicable law or agreed to in writing, software
///  distributed under the License is distributed on an "AS IS" BASIS,
///  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
///  See the License for the specific language governing permissions and
///  limitations under the License.

import 'package:kernel/ast.dart';

import 'package:growingio_aspectd_frontend/src/aop/aop_iteminfo.dart';
import 'package:growingio_aspectd_frontend/src/aop/growingio_method_transformer.dart';
import 'package:growingio_aspectd_frontend/src/aop/aop_tranform_utils.dart';

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
      matches = _judgeClass(info, clsName);
      if (matches) {
        clazz.visitChildren(this);
        break;
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
