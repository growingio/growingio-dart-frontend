import 'dart:convert';
import 'dart:ffi';
import 'dart:mirrors';

import 'package:kernel/ast.dart';

/// <p>
///
/// @author cpacm 2022/12/12
import 'aop_iteminfo.dart';

class AopUtils {
  AopUtils();

  static String kAopAnnotationClassInject = 'Inject';
  static String kAopAnnotationImportUri = 'importUri';
  static String kAopAnnotationClsName = 'clsName';
  static String kAopAnnotationMethodName = 'methodName';
  static String kAopAnnotationIsRegex = 'isRegex';
  static String kAopAnnotationIsStatic = 'isStatic';

  static const String GROWINGIO_INJECT_IMPL =
      "package:growingio_sdk_flutter/growingio_inject_impl.dart";
  static const String GROWINGIO_INJECT_ANNOTATION =
      "package:growingio_sdk_flutter/growingio_inject_annotation.dart";
  static Set<Procedure> manipulatedProcedureSet = {};

  static bool getAopModeByNameAndImportUri(String name, String importUri) {
    if (name == kAopAnnotationClassInject &&
        importUri == GROWINGIO_INJECT_ANNOTATION) {
      return true;
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
        Nullability.nonNullable,
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
    return node;
  }
}
