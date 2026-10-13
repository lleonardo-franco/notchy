#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

scripts/compile.sh
scripts/bundle.sh build/Notchy.app

echo "Pronto: build/Notchy.app"
