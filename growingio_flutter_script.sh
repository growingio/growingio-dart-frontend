#!/bin/bash

loggerD() {
	echo "\033[36m$1 \033[0m"
}

loggerE() {
	echo "\033[1;41;33m$1 \033[0m"
}

checkFlutterStatus() {
	cd $FLUTTER_PATH
	if [ -n "$(git status --porcelain)" ]; then 
	    loggerE "Flutter sdk is modified, do you want to reset it?" 
	    read -p  "Enter [y/n]" input
	    case $input in
            [yY]*)
                comit_id=$(git rev-parse HEAD)
                git reset --hard $comit_id
                rm -rf bin/cache
                flutter --version
                ;;
            [nN]*)
                loggerD "You can reset your flutter sdk manually, then run this shell script again"
                exit 1
                ;;
            *)
                loggerD "Please enter yes or no"
                exit
                ;;
	    esac
	fi
	cd -
}

DART_FRONTEND_NAME="growingio-dart-frontend"
DART_FRONTEND_SNAPSHOT="$DART_FRONTEND_NAME/lib/flutter_frontend_server/frontend_server.dart.snapshot"
DART_FRONTEND_REPOSITORY="https://github.com/growingio/growingio-dart-frontend.git"
FLUTTER_PATH=$(which flutter)
FLUTTER_PATH=${FLUTTER_PATH#flutter is }
FLUTTER_PATH=${FLUTTER_PATH%/bin/flutter}
loggerD "Flutter path is $FLUTTER_PATH"
checkFlutterStatus

os=$(uname -a)
OS_PLATFORM_DIR_NAME="darwin-x64" 
if [[ $os =~ 'Msys' ]] || [[ $os =~ 'msys' ]]; then
    OS_PLATFORM_DIR_NAME="windows-x64"
elif [[ $os =~ 'Darwin' ]]; then 
    OS_PLATFORM_DIR_NAME="darwin-x64"
else
    OS_PLATFORM_DIR_NAME="linux-x64"
fi
ARTIFACTS_SNAPSHOT_PATH="$FLUTTER_PATH/bin/cache/artifacts/engine/$OS_PLATFORM_DIR_NAME"
DART_SDK_SNAPSHOT_PATH="$FLUTTER_PATH/bin/cache/dart-sdk/bin/snapshots"
FLUTTER_VERSION=$(flutter --version | egrep -o "Flutter \d+\.\d+\.\d+")
FLUTTER_VERSION=${FLUTTER_VERSION#Flutter }
loggerD "Flutter version is $FLUTTER_VERSION"

flutter doctor

rm -rf $DART_FRONTEND_NAME

loggerD "Clone growingio dart frontend repository"
git clone -b $FLUTTER_VERSION $DART_FRONTEND_REPOSITORY

if [ ! -f "./$DART_FRONTEND_SNAPSHOT" ]; then
	loggerE "git clone error，check network connection please"
	exit 1
fi

loggerD "Replace frontend_server.dart.snapshot"
if [ ! -e "${ARTIFACTS_SNAPSHOT_PATH}/frontend_server.dart.snapshot$FLUTTER_VERSION" ]; then
  mv "${ARTIFACTS_SNAPSHOT_PATH}/frontend_server.dart.snapshot" "${ARTIFACTS_SNAPSHOT_PATH}/frontend_server.dart.snapshot$FLUTTER_VERSION"
fi
cp "./$DART_FRONTEND_SNAPSHOT"  $ARTIFACTS_SNAPSHOT_PATH
if [[ $FLUTTER_VERSION = "3.0.0" || $FLUTTER_VERSION > '3.0.0' ]]; then
	if [ ! -e "${DART_SDK_SNAPSHOT_PATH}/frontend_server.dart.snapshot$FLUTTER_VERSION" ]; then
	  mv "${DART_SDK_SNAPSHOT_PATH}/frontend_server.dart.snapshot" "${DART_SDK_SNAPSHOT_PATH}/frontend_server.dart.snapshot$FLUTTER_VERSION"
	fi
	cp "./$DART_FRONTEND_SNAPSHOT"  $DART_SDK_SNAPSHOT_PATH
fi
loggerD "Replace success!"

rm -rf $DART_FRONTEND_NAME