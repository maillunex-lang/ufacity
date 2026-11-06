#!/bin/bash
set -eu
GODOT_VERSION=4.3
TEMPLATE_DIR="/root/.local/share/godot/export_templates/${GODOT_VERSION}.stable"
mkdir -p "$TEMPLATE_DIR"
if [ ! -f "$TEMPLATE_DIR/android_debug.apk" ]; then
  echo "export templates missing, downloading"
  wget -q "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_export_templates.tpz" -O /tmp/templates.tpz
  rm -rf /tmp/godot-templates
  unzip -q /tmp/templates.tpz -d /tmp/godot-templates
  cp -a /tmp/godot-templates/templates/. "$TEMPLATE_DIR/"
fi
ls -lh "$TEMPLATE_DIR"/android_debug.apk

if [ ! -f /workspace/client/android/build/build.gradle ]; then
  rm -rf /tmp/android-src
  mkdir -p /tmp/android-src /workspace/client/android
  unzip -q "$TEMPLATE_DIR/android_source.zip" -d /tmp/android-src
  if [ -f /tmp/android-src/build/build.gradle ]; then
    cp -a /tmp/android-src/build /workspace/client/android/build
  else
    cp -a /tmp/android-src /workspace/client/android/build
  fi
fi
test -f /workspace/client/android/build/build.gradle

yes | sdkmanager --licenses >/tmp/sdk-licenses.txt || true
sdkmanager "build-tools;34.0.0" "platforms;android-34"
find /usr/lib/android-sdk/build-tools -name apksigner -o -name apksigner.bat | head

if [ ! -f /root/debug.keystore ]; then
  keytool -keyalg RSA -genkeypair -alias androiddebugkey -keypass android \
    -keystore /root/debug.keystore -storepass android \
    -dname "CN=Android Debug,O=Android,C=US" -validity 9999
fi

JAVA_BIN="$(readlink -f "$(command -v java)")"
JAVA_HOME="$(dirname "$(dirname "$JAVA_BIN")")"
SDK="/usr/lib/android-sdk"
echo "java=$JAVA_HOME sdk=$SDK"
test -d "$JAVA_HOME/bin"
test -x "$SDK/platform-tools/adb"

mkdir -p /root/.config/godot
cat > /root/.config/godot/editor_settings-4.3.tres << EOF
[gd_resource type="EditorSettings" format=3]

[resource]
export/android/java_sdk_path = "$JAVA_HOME"
export/android/android_sdk_path = "$SDK"
export/android/debug_keystore = "/root/debug.keystore"
export/android/debug_keystore_user = "androiddebugkey"
export/android/debug_keystore_pass = "android"
export/android/force_system_user = false
export/android/shutdown_adb_on_exit = true
EOF

godot --headless --import --quit
godot --headless --verbose --export-debug "Android" /workspace/build/ufacity-debug.apk
test -s /workspace/build/ufacity-debug.apk
ls -lh /workspace/build/ufacity-debug.apk
