#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Abdorina/ner.git"
REPO_DIR="${REPO_DIR:-ner}"
PORT="${PORT:-8000}"

# ---- 1) System deps (Ubuntu/Debian) ----
if command -v apt >/dev/null 2>&1; then
  sudo apt update
  sudo apt install -y git git-lfs python3.11 python3.11-venv python3-pip
  git lfs install
else
  echo "❌ Этот скрипт сейчас поддерживает Ubuntu/Debian (apt)."
  echo "Скажи ОС VM (например CentOS/RHEL/Amazon Linux) — дам версию под неё."
  exit 1
fi

# ---- 2) Clone repo (if needed) ----
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
fi
cd "$REPO_DIR"

# ---- 3) Pull LFS files ----
git lfs pull

# ---- 4) Unpack model (if not unpacked) ----
TAR_FILE="ner_rus_bert_coll3_torch.tar"
MODEL_DIR="models/ner_rus_bert_coll3_torch"
mkdir -p "$MODEL_DIR"

if [ ! -f "$MODEL_DIR/model.pth.tar" ] || [ ! -f "$MODEL_DIR/tag.dict" ]; then
  if [ ! -f "$TAR_FILE" ]; then
    echo "❌ Не найден $TAR_FILE. Проверь, что он есть в репозитории и скачался через LFS."
    exit 1
  fi
  echo "🗜 Распаковываю модель..."
  tar -xf "$TAR_FILE" -C "$MODEL_DIR"
fi

# ---- 5) Create venv ----
if [ ! -d ".venv" ]; then
  python3.11 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
python -m pip install -U pip

# ---- 6) Install pinned Python deps ----
# Эти версии мы уже “выстрадали” на Mac, чтобы DeepPavlov 1.7.0 работал стабильно
python -m pip install --no-cache-dir \
  "deeppavlov==1.7.0" \
  "fastapi==0.89.1" \
  "uvicorn==0.40.0" \
  "pydantic<2" \
  "torch" \
  "pytorch-crf" \
  "numpy==1.23.5" \
  "tqdm==4.64.1" \
  "transformers==4.30.2" \
  "tokenizers==0.13.3" \
  "huggingface_hub==0.16.4" \
  "filelock==3.9.1"

# ---- 7) Run service ----
echo "✅ Model files:"
ls -lh "$MODEL_DIR/model.pth.tar" "$MODEL_DIR/tag.dict"

echo "🚀 Starting NER service on http://0.0.0.0:${PORT}"
exec uvicorn app:app --host 0.0.0.0 --port "$PORT"