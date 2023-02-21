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

import 'dart:developer';
import 'package:kernel/ast.dart';

class AopUtils {
  AopUtils();

  static String kAopAnnotationClassPointCut = 'PointCut';
  static String kAopAnnotationClassPointCutResult = 'result';
  static String kAopAnnotationClassInject = 'Inject';
  static String kAopAnnotationImportUri = 'importUri';
  static String kAopAnnotationClsName = 'clsName';
  static String kAopAnnotationMethodName = 'methodName';
  static String kAopAnnotationIsRegex = 'isRegex';
  static String kAopAnnotationIsStatic = 'isStatic';
  static String kAopAnnotationIsAfter = 'isAfter';
  static String kAopAnnotationInjectType= 'injectType';
  static String kAopAnnotationMethodPrefix = 'gio_stub_';
  static int kAopAnnotationMethodIndex = 0;

  static const String kAopGrowingInjectImpl =
      r'^package:[a-zA-Z_]*/growingio_inject_impl.dart$';
  static const String kAopGrowingInjectAnnotation =
      r'^package:[a-zA-Z_]*/growingio_inject_annotation.dart$';
  static Set<Procedure> manipulatedProcedureSet = {};

  static Class? pointCutProceedClass;

  static String getOnlyStubMethodName(String methodName){
    return '$kAopAnnotationMethodPrefix$methodName';
  }

  static bool getAopModeByNameAndImportUri(String name, String importUri) {
    if (RegExp(AopUtils.kAopGrowingInjectAnnotation).hasMatch(importUri)) {
      if (name == kAopAnnotationClassInject) {
        return true;
      }
    }
    return false;
  }

  //Generic Operation
  static void insertLibraryDependency(Library library, Library dependLibrary) {
    for (LibraryDependency dependency in library.dependencies) {
      if (dependency.importedLibraryReference.node == dependLibrary) {
        return;
      }
    }
    library.dependencies.add(LibraryDependency.import(dependLibrary));
  }

  static Arguments argumentsFromFunctionNode(FunctionNode functionNode) {
    final List<Expression> positional = <Expression>[];
    final List<NamedExpression> named = <NamedExpression>[];
    for (VariableDeclaration variableDeclaration
        in functionNode.positionalParameters) {
      positional.add(VariableGet(variableDeclaration));
    }
    for (VariableDeclaration variableDeclaration
        in functionNode.namedParameters) {
      named.add(NamedExpression(
          variableDeclaration.name!, VariableGet(variableDeclaration)));
    }
    return Arguments(positional, named: named);
  }

  static FunctionType computeFunctionTypeForFunctionNode(
      FunctionNode functionNode, Arguments arguments) {
    final List<DartType> positionDartType = [];
    arguments.positional.forEach((element) {
      if (element is AsExpression) {
        positionDartType.add(element.type);
      }
    });

    final List<NamedType> namedDartType = [];
    arguments.named.forEach((element) {
      Expression value = element.value;
      if (value is AsExpression) {
        namedDartType.add(NamedType(element.name, value.type));
      }
    });
    FunctionType functionType = FunctionType(
        positionDartType,
        deepCopyASTNode(functionNode.returnType,
            isReturnType: true, ignoreGenerics: true),
        Nullability.legacy,
        namedParameters: namedDartType,
        typeParameters: [],
        requiredParameterCount: functionNode.requiredParameterCount);
    return functionType;
  }

  static Field? findFieldForClassWithName(Class cls, String fieldName) {
    for (Field field in cls.fields) {
      if (field.name.text == fieldName) {
        return field;
      }
    }
    return null;
  }

  static bool isAsyncFunctionNode(FunctionNode functionNode) {
    return functionNode.dartAsyncMarker == AsyncMarker.Async ||
        functionNode.dartAsyncMarker == AsyncMarker.AsyncStar;
  }

  static Node? getNodeToVisitRecursively(Object statement) {
    if (statement is FunctionDeclaration) {
      return statement.function;
    }
    if (statement is LabeledStatement) {
      return statement.body;
    }
    if (statement is IfStatement) {
      return statement.then;
    }
    if (statement is ForInStatement) {
      return statement.body;
    }
    if (statement is ForStatement) {
      return statement.body;
    }
    return null;
  }

  static List<T> deepCopyASTNodes<T>(List<T> nodes,
      {bool ignoreGeneric = false}) {
    final List<T> newNodes = <T>[];
    for (T node in nodes) {
      final dynamic newNode =
          deepCopyASTNode(node, ignoreGenerics: ignoreGeneric);
      if (newNode != null) {
        newNodes.add(newNode);
      }
    }
    return newNodes;
  }

  static dynamic deepCopyASTNode(dynamic node,
      {bool isReturnType = false, bool ignoreGenerics = false}) {
    if (node is TypeParameter) {
      if (ignoreGenerics)
        return TypeParameter(node.name, node.bound, node.defaultType);
    }
    if (node is VariableDeclaration) {
      return VariableDeclaration(
        node.name,
        initializer: node.initializer,
        type: deepCopyASTNode(node.type),
        flags: node.flags,
        isFinal: node.isFinal,
        isConst: node.isConst,
        isInitializingFormal: node.isInitializingFormal,
        isCovariantByDeclaration: node.isCovariantByDeclaration,
        isLate: node.isLate,
        isRequired: node.isRequired,
        isLowered: node.isLowered,
      );
    }
    if (node is TypeParameterType) {
      if (isReturnType || ignoreGenerics) {
        return const DynamicType();
      }
      return TypeParameterType(
          deepCopyASTNode(node.parameter), node.nullability);
    }
    if (node is FunctionType) {
      return FunctionType(
          deepCopyASTNodes(node.positionalParameters),
          deepCopyASTNode(node.returnType, isReturnType: true),
          Nullability.legacy,
          namedParameters: deepCopyASTNodes(node.namedParameters),
          typeParameters: deepCopyASTNodes(node.typeParameters),
          requiredParameterCount: node.requiredParameterCount);
    }
    if (node is TypedefType) {
      return TypedefType(node.typedefNode, Nullability.legacy,
          deepCopyASTNodes(node.typeArguments, ignoreGeneric: ignoreGenerics));
    }

    if (node is InterfaceType) {
      return InterfaceType(node.classNode, node.declaredNullability,
          deepCopyASTNodes(node.typeArguments, ignoreGeneric: ignoreGenerics));
    }
    return node;
  }
}

class Logger {
  static void d(String log) {
    _debugLog(log);
  }

  static void e(String msg, {StackTrace? stackTrace, Object? error}) {
    log(msg,
        name: "GrowingIO TRACK: ${DateTime.now().toLocal().toString()}",
        error: error,
        stackTrace: stackTrace);
  }

  static void p(String msg) {
    assert(() {
      print(msg);
      return true;
    }());
  }

  static void _debugLog(String msg, {StackTrace? stackTrace, Object? error}) {
    assert(() {
      log(msg,
          name: "GrowingIO TRACK",
          error: error,
          stackTrace: stackTrace);
      return true;
    }());
  }
}
