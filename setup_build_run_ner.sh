#!/usr/bin/env bash
set -euo pipefail

# ====== НАСТРОЙКИ ======
REPO_URL="${REPO_URL:-https://github.com/Abdorina/ner.git}"
WORKDIR="${WORKDIR:-$HOME/ner-docker}"
IMAGE_NAME="${IMAGE_NAME:-ner-pavlov:1.0}"
CONTAINER_NAME="${CONTAINER_NAME:-ner-pavlov}"
HOST_PORT="${HOST_PORT:-8000}"

# Если репозиторий/ LFS приватные — передай токен:
#   GITHUB_TOKEN=ghp_xxx bash setup_build_run_ner.sh
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

echo "=== Setup + Build + Run (Debian) ==="
echo "Repo:      $REPO_URL"
echo "Workdir:   $WORKDIR"
echo "Image:     $IMAGE_NAME"
echo "Container: $CONTAINER_NAME"
echo "Port:      $HOST_PORT"
echo

# ----- 0) Fix Debian 10 apt repos (buster is EOL) -----
fix_apt_buster() {
  if [ -f /etc/os-release ] && grep -qE 'VERSION_ID="10"|VERSION_ID=10' /etc/os-release; then
    echo "🛠 Debian 10 detected. Switching apt sources to archive.debian.org ..."
    sudo cp -a /etc/apt/sources.list "/etc/apt/sources.list.bak.$(date +%s)" || true
    cat <<'EOF' | sudo tee /etc/apt/sources.list >/dev/null
deb http://archive.debian.org/debian buster main contrib non-free
deb http://archive.debian.org/debian-security buster/updates main contrib non-free
EOF
    echo 'Acquire::Check-Valid-Until "false";' | sudo tee /etc/apt/apt.conf.d/99no-check-valid >/dev/null
  fi
}
fix_apt_buster

# ----- 1) System deps -----
echo "⬇️ Installing system packages (git, git-lfs, docker)..."
sudo apt-get update
sudo apt-get install -y curl ca-certificates git git-lfs docker.io tar

sudo systemctl enable docker
sudo systemctl start docker

git lfs install

# ----- 2) Prepare workdir -----
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# ----- 3) Clone repo + pull LFS -----
clone_url="$REPO_URL"
if [ -n "$GITHUB_TOKEN" ]; then
  # HTTPS auth without SSH (for private repo/LFS)
  clone_url="$(echo "$REPO_URL" | sed -E "s#https://#https://${GITHUB_TOKEN}@#")"
fi

if [ ! -d ".git" ]; then
  echo "📥 Cloning repo..."
  git clone "$clone_url" .
else
  echo "🔄 Repo exists, pulling..."
  git pull --rebase || true
fi

echo "📦 Pulling Git LFS files..."
git lfs pull

# ----- 4) Validate required files -----
echo "🔎 Checking required artifacts..."
test -f app.py || { echo "❌ app.py not found in repo root"; exit 1; }
test -f deeppavlov_cache.tar.gz || { echo "❌ deeppavlov_cache.tar.gz not found"; exit 1; }
test -f hf_rubert_only.tar.gz || { echo "❌ hf_rubert_only.tar.gz not found"; exit 1; }

ls -lh deeppavlov_cache.tar.gz hf_rubert_only.tar.gz

# Check not LFS pointer
if head -n 1 deeppavlov_cache.tar.gz | grep -q "git-lfs.github.com"; then
  echo "❌ deeppavlov_cache.tar.gz is an LFS pointer (not downloaded)."
  echo "   Ensure LFS access, then run: git lfs pull"
  exit 1
fi

# ----- 5) Determine model dir name inside deeppavlov cache -----
# We expect something like: .deeppavlov/models/<model_dir>/model.pth.tar
MODEL_DIR_IN_CACHE="$(tar -tzf deeppavlov_cache.tar.gz | \
  awk -F/ '/\.deeppavlov\/models\/[^\/]+\/model\.pth\.tar$/ {print $3; exit}')"

if [ -z "${MODEL_DIR_IN_CACHE:-}" ]; then
  echo "❌ Cannot detect model dir inside deeppavlov_cache.tar.gz"
  echo "   Run: tar -tzf deeppavlov_cache.tar.gz | head -n 50"
  exit 1
fi

echo "✅ Detected DeepPavlov model dir in cache: $MODEL_DIR_IN_CACHE"

# ----- 6) Create Dockerfile (always overwrite to be consistent) -----
echo "📝 Writing Dockerfile..."
cat > Dockerfile <<EOF
FROM python:3.11-slim
WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \\
    tar curl ca-certificates \\
 && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir -U pip && pip install --no-cache-dir \\
  deeppavlov==1.7.0 \\
  fastapi==0.89.1 \\
  uvicorn==0.40.0 \\
  "pydantic<2" \\
  torch \\
  numpy==1.23.5 \\
  tqdm==4.64.1 \\
  transformers==4.30.2 \\
  tokenizers==0.13.3 \\
  huggingface_hub==0.16.4 \\
  filelock==3.9.1 \\
  pytorch-crf

COPY app.py /app/app.py

COPY deeppavlov_cache.tar.gz /tmp/deeppavlov_cache.tar.gz
COPY hf_rubert_only.tar.gz /tmp/hf_rubert_only.tar.gz

# 1) распаковываем кеши в /root (получится /root/.deeppavlov и /root/.cache/huggingface)
# 2) создаём симлинк, чтобы app.py видел модель в /app/models/ner_rus_bert_coll3_torch
RUN mkdir -p /root/.cache /root/.deeppavlov /app/models \\
 && tar -xzf /tmp/deeppavlov_cache.tar.gz -C /root \\
 && tar -xzf /tmp/hf_rubert_only.tar.gz -C /root \\
 && rm -f /tmp/*.tar.gz \\
 && ln -s /root/.deeppavlov/models/${MODEL_DIR_IN_CACHE} /app/models/ner_rus_bert_coll3_torch

EXPOSE 8000
CMD ["uvicorn","app:app","--host","0.0.0.0","--port","8000"]
EOF

# ----- 7) Build image -----
echo "🔨 Building image $IMAGE_NAME ..."
sudo docker build -t "$IMAGE_NAME" .

# ----- 8) Run container -----
echo "🧹 Removing old container (if any)..."
sudo docker rm -f "$CONTAINER_NAME" >/dev/null 2>&1 || true

echo "🚀 Starting container $CONTAINER_NAME ..."
sudo docker run -d --name "$CONTAINER_NAME" -p "${HOST_PORT}:8000" "$IMAGE_NAME"

echo
echo "✅ Done. Try:"
echo "  curl -i http://127.0.0.1:${HOST_PORT}/health"
echo "  curl -i http://127.0.0.1:${HOST_PORT}/readyz"
echo "  curl -s -X POST http://127.0.0.1:${HOST_PORT}/ner -H 'Content-Type: application/json' -d '{\"text\":\"Иван Иванов живёт в Москве\"}'"
echo
echo "Logs:"
echo "  sudo docker logs -f ${CONTAINER_NAME}"