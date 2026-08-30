#!/usr/bin/env bash
set -euo pipefail

DEST_DIR="${1:-$HOME/.local/bin}"
SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin"

mkdir -p "$DEST_DIR"
install -m 755 "$SRC_DIR/aur-verify" "$DEST_DIR/aur-verify"

echo "Installed aur-verify to $DEST_DIR/aur-verify"
case ":$PATH:" in
  *":$DEST_DIR:"*) ;;
  *) echo "Note: $DEST_DIR is not on your PATH." ;;
esac
