#!/usr/bin/env bash
set -euo pipefail

PORT="${PORT:-8000}"
LOG="${LOG:-ner.log}"
PIDFILE="${PIDFILE:-ner.pid}"

FORGE_DIR="$HOME/miniforge3"
CONDA_SH="$FORGE_DIR/etc/profile.d/conda.sh"
ENV_NAME="ner311"

cd "$(dirname "$0")"

if [ ! -f "$CONDA_SH" ]; then
  echo "❌ Не найден $CONDA_SH"
  echo "Сначала запусти: ./bootstrap_vm_light.sh"
  exit 1
fi

# stop old if running
if [ -f "$PIDFILE" ]; then
  OLD_PID="$(cat "$PIDFILE" || true)"
  if [ -n "${OLD_PID:-}" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "🛑 Stopping old server PID=$OLD_PID"
    kill "$OLD_PID" || true
    sleep 1
  fi
fi

: > "$LOG"
echo "🚀 Starting in background on 0.0.0.0:$PORT (log: $LOG)"

# IMPORTANT: bash -lc + source conda.sh -> работает даже в nohup
nohup bash -lc "source '$CONDA_SH' && conda activate '$ENV_NAME' && exec uvicorn app:app --host 0.0.0.0 --port '$PORT'" \
  >> "$LOG" 2>&1 &

echo $! > "$PIDFILE"
echo "✅ PID=$(cat "$PIDFILE")"