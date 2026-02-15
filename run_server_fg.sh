#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8000}"
FORGE_DIR="$HOME/miniforge3"
ENV_NAME="ner311"

# shellcheck disable=SC1091
source "$FORGE_DIR/etc/profile.d/conda.sh"
conda activate "$ENV_NAME"

cd "$(dirname "$0")"
exec uvicorn app:app --host 0.0.0.0 --port "$PORT"