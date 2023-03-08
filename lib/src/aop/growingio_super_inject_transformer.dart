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
import 'package:growingio_aspectd_frontend/src/aop/aop_tranform_utils.dart';
import 'package:growingio_aspectd_frontend/src/aop/growingio_method_transformer.dart';

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
