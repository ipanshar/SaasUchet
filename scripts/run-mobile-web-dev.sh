#!/usr/bin/env sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
FLUTTER_BIN="$ROOT_DIR/.tools/flutter-sdk/bin/flutter"
UNZIP_SHIM_DIR="$ROOT_DIR/.tools/bin"
MOBILE_DIR="$ROOT_DIR/mobile"

if [ ! -x "$FLUTTER_BIN" ]; then
  echo "Flutter SDK not found at $FLUTTER_BIN" >&2
  exit 1
fi

export PATH="$UNZIP_SHIM_DIR:$PATH"

cd "$MOBILE_DIR"
exec "$FLUTTER_BIN" run -d web-server --web-hostname 0.0.0.0 --web-port 3000
