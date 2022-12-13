/// <p>
///
/// @author cpacm 2022/12/12
import 'package:growingio_aspectd_frontend/src/aop/aop_tranform_utils.dart';
import 'package:kernel/ast.dart';
import 'package:kernel/type_algebra.dart';

import 'aop_iteminfo.dart';

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
        //print("GrowingIO Inject: " + importUri);
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
          //print("GrowingIO Inject: " + clsName);
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

    print("GrowingIO Inject: ${matchedInfo.importUri}/${matchedInfo.clsName} ${matchedInfo.methodName}");
    _aopItemInfoList.remove(matchedInfo);

    // deal with method
    if (matchedInfo.isStatic) {
      if (method.parent is Library) {
        transformInstanceMethodProcedure(
            method.parent as Library, matchedInfo, method);
      } else if (method.parent is Class) {
        transformInstanceMethodProcedure(
            method.parent!.parent as Library, matchedInfo, method);
      }
    } else {
      if (method.parent != null) {
        transformInstanceMethodProcedure(
            method.parent!.parent as Library, matchedInfo, method);
      }
    }
  }

  void transformInstanceMethodProcedure(Library originalLibrary,
      GrowingioAopInfo aopItemInfo, Procedure originalProcedure) {
    //get function params,body and return
    final FunctionNode functionNode = originalProcedure.function;

    // inject GioMethod to the method top.
    Block injectGioFunction = createPointcutCallFromOriginal(
        originalLibrary,
        aopItemInfo,
        originalProcedure,
        AopUtils.argumentsFromFunctionNode(functionNode));
    if (functionNode.body != null) {
      injectGioFunction.addStatement(functionNode.body!);
    }
    functionNode.body = injectGioFunction;
    //print("GrowingIO Function: "+functionNode.body.toString());
  }

  // create InjectMethod
  Block createPointcutCallFromOriginal(Library library,
      GrowingioAopInfo aopItemInfo, Member member, Arguments arguments) {
    AopUtils.insertLibraryDependency(
        library, aopItemInfo.member.parent?.parent as Library);
    Expression? callExpression;
    if (aopItemInfo.member is Procedure) {
      final Procedure procedure = aopItemInfo.member as Procedure;

      Arguments injectArgs =
          AopUtils.argumentsFromFunctionNode(procedure.function);
      if (injectArgs.positional.length > arguments.positional.length) {
        print(
            "Error: Inject Method Params length more than Target Method Params");
        return Block(<Statement>[]);
      }

      // map target method params into inject method.
      for (int i = 0; i < injectArgs.positional.length; i++) {
        injectArgs.positional[i] = arguments.positional[i];
      }
      //print("GrowingIO inject: args " + injectArgs.toString());

      if (procedure.isStatic) {
        callExpression =
            StaticInvocation(aopItemInfo.member as Procedure, injectArgs);
      } else {
        // first, call constructor
        final Class aopItemMemberCls = aopItemInfo.member.parent as Class;
        final ConstructorInvocation redirectConstructorInvocation =
            ConstructorInvocation.byReference(
                aopItemMemberCls.constructors.first.reference,
                Arguments(<Expression>[]));

        // then,call inject method.
        callExpression = InstanceInvocation(InstanceAccessKind.Instance,
            redirectConstructorInvocation, aopItemInfo.member.name, injectArgs,
            interfaceTarget: aopItemInfo.member as Procedure,
            functionType: AopUtils.computeFunctionTypeForFunctionNode(
                (aopItemInfo.member as Procedure).function, injectArgs));

        print("GrowingIO inject: expression  " + callExpression.toString());
      }
    }

    // inject always needn't return
    final bool shouldReturn =
        !((aopItemInfo.member as Procedure).function.returnType is VoidType);

    final Block bodyStatements = Block(<Statement>[]);
    if (shouldReturn) {
      bodyStatements.addStatement(ReturnStatement(callExpression));
    } else {
      bodyStatements.addStatement(ExpressionStatement(callExpression!));
    }
    return bodyStatements;
  }
}
