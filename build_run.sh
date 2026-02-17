#!/usr/bin/env bash
set -euo pipefail

IMAGE="ner-pavlov"
NAME="ner-pavlov"
PORT=8000

docker rm -f "$NAME" 2>/dev/null || true
docker build -t "$IMAGE" .
docker run -d --name "$NAME" -p ${PORT}:8000 "$IMAGE"

echo "OK. Test:"
echo "  curl -i http://127.0.0.1:${PORT}/health"