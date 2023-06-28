#!/bin/bash

# 用于新版本Flutter的SNAPSHOT打包命令，请先按照以下步骤设置路径：
# 1. 设置 Flutter 源码路径: FLUTTER_SOURCE_DIR=<PATH>
# 2. 设置 Dart 源码路径: DART_SOURCE_DIR=<PATH>
# 3. 在当前位置使用命令行运行: ./flutter_snapshot_dump.sh <flutter_version> [dart_version]
#    比如 ./flutter_snapshot_dump.sh 3.10.5
# 4. 可以使用 git status 查看是否已经生成新的SNAPSHOT

FLUTTER_SOURCE_DIR="/Users/shenliming/Program/flutter"
DART_SOURCE_DIR="/Users/shenliming/Program/dart/sdk"

if  [ $# -ne 1 ] && [ $# -ne 2 ]; then
    echo "[flutter_snapshot_dump] 请输入正确的flutter版本号."
    exit 1
fi

source_dir=$PWD
flutter_version="$1"
if ! [[ "$flutter_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[flutter_snapshot_dump] Flutter版本号格式错误: $flutter_version"
    exit 1
fi


echo "[flutter_snapshot_dump] start checkout flutter tag in $flutter_version"
cd "$FLUTTER_SOURCE_DIR"
git pull
git checkout -f "$flutter_version"


dart_version="$2"
if [ -z "$dart_version" ]; then
	result=$(flutter --version)
	dart_version=$(echo "$result" | sed -En "s/.*Dart ([0-9]+\.[0-9]+\.[0-9]+).*/\1/p")
	echo "[flutter_snapshot_dump] dart version:$dart_version"
fi

if ! [[ "$dart_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "[flutter_snapshot_dump] Dart版本号格式错误: $dart_version"
    exit 1
fi
echo "[flutter_snapshot_dump] start checkout dart tag in $dart_version"
cd "$DART_SOURCE_DIR"
git pull
git checkout -f "$dart_version"

echo "[flutter_snapshot_dump] start cherry-pick diff.patch"
git apply "$source_dir/dart_flutter.patch"

echo "[flutter_snapshot_dump] generate frontend_server.dart.snapshot"
cd "$source_dir"
dart pub get
cd lib/flutter_frontend_server
dart --deterministic --snapshot=frontend_server.dart.snapshot frontend_server_starter.dart
echo "[flutter_snapshot_dump] COMPLETE!!!"

