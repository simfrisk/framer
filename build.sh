#!/bin/bash
set -e

APP="Framer.app"
CONTENTS="$APP/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building $APP..."

# Clean previous build
rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

# Compile
swiftc -O Framer.swift -o "$MACOS/Framer"

# Copy plist
cp Info.plist "$CONTENTS/Info.plist"

# Ad-hoc code sign so macOS allows it to run
codesign --sign - --force --deep "$APP"

echo "Done. Open with:  open $APP"
