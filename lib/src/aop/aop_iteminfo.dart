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

import 'package:kernel/ast.dart';

class GrowingioAopInfo {
  GrowingioAopInfo(this.importUri, this.clsName, this.methodName, this.member,
      {this.isStatic = false,
      this.isRegex = false,
      this.isAfter = false,
      this.gioInjectType = 0});//0:inject;1:SuperInject

  final String importUri;
  final String clsName;
  final String methodName;
  final Member member;
  final bool isStatic;
  final bool isRegex;
  final bool isAfter;
  final int gioInjectType;
}
