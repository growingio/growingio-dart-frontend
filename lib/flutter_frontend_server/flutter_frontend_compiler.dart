// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';
import 'dart:io' hide FileSystemEntity;

import 'package:args/args.dart';

import 'package:frontend_server/frontend_server.dart' as frontend
    show
        BinaryPrinterFactory,
        FrontendCompiler,
        CompilerInterface,
        listenAndCompile,
        argParser,
        usage,
        ProgramTransformer;
import 'package:kernel/ast.dart';
import 'package:path/path.dart' as path;
import 'package:vm/incremental_compiler.dart';
import 'package:vm/target/flutter.dart';

import '../src/aop/aop_transformer_wrapper.dart';

/// 原 FrontendCompiler proxy，用于添加flutter的transformer
class FlutterFrontendCompiler implements frontend.CompilerInterface {
  final frontend.CompilerInterface _compiler;

  final AopWrapperTransformer aspectdAopTransformer = AopWrapperTransformer();

  FlutterFrontendCompiler(StringSink? outputStream,
      {frontend.BinaryPrinterFactory? printerFactory,
      frontend.ProgramTransformer? transformer,
      bool? unsafePackageSerialization,
      bool? incrementalSerialization,
      bool useDebuggerModuleNames = false,
      bool emitDebugMetadata = false,
      bool emitDebugSymbols = false})
      : _compiler = frontend.FrontendCompiler(outputStream,
            printerFactory: printerFactory,
            transformer: transformer,
            useDebuggerModuleNames: useDebuggerModuleNames,
            emitDebugMetadata: emitDebugMetadata,
            unsafePackageSerialization: unsafePackageSerialization);

  @override
  Future<bool> compile(String filename, ArgResults options,
      {IncrementalCompiler? generator}) async {
    if (!FlutterTarget.flutterProgramTransformers
        .contains(aspectdAopTransformer)) {
      FlutterTarget.flutterProgramTransformers.add(aspectdAopTransformer);
    }

    return _compiler.compile(filename, options, generator: generator);
  }

  @override
  Future<Null> recompileDelta({String? entryPoint}) async {
    return _compiler.recompileDelta(entryPoint: entryPoint);
  }

  @override
  void acceptLastDelta() {
    _compiler.acceptLastDelta();
  }

  @override
  Future<void> rejectLastDelta() async {
    return _compiler.rejectLastDelta();
  }

  @override
  void invalidate(Uri uri) {
    _compiler.invalidate(uri);
  }

  @override
  void resetIncrementalCompiler() {
    _compiler.resetIncrementalCompiler();
  }

  @override
  Future<Null> compileExpression(
      String expression,
      List<String> definitions,
      List<String> typeDefinitions,
      String libraryUri,
      String? klass,
      String? method,
      bool isStatic) {
    return _compiler.compileExpression(
        expression,
        definitions,
        typeDefinitions,
        libraryUri,
        klass,
        method,
        isStatic);
  }

  @override
  Future<Null> compileExpressionToJs(
      String libraryUri,
      int line,
      int column,
      Map<String, String> jsModules,
      Map<String, String> jsFrameValues,
      String moduleName,
      String expression) {
    return _compiler.compileExpressionToJs(libraryUri, line, column, jsModules,
        jsFrameValues, moduleName, expression);
  }

  @override
  void reportError(String msg) {
    _compiler.reportError(msg);
  }
}
