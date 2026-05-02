#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCHEME="Jeff AI"
PROJECT="Jeff AI.xcodeproj"
APP_NAME="Jeff AI.app"
CONFIG="${CONFIG:-Debug}"

cd "$PROJECT_DIR"

echo "▶ Building $SCHEME ($CONFIG)…"
BUILD_OUT="$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -configuration "$CONFIG" -destination "platform=macOS" \
    -showBuildSettings build 2>/dev/null | awk -F' = ' '/ BUILT_PRODUCTS_DIR / {print $2; exit}')"

xcodebuild -project "$PROJECT" -scheme "$SCHEME" \
    -configuration "$CONFIG" -destination "platform=macOS" build

APP_PATH="$BUILD_OUT/$APP_NAME"
if [[ ! -d "$APP_PATH" ]]; then
    echo "✗ Build succeeded but $APP_PATH is missing." >&2
    exit 1
fi

echo "▶ Launching $APP_PATH"
# Kill any prior instance so we always run the freshly built binary.
pkill -x "Jeff AI" 2>/dev/null || true
# Refresh LaunchServices registration so it points at this build, not a stale one.
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$APP_PATH" >/dev/null 2>&1 || true
# -n forces a new instance even if LaunchServices thinks one is already running.
open -n "$APP_PATH"
