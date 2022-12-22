/// <p>
///
/// @author cpacm 2022/12/12
import 'package:growingio_aspectd_frontend/src/aop/growingio_inject_transformer.dart';
import 'package:kernel/ast.dart';
import 'package:vm/target/flutter.dart';

import 'aop_iteminfo.dart';
import 'aop_tranform_utils.dart';

import 'track_widget_custom_location.dart';

class AopWrapperTransformer extends FlutterProgramTransformer {
  AopWrapperTransformer({this.platformStrongComponent});

  Component? platformStrongComponent;

  final List<GrowingioAopInfo> injectInfoList = <GrowingioAopInfo>[];
  final WidgetCreatorTracker tracker = WidgetCreatorTracker();

  @override
  void transform(Component component) {
    tracker.transform(component, component.libraries, null);
    prepareAopItemInfo(component);

    // transform
    if (injectInfoList.isNotEmpty) {
      component.visitChildren(GrowingIOInjectTransformer(injectInfoList));
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
    Library? gioLibrary;
    for (Library library in libraries) {
      if (RegExp(AopUtils.GROWINGIO_INJECT_IMPL)
          .hasMatch(library.importUri.toString())) {
        Library gioLibrary = library;
        final List<Class> classes = gioLibrary.classes;
        for (Class cls in classes) {
          for (Member member in cls.members) {
            if (!(member is Member)) {
              continue;
            }
            final GrowingioAopInfo? aopItemInfo = _processAopMember(member);
            if (aopItemInfo != null) {
              injectInfoList.add(aopItemInfo);
            }
          }
        }
      }

      if (RegExp(AopUtils.GROWINGIO_INJECT_ANNOTATION)
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
          });

          member.annotations.clear();

          return GrowingioAopInfo(importUri!, clsName!, methodName!, member,
              isStatic: isStatic, isRegex: isRegex, isAfter: isAfter);
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
          }
        }
        member.annotations.clear();
        return GrowingioAopInfo(importUri, clsName, methodName, member,
            isStatic: isStatic, isRegex: isRegex, isAfter: isAfter);
      }
    }
    return null;
  }
}
