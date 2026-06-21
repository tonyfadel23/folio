#!/bin/bash
# Build, bundle, and launch Folio.app.
set -euo pipefail

cd "$(dirname "$0")/.."

bash scripts/bundle.sh

echo "▶ Launching Folio.app…"
open Folio.app
