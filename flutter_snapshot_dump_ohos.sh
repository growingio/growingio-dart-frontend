#!/bin/bash

# 用于 HarmonyOS 特制版 Flutter SDK 的 SNAPSHOT 打包命令。
#
# 特制版 Flutter SDK 的 Dart VM 由 OpenHarmony 引擎补丁重新构建，snapshot 版本哈希与上游
# 不一致，因此必须使用特制版 SDK 内置的 dart 二进制进行构建（无需编译 engine）；同时
# 3.22+ 的 flutter_tools 实际加载的是 AOT 版 frontend_server_aot.dart.snapshot（由
# dartaotruntime 运行），本脚本会同时产出 JIT 与 AOT 两个版本。
#
# 请先按照以下步骤设置路径：
# 1. 设置 Dart 源码路径: DART_SOURCE_DIR=<PATH>
#    (https://github.com/dart-lang/sdk 的 git checkout)
# 2. 设置特制版 Flutter SDK 路径: OHOS_FLUTTER_SDK=<PATH>
#    (https://gitee.com/openharmony-sig/flutter_flutter 的 git checkout，
#     且已运行过 flutter doctor 完成 bin/cache 初始化)
# 3. 在当前位置使用命令行运行:
#    ./flutter_snapshot_dump_ohos.sh <flutter_version> [dart_version] [engine_branch]
#    比如 ./flutter_snapshot_dump_ohos.sh 3.22.1
#         ./flutter_snapshot_dump_ohos.sh 3.22.1 3.4.0 oh-3.22.0
#    - dart_version 缺省时读取特制版 SDK bin/cache/dart-sdk/version
#    - engine_branch 缺省为 oh-<major.minor>.0，用于从 gitee 引擎仓库下载 dart 补丁
#
# 产物（可以使用 git status 查看是否已经生成新的 SNAPSHOT）：
#   lib/flutter_frontend_server/frontend_server.dart.snapshot            (JIT)
#   lib/flutter_frontend_server/<host>/frontend_server_aot.dart.snapshot (AOT)
#
# 集成方式（替换特制版 Flutter SDK 内文件后 flutter clean）：
#   <OHOS_FLUTTER_SDK>/bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot  <- AOT（关键，工具链实际加载）
#   <OHOS_FLUTTER_SDK>/bin/cache/dart-sdk/bin/snapshots/frontend_server.dart.snapshot      <- JIT
#   <OHOS_FLUTTER_SDK>/bin/cache/artifacts/engine/darwin-x64/frontend_server.dart.snapshot <- JIT
#
# 验证注入是否成功（反编译 app.dill 检查 GrowingClickInject/GrowingPageInject 调用点）：
#   dart --packages=<本工程>/.dart_tool/package_config.json \
#     $DART_SOURCE_DIR/pkg/vm/bin/dump_kernel.dart app.dill out.dill.txt
#
# 注意：pkg/vm 的 FFI ABI 列表必须与特制版引擎 platform dill 中 dart:ffi 的 Abi 完全一致。
# 脚本会在 gitee 补丁缺失时自动补齐 ohosX64；若后续版本构建 App 时报
# "Type XXX has no mapping for ABI"，请用 dump_kernel.dart 反编译
# <OHOS_FLUTTER_SDK>/bin/cache/artifacts/engine/common/flutter_patched_sdk/platform_strong.dill
# 中的 dart:ffi Abi 定义并与 pkg/vm/lib/modular/transformations/ffi/abi.dart 对齐。

set -e

DART_SOURCE_DIR="${DART_SOURCE_DIR:?请设置 DART_SOURCE_DIR 为 dart-lang/sdk 源码路径}"
OHOS_FLUTTER_SDK="${OHOS_FLUTTER_SDK:?请设置 OHOS_FLUTTER_SDK 为特制版 Flutter SDK 路径}"

if [ $# -lt 1 ] || [ $# -gt 3 ]; then
    echo "[flutter_snapshot_dump_ohos] 用法: $0 <flutter_version> [dart_version] [engine_branch]"
    exit 1
fi

source_dir=$PWD
flutter_version="$1"
if ! [[ "$flutter_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[flutter_snapshot_dump_ohos] Flutter版本号格式错误: $flutter_version"
    exit 1
fi

dart_bin="$OHOS_FLUTTER_SDK/bin/cache/dart-sdk/bin/dart"
if [ ! -x "$dart_bin" ]; then
    echo "[flutter_snapshot_dump_ohos] 未找到特制版 dart: $dart_bin"
    echo "[flutter_snapshot_dump_ohos] 请先在特制版 SDK 下运行 flutter doctor 完成 bin/cache 初始化"
    exit 1
fi

dart_version="$2"
if [ -z "$dart_version" ]; then
    dart_version=$(sed -En 's/^([0-9]+\.[0-9]+\.[0-9]+).*/\1/p' "$OHOS_FLUTTER_SDK/bin/cache/dart-sdk/version")
    echo "[flutter_snapshot_dump_ohos] dart version: $dart_version"
fi
if ! [[ "$dart_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[flutter_snapshot_dump_ohos] Dart版本号格式错误: $dart_version"
    exit 1
fi

engine_branch="$3"
if [ -z "$engine_branch" ]; then
    engine_branch="oh-$(echo "$flutter_version" | cut -d. -f1-2).0"
fi
echo "[flutter_snapshot_dump_ohos] engine branch: $engine_branch"

echo "[flutter_snapshot_dump_ohos] start checkout dart tag in $dart_version"
cd "$DART_SOURCE_DIR"
git checkout -f "$dart_version" 2>/dev/null || { git fetch --tags && git checkout -f "$dart_version"; }
git clean -fdq

echo "[flutter_snapshot_dump_ohos] apply dart_flutter.patch (GrowingIO AOP)"
git apply "$source_dir/dart_flutter.patch"

ohos_patch_url="https://gitee.com/openharmony-sig/flutter_engine/raw/$engine_branch/attachment/repos/dart.$dart_version.patch"
ohos_patch_file=$(mktemp -t dart_ohos_patch)
echo "[flutter_snapshot_dump_ohos] download ohos dart patch: $ohos_patch_url"
if ! curl -fsSL -o "$ohos_patch_file" "$ohos_patch_url"; then
    echo "[flutter_snapshot_dump_ohos] 下载失败，请到 https://gitee.com/openharmony-sig/flutter_engine 的 attachment/repos 目录确认补丁文件名与分支名后，通过第三个参数指定 engine_branch"
    exit 1
fi

echo "[flutter_snapshot_dump_ohos] apply ohos dart patch"
git apply "$ohos_patch_file"

echo "[flutter_snapshot_dump_ohos] align pkg/vm ffi abi with ohos platform dill"
python3 - "$DART_SOURCE_DIR/pkg/vm/lib/modular/transformations/ffi/abi.dart" <<'PYEOF'
import sys

path = sys.argv[1]
with open(path) as f:
    s = f.read()

if "ohosArm64" not in s:
    sys.exit("[flutter_snapshot_dump_ohos] abi.dart 中没有 ohos ABI，ohos dart 补丁可能未生效")

# 特制版引擎 platform dill 的 dart:ffi 定义了 ohosArm/ohosArm64/ohosX64 三个 ABI，
# gitee 引擎仓库的 dart 补丁历史版本缺少 ohosX64，缺失时会报
# "Type IntPtr has no mapping for ABI"，此处自动补齐
if "ohosX64" in s:
    print("[flutter_snapshot_dump_ohos] ohosX64 已存在，跳过")
    sys.exit(0)

edits = [
    ("  static const ohosArm64 = _ohosArm64;\n",
     "  static const ohosArm64 = _ohosArm64;\n\n  static const ohosX64 = _ohosX64;\n"),
    ("    ohosArm,\n    ohosArm64,\n",
     "    ohosArm,\n    ohosArm64,\n    ohosX64,\n"),
    ("  static const _ohosArm64 = Abi._(_Architecture.arm64, _OS.ohos);\n",
     "  static const _ohosArm64 = Abi._(_Architecture.arm64, _OS.ohos);\n"
     "  static const _ohosX64 = Abi._(_Architecture.x64, _OS.ohos);\n"),
    ("  Abi.ohosArm64: 'ohosArm64',\n",
     "  Abi.ohosArm64: 'ohosArm64',\n  Abi.ohosX64: 'ohosX64',\n"),
    ("  Abi.ohosArm64: _wordSize64,\n",
     "  Abi.ohosArm64: _wordSize64,\n  Abi.ohosX64: _wordSize64,\n"),
]
for old, new in edits:
    if s.count(old) != 1:
        sys.exit(f"[flutter_snapshot_dump_ohos] abi.dart 结构与预期不符，请手工对齐: {old!r}")
    s = s.replace(old, new)

with open(path, "w") as f:
    f.write(s)
print("[flutter_snapshot_dump_ohos] 已补齐 ohosX64")
PYEOF

echo "[flutter_snapshot_dump_ohos] dart pub get"
cd "$source_dir"
ln -sfn "$DART_SOURCE_DIR" sdk
"$dart_bin" pub get

case "$(uname -s)-$(uname -m)" in
    Darwin-arm64) host_dir="darwin_arm64" ;;
    Darwin-x86_64) host_dir="darwin_x64" ;;
    Linux-*) host_dir="linux_x64" ;;
    *) host_dir="windows_x64" ;;
esac

echo "[flutter_snapshot_dump_ohos] generate frontend_server.dart.snapshot (JIT)"
cd lib/flutter_frontend_server
"$dart_bin" --deterministic --snapshot=frontend_server.dart.snapshot frontend_server_starter.dart

echo "[flutter_snapshot_dump_ohos] generate $host_dir/frontend_server_aot.dart.snapshot (AOT)"
mkdir -p "$host_dir"
"$dart_bin" compile aot-snapshot -o "$host_dir/frontend_server_aot.dart.snapshot" frontend_server_starter.dart

echo "[flutter_snapshot_dump_ohos] COMPLETE!!!"
echo ""
echo "请将产物替换到特制版 Flutter SDK 后执行 flutter clean："
echo "  cp lib/flutter_frontend_server/$host_dir/frontend_server_aot.dart.snapshot $OHOS_FLUTTER_SDK/bin/cache/dart-sdk/bin/snapshots/frontend_server_aot.dart.snapshot"
echo "  cp lib/flutter_frontend_server/frontend_server.dart.snapshot $OHOS_FLUTTER_SDK/bin/cache/dart-sdk/bin/snapshots/frontend_server.dart.snapshot"
echo "  cp lib/flutter_frontend_server/frontend_server.dart.snapshot $OHOS_FLUTTER_SDK/bin/cache/artifacts/engine/darwin-x64/frontend_server.dart.snapshot"
