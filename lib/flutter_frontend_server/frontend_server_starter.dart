// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library frontend_server;

import 'dart:async';
import 'dart:io';

import 'starter.dart';

Future<Null> main(List<String> args) async {
  exitCode = await starter(args);
  if (exitCode != 0) {
    exit(exitCode);
  }
}