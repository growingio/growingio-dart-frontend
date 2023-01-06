/// <p>
///
/// @author cpacm 2023/01/06

import 'package:growingio_aspectd_frontend/src/aop/aop_tranform_utils.dart';
import 'package:kernel/ast.dart';
import 'package:kernel/type_algebra.dart';

import 'aop_iteminfo.dart';

class GrowingIOSuperInjectMethodTransformer extends RecursiveVisitor {
  GrowingIOSuperInjectMethodTransformer(this.procedure, this.aopItemInfo);
  final Procedure procedure;
  final GrowingioAopInfo aopItemInfo;

  @override
  void visitBlock(Block node) {
    if (node.parent != null && node.parent is FunctionNode) {
      Procedure stubProcedure = _createStubProcedureAndInsert(procedure);
      final Procedure aopProcedure = aopItemInfo.member as Procedure;
      bool shouldReturn = procedure.function.returnType is! VoidType;
      //check aop member if it is legal
      // if (aopItemInfo.isAfter) {
      //   bool shouldAopReturn = aopProcedure.function.returnType is! VoidType;
      //   if (shouldAopReturn != shouldReturn) {
      //     print(
      //         "GrowingIO AOP Error: Inject Method ReturnType different with Original Method ReturnType");
      //     return;
      //   }
      // }

      var functionNode = node.parent as FunctionNode;
      var newBlock = Block(<Statement>[]);

      /// call stubProcedure
      InstanceInvocation stubInstanceInvocation = InstanceInvocation(
          InstanceAccessKind.Instance,
          ThisExpression(),
          stubProcedure.name,
          AopUtils.argumentsFromFunctionNode(stubProcedure.function),
          interfaceTarget: stubProcedure,
          functionType: (stubProcedure.getterType) as FunctionType);

      if (shouldReturn) {
        // final gioResult = this.gio_stub_method();
        final VariableDeclaration variable = VariableDeclaration("gioResult",
            initializer: stubInstanceInvocation, isFinal: true);
        Statement? injectStatement;
        var generateExpression = _generateAopExpression(
            functionNode, aopItemInfo.isAfter ? VariableGet(variable) : null);
        bool shouldAopReturn = aopProcedure.function.returnType is! VoidType;
        if (generateExpression != null) {
          injectStatement = shouldAopReturn
              ? ReturnStatement(generateExpression)
              : ExpressionStatement(generateExpression);
        }
        var returnStatement = ReturnStatement(VariableGet(variable));

        if (aopItemInfo.isAfter) {
          newBlock.addStatement(variable);
          if (injectStatement != null) {
            newBlock.addStatement(injectStatement);
            if (!shouldAopReturn) {
              newBlock.addStatement(returnStatement);
            }
          } else {
            newBlock.addStatement(returnStatement);
          }
        } else {
          if (generateExpression != null) {
            injectStatement = ExpressionStatement(generateExpression);
            newBlock.addStatement(injectStatement);
          }
          returnStatement = ReturnStatement(stubInstanceInvocation);
            newBlock.addStatement(returnStatement);
        }
      }else{
        if (aopItemInfo.isAfter) {
          newBlock.addStatement(ExpressionStatement(stubInstanceInvocation));
          var generateExpression = _generateAopExpression(functionNode, null);
          if (generateExpression != null) {
            var injectStatement = ExpressionStatement(generateExpression);
            newBlock.addStatement(injectStatement);
          }
        }else{
          var generateExpression = _generateAopExpression(functionNode, null);
          if (generateExpression != null) {
            var injectStatement = ExpressionStatement(generateExpression);
            newBlock.addStatement(injectStatement);
          }
          newBlock.addStatement(ExpressionStatement(stubInstanceInvocation));
        }
         
      }
      // for(Statement s in newBlock.statements){
      //   print("GrowingIO SuperInject Statement:$s");
      // }
      procedure.function.body = newBlock;
      print("GrowingIO SuperInject FunctionNode:${procedure.function.body}");
    }
  }

  @override
  void visitFunctionNode(FunctionNode node) {
    print("GrowingIO SuperInject visitFunctionNode:${node.parent.toString()}");
    node.visitChildren(this);
  }

  Procedure _createStubProcedureAndInsert(Procedure procedure) {
    Procedure stubProcedure = _createStubProcedure(procedure);
    var parent = procedure.parent;
    if (parent is Library) {
      parent.addProcedure(stubProcedure);
    } else if (parent is Class) {
      parent.addProcedure(stubProcedure);
    }
    return stubProcedure;
  }

  Procedure? _checkHasStubProcedure(Procedure referProcedure, Name stubName) {
    var parent = procedure.parent;
    if (parent is Library) {
      for (Procedure element in parent.procedures) {
        if (element.name.text == stubName.text) {
          return element;
        }
      }
    } else if (parent is Class) {
      for (Procedure element in parent.procedures) {
        if (element.name.text == stubName.text) {
          return element;
        }
      }
    }
    return null;
  }

  Procedure _createStubProcedure(Procedure referProcedure) {
    final stubKey = AopUtils.getOnlyStubMethodName(referProcedure.name.text);
    final stubName = Name(stubKey, referProcedure.name.library);
    var stubProcedure = _checkHasStubProcedure(referProcedure, stubName);
    if (stubProcedure != null) {
      return stubProcedure;
    }
    final Statement? bodyStatements = referProcedure.function.body;

    //build stub method nodes.
    final FunctionNode functionNode = FunctionNode(bodyStatements,
        typeParameters: referProcedure.function.typeParameters,
        positionalParameters: referProcedure.function.positionalParameters,
        namedParameters: referProcedure.function.namedParameters,
        requiredParameterCount: referProcedure.function.requiredParameterCount,
        returnType: referProcedure.function.returnType,
        asyncMarker: referProcedure.function.asyncMarker,
        dartAsyncMarker: referProcedure.function.dartAsyncMarker);

    final Procedure procedure = Procedure(
      stubName,
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
    //print("GrowingIO SuperInject stubProcedure:${procedure.name.text} ${procedure.function.body}");
    return procedure;
  }

  ConstructorInvocation _createPointCutConstructor(Expression targetExpression,
      {Expression? paramExpression}) {
    final Arguments pointCutConstructorArguments = Arguments.empty();
    pointCutConstructorArguments.positional.add(targetExpression);

    if (paramExpression != null) {
      NamedExpression namedExpression = NamedExpression(
          AopUtils.kAopAnnotationClassPointCutResult, paramExpression);
      pointCutConstructorArguments.named.add(namedExpression);
    }

    final ConstructorInvocation pointCutConstructorInvocation =
        ConstructorInvocation(AopUtils.pointCutProceedClass!.constructors.first,
            pointCutConstructorArguments);
    return pointCutConstructorInvocation;
  }

  Expression? _generateAopExpression(
      FunctionNode functionNode, Expression? paramExpression) {
    Expression? callExpression;
    if (aopItemInfo.member is Procedure) {
      final Procedure procedure = aopItemInfo.member as Procedure;
      Arguments arguments = AopUtils.argumentsFromFunctionNode(functionNode);
      Arguments injectArgs =
          AopUtils.argumentsFromFunctionNode(procedure.function);
      if (injectArgs.positional.isNotEmpty) {
        int addition = 1;
        injectArgs.positional[0] = _createPointCutConstructor(ThisExpression(),
            paramExpression: paramExpression);
        if (injectArgs.positional.length >
            arguments.positional.length + addition) {
          print(
              "Error: Inject Method Params length more than Target Method Params");
          return null;
        }

        // map target method params into inject method.
        // include named expression
        for (int i = addition; i < injectArgs.positional.length; i++) {
          injectArgs.positional[i] = arguments.positional[i - addition];
        }
        for (int i = 0; i < injectArgs.named.length; i++) {
          injectArgs.named[i] = arguments.named[i];
        }

        //print("GrowingIO SuperInject args: " + injectArgs.toString());
      }

      if (procedure.isStatic) {
        callExpression =
            StaticInvocation(aopItemInfo.member as Procedure, injectArgs);
      } else {
        // first, call constructor
        final Class aopItemMemberCls = aopItemInfo.member.parent as Class;
        final ConstructorInvocation redirectConstructorInvocation =
            ConstructorInvocation.byReference(
                aopItemMemberCls.constructors.first.reference,
                Arguments.empty());

        // then,call inject method.
        callExpression = InstanceInvocation(InstanceAccessKind.Instance,
            redirectConstructorInvocation, aopItemInfo.member.name, injectArgs,
            interfaceTarget: aopItemInfo.member as Procedure,
            functionType:
                (aopItemInfo.member as Procedure).getterType as FunctionType);

        //print("GrowingIO SuperInject expression:  " + callExpression.toString());
      }

      return callExpression;
    }
    return null;
  }
}
