// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:kernel/kernel.dart' show Component, writeComponentToText;
import 'package:kernel/binary/ast_from_binary.dart'
    show BinaryBuilderWithMetadata;

import 'package:vm/metadata/direct_call.dart' show DirectCallMetadataRepository;
import 'package:vm/metadata/inferred_type.dart'
    show InferredTypeMetadataRepository;
import 'package:vm/metadata/procedure_attributes.dart'
    show ProcedureAttributesMetadataRepository;
import 'package:vm/metadata/table_selector.dart'
    show TableSelectorMetadataRepository;
import 'package:vm/metadata/unboxing_info.dart'
    show UnboxingInfoMetadataRepository;
import 'package:vm/metadata/unreachable.dart'
    show UnreachableNodeMetadataRepository;
import 'package:vm/metadata/call_site_attributes.dart'
    show CallSiteAttributesMetadataRepository;
import 'package:vm/metadata/loading_units.dart'
    show LoadingUnitsMetadataRepository;

final String _usage = '''
Usage: dump_kernel input.dill output.txt
Dumps kernel binary file with VM-specific metadata.
''';

main(List<String> arguments) async {
  
  // if (arguments.length != 2) {
  //   print(_usage);
  //   exit(1);
  // }

  // final input = arguments[0];
  // final output = arguments[1];

  final input = "app.dill";
  final output = "out.dill.txt";

  final component = Component();

  // Register VM-specific metadata.
  component.addMetadataRepository(DirectCallMetadataRepository());
  component.addMetadataRepository(InferredTypeMetadataRepository());
  component.addMetadataRepository(ProcedureAttributesMetadataRepository());
  component.addMetadataRepository(TableSelectorMetadataRepository());
  component.addMetadataRepository(UnboxingInfoMetadataRepository());
  component.addMetadataRepository(UnreachableNodeMetadataRepository());
  component.addMetadataRepository(CallSiteAttributesMetadataRepository());
  component.addMetadataRepository(LoadingUnitsMetadataRepository());

  final List<int> bytes = File(input).readAsBytesSync();
  BinaryBuilderWithMetadata(bytes).readComponent(component);

  writeComponentToText(component, path: output, showMetadata: true);
}
