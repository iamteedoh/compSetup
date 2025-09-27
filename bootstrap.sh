#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OS_NAME=$(uname -s)

case "$OS_NAME" in
  Darwin)
    exec "$SCRIPT_DIR/macOSBootstrap.sh" "$@"
    ;;
  Linux)
    exec "$SCRIPT_DIR/linuxBootstrap.sh" "$@"
    ;;
  *)
    echo "Unsupported operating system: $OS_NAME" >&2
    echo "Only macOS and Ubuntu/Pop!_OS (Linux) are currently supported." >&2
    exit 1
    ;;
esac


