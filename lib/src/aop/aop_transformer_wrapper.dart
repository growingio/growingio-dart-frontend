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
import 'package:vm/modular/target/flutter.dart';

import 'package:growingio_aspectd_frontend/src/aop/growingio_inject_transformer.dart';
import 'package:growingio_aspectd_frontend/src/aop/growingio_super_inject_transformer.dart';
import 'package:growingio_aspectd_frontend/src/aop/aop_iteminfo.dart';
import 'package:growingio_aspectd_frontend/src/aop/aop_tranform_utils.dart';
import 'package:growingio_aspectd_frontend/src/aop/track_widget_custom_location.dart';

class AopWrapperTransformer extends FlutterProgramTransformer {
  AopWrapperTransformer({this.platformStrongComponent});

  Component? platformStrongComponent;

  final List<GrowingioAopInfo> injectInfoList = <GrowingioAopInfo>[];
  final List<GrowingioAopInfo> superInjectInfoList = <GrowingioAopInfo>[];
  final WidgetCreatorTracker tracker = WidgetCreatorTracker();

  @override
  void transform(Component component) {
    tracker.transform(component, component.libraries, null);
    prepareAopItemInfo(component);

    // transform
    if (injectInfoList.isNotEmpty) {
      component.visitChildren(GrowingIOInjectTransformer(injectInfoList));
    }

    // super inject transform
    if (superInjectInfoList.isNotEmpty) {
      component.visitChildren(GrowingIOSuperInjectTransformer(superInjectInfoList));
    }
  }

  void prepareAopItemInfo(Component program) {
    final List<Library> libraries = program.libraries;

    if (libraries.isEmpty) {
      return;
    }

    //check contain growingio plugin library
    _resolveAopProcedures(libraries);
  }

  void _resolveAopProcedures(Iterable<Library> libraries) {
    // all inject in one library:growingio_inject_impl.dart
    for (Library library in libraries) {
      if (RegExp(AopUtils.kAopGrowingInjectImpl)
          .hasMatch(library.importUri.toString())) {
        final List<Class> classes = library.classes;
        for (Class cls in classes) {
          for (Member member in cls.members) {
            final GrowingioAopInfo? aopItemInfo = _processAopMember(member);
            if (aopItemInfo != null) {
              if (aopItemInfo.gioInjectType == 0) {
                injectInfoList.add(aopItemInfo);
              } else if (aopItemInfo.gioInjectType == 1) {
                superInjectInfoList.add(aopItemInfo);
              }
            }
          }
        }
      }

      if (RegExp(AopUtils.kAopGrowingInjectAnnotation)
          .hasMatch(library.importUri.toString())) {
        final List<Class> classes = library.classes;
        for (Class cls in classes) {
          if (cls.name == AopUtils.kAopAnnotationClassPointCut) {
            AopUtils.pointCutProceedClass = cls;
          }
        }
      }
    }
  }

  // get @inject params
  GrowingioAopInfo? _processAopMember(Member member) {
    for (Expression annotation in member.annotations) {
      //Release mode
      if (annotation is ConstantExpression) {
        final ConstantExpression constantExpression = annotation;
        final Constant constant = constantExpression.constant;
        if (constant is InstanceConstant) {
          final InstanceConstant instanceConstant = constant;

          final Class instanceClass =
              instanceConstant.classReference.node as Class;
          final bool isGioInject = AopUtils.getAopModeByNameAndImportUri(
              instanceClass.name,
              (instanceClass.parent as Library).importUri.toString());
          if (!isGioInject) continue;

          String? importUri;
          String? clsName;
          String? methodName;
          bool isRegex = false;
          bool isStatic = false;
          bool isAfter = false;
          int injectType = 0;
          instanceConstant.fieldValues
              .forEach((Reference reference, Constant constant) {
            if (constant is StringConstant) {
              final String value = constant.value;
              if ((reference.node as Field).name.toString() ==
                  AopUtils.kAopAnnotationImportUri) {
                importUri = value;
              } else if ((reference.node as Field).name.toString() ==
                  AopUtils.kAopAnnotationClsName) {
                clsName = value;
              } else if ((reference.node as Field).name.toString() ==
                  AopUtils.kAopAnnotationMethodName) {
                methodName = value;
              }
            }
            if (constant is BoolConstant) {
              final bool value = constant.value;
              if ((reference.node as Field).name.toString() ==
                  AopUtils.kAopAnnotationIsRegex) {
                isRegex = value;
              } else if ((reference.node as Field).name.toString() ==
                  AopUtils.kAopAnnotationIsStatic) {
                isStatic = value;
              } else if ((reference.node as Field).name.toString() ==
                  AopUtils.kAopAnnotationIsAfter) {
                isAfter = value;
              }
            }

            if (constant is IntConstant){
              final int value = constant.value;
              if((reference.node as Field).name.toString() == AopUtils.kAopAnnotationInjectType){
                injectType = value;
              }
            }
          });
          member.annotations.clear();
          return GrowingioAopInfo(importUri!, clsName!, methodName!, member,
              isStatic: isStatic,
              isRegex: isRegex,
              isAfter: isAfter,
              gioInjectType: injectType);
        }
      }
      //Debug Mode
      else if (annotation is ConstructorInvocation) {
        final ConstructorInvocation constructorInvocation = annotation;
        final Class cls =
            constructorInvocation.targetReference.node?.parent as Class;
        final Library clsParentLib = cls.parent as Library;
        final bool isGioInject = AopUtils.getAopModeByNameAndImportUri(
            cls.name, clsParentLib.importUri.toString());
        if (!isGioInject) continue;

        final StringLiteral stringLiteral0 =
            constructorInvocation.arguments.positional[0] as StringLiteral;
        final String importUri = stringLiteral0.value;
        final StringLiteral stringLiteral1 =
            constructorInvocation.arguments.positional[1] as StringLiteral;
        final String clsName = stringLiteral1.value;
        final StringLiteral stringLiteral2 =
            constructorInvocation.arguments.positional[2] as StringLiteral;
        String methodName = stringLiteral2.value;
        bool isRegex = false;
        bool isStatic = false;
        bool isAfter = false;
        int injectType = 0;
        for (NamedExpression namedExpression
            in constructorInvocation.arguments.named) {
          if (namedExpression.name == AopUtils.kAopAnnotationIsRegex) {
            final BoolLiteral boolLiteral =
                namedExpression.value as BoolLiteral;
            isRegex = boolLiteral.value;
          } else if (namedExpression.name == AopUtils.kAopAnnotationIsStatic) {
            final BoolLiteral boolLiteral =
                namedExpression.value as BoolLiteral;
            isStatic = boolLiteral.value;
          } else if (namedExpression.name == AopUtils.kAopAnnotationIsAfter) {
            final BoolLiteral boolLiteral =
                namedExpression.value as BoolLiteral;
            isAfter = boolLiteral.value;
          }else if (namedExpression.name == AopUtils.kAopAnnotationInjectType) {
            final IntLiteral intLiteral =
                namedExpression.value as IntLiteral;
            injectType = intLiteral.value;
          }
        }
        member.annotations.clear();
        return GrowingioAopInfo(importUri, clsName, methodName, member,
            isStatic: isStatic,
            isRegex: isRegex,
            isAfter: isAfter,
            gioInjectType: injectType);
      }
    }
    return null;
  }
}
