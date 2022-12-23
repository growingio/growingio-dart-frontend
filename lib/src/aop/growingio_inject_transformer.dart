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

    print(
        "GrowingIO Inject: ${matchedInfo.importUri}/${matchedInfo.clsName} ${matchedInfo.methodName}");
    _aopItemInfoList.remove(matchedInfo);

    if (AopUtils.manipulatedProcedureSet.contains(method)) {
      return;
    }

    // deal with method
    if (matchedInfo.isStatic) {
      if (method.parent is Library) {
        transformStaticMethodProcedure(
            method.parent as Library, matchedInfo, method);
      } else if (method.parent is Class) {
        transformStaticMethodProcedure(
            method.parent!.parent as Library, matchedInfo, method);
      }
    } else {
      if (method.parent != null) {
        transformInstanceMethodProcedure(
            method.parent!.parent as Library, matchedInfo, method);
      }
    }
  }

  void transformStaticMethodProcedure(Library originalLibrary,
      GrowingioAopInfo aopItemInfo, Procedure originalProcedure) {
    //get function params,body and return
    /// step1. create stub method.
    final FunctionNode functionNode = originalProcedure.function;
    final Statement? body = functionNode.body;
    final bool shouldReturn =
        originalProcedure.function.returnType is! VoidType;
    final stubKey = AopUtils.getStubMethodName(originalProcedure.name.text);
    final originStubProcedure = _createStubProcedure(
        Name(stubKey, originalProcedure.name.library),
        originalProcedure,
        body,
        shouldReturn);

    final Node? parent = originalProcedure.parent;

    if (parent is Library) {
      parent.procedures.add(originStubProcedure);
    } else if (parent is Class) {
      parent.procedures.add(originStubProcedure);
    }

    /// step2. inject method to origin method.
    createPointcutCallFromOriginal(originalLibrary, aopItemInfo,
        originalProcedure, originStubProcedure, functionNode);
    //print("GrowingIO Inject Function: "+functionNode.body.toString());
  }

  void transformInstanceMethodProcedure(Library originalLibrary,
      GrowingioAopInfo aopItemInfo, Procedure originalProcedure) {
    //get function params,body and return
    /// step1. create stub method.
    final FunctionNode functionNode = originalProcedure.function;
    final Class originalClass = originalProcedure.parent as Class;
    final Statement? body = functionNode.body;
    final bool shouldReturn =
        originalProcedure.function.returnType is! VoidType;
    final stubKey = AopUtils.getStubMethodName(originalProcedure.name.text);
    final originStubProcedure = _createStubProcedure(
        Name(stubKey, originalProcedure.name.library),
        originalProcedure,
        body,
        shouldReturn);

    originalClass.procedures.add(originStubProcedure);

    /// step2. inject method to origin method.
    createPointcutCallFromOriginal(originalLibrary, aopItemInfo,
        originalProcedure, originStubProcedure, functionNode);
    //print("GrowingIO Inject Function: "+functionNode.body.toString());
  }

  // create InjectMethod
  void createPointcutCallFromOriginal(
      Library library,
      GrowingioAopInfo aopItemInfo,
      Member member,
      Procedure stubProcedure,
      FunctionNode functionNode) {
    AopUtils.insertLibraryDependency(
        library, aopItemInfo.member.parent?.parent as Library);
    Expression? callExpression;
    if (aopItemInfo.member is Procedure) {
      final Procedure procedure = aopItemInfo.member as Procedure;
      Arguments arguments = AopUtils.argumentsFromFunctionNode(functionNode);
      Arguments injectArgs =
          AopUtils.argumentsFromFunctionNode(procedure.function);
      if (injectArgs.positional.isEmpty) return;

      int addition = 1;
      if (!aopItemInfo.isAfter) {
        injectArgs.positional[0] =
            AopUtils.createPointCutConstructor(ThisExpression());
      } else {
        injectArgs.positional[0] = AopUtils.createPointCutConstructor(
            ThisExpression(),
            stubProcedure: stubProcedure);
      }
      if (injectArgs.positional.length > arguments.positional.length + 1) {
        print(
            "Error: Inject Method Params length more than Target Method Params");
        return;
      }

      // map target method params into inject method.
      // include named expression
      for (int i = addition; i < injectArgs.positional.length; i++) {
        injectArgs.positional[i] = arguments.positional[i - addition];
      }
      for (int i = 0; i < injectArgs.named.length; i++) {
        injectArgs.named[i] = arguments.named[i];
      }

      print("GrowingIO inject args: " + injectArgs.toString());

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

        print("GrowingIO inject expression:  " + callExpression.toString());
      }
    }

    // inject after need return
    final bool shouldReturn = functionNode.returnType is! VoidType;

    final Block bodyStatements = Block(<Statement>[]);
    Statement injectStatement = shouldReturn
        ? ReturnStatement(callExpression)
        : ExpressionStatement(callExpression!);

    if (functionNode.body != null) {
      if (aopItemInfo.isAfter && shouldReturn) {
        bodyStatements.addStatement(injectStatement);
        functionNode.body = bodyStatements;
      } else {
        Arguments stubArgs =
            AopUtils.argumentsFromFunctionNode(stubProcedure.function);
        InstanceInvocation resultInstanceInvocation = InstanceInvocation(
            InstanceAccessKind.Instance,
            ThisExpression(),
            stubProcedure.name,
            stubArgs,
            interfaceTarget: stubProcedure,
            functionType: AopUtils.computeFunctionTypeForFunctionNode(
                stubProcedure.function, stubArgs));
        Statement originStatement = shouldReturn
            ? ReturnStatement(resultInstanceInvocation)
            : ExpressionStatement(resultInstanceInvocation);

        if (aopItemInfo.isAfter) {
          bodyStatements
              .addStatement(ExpressionStatement(resultInstanceInvocation));
          bodyStatements.addStatement(injectStatement);
        } else {
          bodyStatements.addStatement(ExpressionStatement(callExpression!));
          bodyStatements.addStatement(originStatement);
        }
        functionNode.body = bodyStatements;
      }
    } else {
      bodyStatements.addStatement(injectStatement);
      functionNode.body = bodyStatements;
    }
  }

  Procedure _createStubProcedure(Name methodName, Procedure referProcedure,
      Statement? bodyStatements, bool shouldReturn) {
    //build stub method nodes.
    final FunctionNode functionNode = FunctionNode(bodyStatements,
        typeParameters: AopUtils.deepCopyASTNodes<TypeParameter>(
            referProcedure.function.typeParameters),
        positionalParameters: referProcedure.function.positionalParameters,
        namedParameters: referProcedure.function.namedParameters,
        requiredParameterCount: referProcedure.function.requiredParameterCount,
        returnType: shouldReturn
            ? AopUtils.deepCopyASTNode(referProcedure.function.returnType)
            : const VoidType(),
        asyncMarker: referProcedure.function.asyncMarker,
        dartAsyncMarker: referProcedure.function.dartAsyncMarker);
    final Procedure procedure = Procedure(
      Name(methodName.text, methodName.library),
      ProcedureKind.Method,
      functionNode,
      isStatic: referProcedure.isStatic,
      fileUri: referProcedure.fileUri,
      stubKind: referProcedure.stubKind,
      stubTarget: referProcedure.stubTarget,
    );

    procedure.fileOffset = referProcedure.fileOffset;
    procedure.fileEndOffset = referProcedure.fileEndOffset;
    procedure.fileStartOffset = referProcedure.fileStartOffset;
    AopUtils.manipulatedProcedureSet.add(referProcedure);
    return procedure;
  }
}
