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

@pragma('vm:entry-point')
class Inject {
  /// Indicating which dart file to operate on.
  final String importUri;

  /// Indicating which dart class to operate on.
  final String clsName;

  /// Indicating which dart method to operate on.
  final String methodName;

  /// Indicating whether those specification above should be regarded as
  /// regex expressions.
  final bool isRegex;

  final bool isStatic;

  /// When set to true, you need to ensure that the type returned by the method is consistent with the returned type of the hook method.
  final bool isAfter;

  final int injectType; //0：inject,1:superInject

  @pragma('vm:entry-point')
  const Inject(this.importUri, this.clsName, this.methodName,
      {this.isRegex = false, this.isStatic = false, this.isAfter = false, this.injectType = 0});
}

@pragma('vm:entry-point')
class PointCut {
  final dynamic target;
  dynamic result;

  @pragma('vm:entry-point')
  PointCut(this.target, {this.result});
}
