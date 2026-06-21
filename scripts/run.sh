#!/bin/bash
# Build, bundle, and launch NativeMd.app.
set -euo pipefail

cd "$(dirname "$0")/.."

bash scripts/bundle.sh

echo "▶ Launching NativeMd.app…"
open NativeMd.app
