#!/usr/bin/env sh

set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
MOBILE_DIR="$ROOT_DIR/mobile"
API_BASE_URL="https://uchet.smoketrout.com"

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found on PATH" >&2
  exit 1
fi

cd "$MOBILE_DIR"
exec flutter build apk --release --dart-define="API_BASE_URL=$API_BASE_URL"
