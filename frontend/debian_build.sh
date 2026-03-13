#!/bin/bash
set -e
apt-get update
apt-get install -y curl git unzip xz-utils libglu1-mesa ca-certificates
git config --global --add safe.directory '*'
curl -o flutter_windows.zip https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.0-stable.tar.xz
mkdir -p /opt/flutter
tar xf flutter_windows.zip -C /opt/flutter --strip-components=1
export PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:$PATH"
flutter config --enable-web || true
flutter create --platforms=web .
# Clean first, this might help if there's corrupted lock files
flutter clean || true
rm -rf pubspec.lock
flutter pub get
flutter build web --release
