#!/usr/bin/env bash
set -euo pipefail

PIDFILE="${PIDFILE:-ner.pid}"

cd "$(dirname "$0")"

if [ ! -f "$PIDFILE" ]; then
  echo "No pid file ($PIDFILE)."
  exit 0
fi

PID="$(cat "$PIDFILE" || true)"
if [ -z "${PID:-}" ]; then
  echo "Empty pid file."
  exit 0
fi

if kill -0 "$PID" 2>/dev/null; then
  echo "🛑 Stopping PID=$PID"
  kill "$PID" || true
else
  echo "PID $PID not running."
fi

rm -f "$PIDFILE"