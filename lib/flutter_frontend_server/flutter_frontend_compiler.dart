// Copyright (c) 2022, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE.md file.

import 'dart:async';

import 'package:args/args.dart';

import 'package:frontend_server/frontend_server.dart' as frontend
    show
        BinaryPrinterFactory,
        FrontendCompiler,
        CompilerInterface,
        ProgramTransformer;
import 'package:vm/incremental_compiler.dart';
import 'package:vm/modular/target/flutter.dart';

import '../src/aop/aop_transformer_wrapper.dart';

/// 原 FrontendCompiler proxy，用于添加flutter的transformer
class FlutterFrontendCompiler implements frontend.CompilerInterface {
  final frontend.CompilerInterface _compiler;

  final AopWrapperTransformer aspectdAopTransformer = AopWrapperTransformer();

  FlutterFrontendCompiler(StringSink? outputStream,
      {frontend.BinaryPrinterFactory? printerFactory,
      frontend.ProgramTransformer? transformer,
      bool? unsafePackageSerialization,
      bool incrementalSerialization = true,
      bool useDebuggerModuleNames = false,
      bool emitDebugMetadata = false,
      bool emitDebugSymbols = false,
      bool canaryFeatures = false,})
      : _compiler = frontend.FrontendCompiler(outputStream,
            printerFactory: printerFactory,
            transformer: transformer,
            unsafePackageSerialization: unsafePackageSerialization,
            incrementalSerialization: incrementalSerialization,
            useDebuggerModuleNames: useDebuggerModuleNames,
            emitDebugMetadata: emitDebugMetadata,
            emitDebugSymbols: emitDebugSymbols,
            canaryFeatures: canaryFeatures);

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
  Future<bool> compileNativeAssetsOnly(
    ArgResults options, {
    IncrementalCompiler? generator,
  }) async {
    return _compiler.compileNativeAssetsOnly(options, generator: generator);
  }

  @override
  Future<bool> setNativeAssets(String nativeAssets) {
    return _compiler.setNativeAssets(nativeAssets);
  }

  @override
  Future<void> recompileDelta({String? entryPoint}) async {
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
  Future<void> compileExpression(
      String expression,
      List<String> definitions,
      List<String> definitionTypes,
      List<String> typeDefinitions,
      List<String> typeBounds,
      List<String> typeDefaults,
      String libraryUri,
      String? klass,
      String? method,
      int offset,
      String? scriptUri,
      bool isStatic) {
    return _compiler.compileExpression(
        expression,
        definitions,
        definitionTypes,
        typeDefinitions,
        typeBounds,
        typeDefaults,
        libraryUri,
        klass,
        method,
        offset,
        scriptUri,
        isStatic);
  }

  @override
  Future<void> compileExpressionToJs(
      String libraryUri,
      String? scriptUri,
      int line,
      int column,
      Map<String, String> jsModules,
      Map<String, String> jsFrameValues,
      String moduleName,
      String expression) {
    return _compiler.compileExpressionToJs(libraryUri, scriptUri, line, column, jsModules,
        jsFrameValues, moduleName, expression);
  }

  @override
  void reportError(String msg) {
    _compiler.reportError(msg);
  }
}
