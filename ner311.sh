#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/Abdorina/ner.git"
REPO_DIR="${REPO_DIR:-ner}"
PORT="${PORT:-8000}"

# --- 1) System deps (Debian 10) ---
sudo apt-get update
sudo apt-get install -y git git-lfs curl bzip2 ca-certificates tar
git lfs install

# --- 2) Install Miniconda locally (no root needed) ---
CONDA_DIR="$HOME/miniconda3"
if [ ! -d "$CONDA_DIR" ]; then
  echo "⬇️ Installing Miniconda..."
  curl -L -o /tmp/miniconda.sh \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
  bash /tmp/miniconda.sh -b -p "$CONDA_DIR"
fi

# Enable conda in this shell
# shellcheck disable=SC1091
source "$CONDA_DIR/etc/profile.d/conda.sh"

# --- 3) Create env with Python 3.11 + pinned deps ---
if ! conda env list | awk '{print $1}' | grep -qx "ner311"; then
  conda create -n ner311 python=3.11 -y
fi
conda activate ner311
python -m pip install -U pip

# --- 4) Clone repo (if needed) ---
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone "$REPO_URL" "$REPO_DIR"
fi
cd "$REPO_DIR"

# --- 5) Pull LFS files ---
git lfs pull

# --- 6) Unpack model ---
TAR_FILE="ner_rus_bert_coll3_torch.tar"
MODEL_DIR="models/ner_rus_bert_coll3_torch"
mkdir -p "$MODEL_DIR"

if [ ! -f "$MODEL_DIR/model.pth.tar" ] || [ ! -f "$MODEL_DIR/tag.dict" ]; then
  if [ ! -f "$TAR_FILE" ]; then
    echo "❌ Не найден $TAR_FILE. Проверь, что он в репозитории и скачался через LFS."
    exit 1
  fi
  echo "🗜 Extracting model..."
  tar -xf "$TAR_FILE" -C "$MODEL_DIR"
fi

# --- 7) Install pinned Python deps (the working set) ---
python -m pip install --no-cache-dir \
  "deeppavlov==1.7.0" \
  "fastapi==0.89.1" \
  "uvicorn==0.40.0" \
  "pydantic<2" \
  "torch" \
  "numpy==1.23.5" \
  "tqdm==4.64.1" \
  "transformers==4.30.2" \
  "tokenizers==0.13.3" \
  "huggingface_hub==0.16.4" \
  "filelock==3.9.1" \
  "pytorch-crf"

# --- 8) Run service ---
echo "✅ Model files:"
ls -lh "$MODEL_DIR/model.pth.tar" "$MODEL_DIR/tag.dict"

echo "🚀 Starting NER service on http://0.0.0.0:${PORT}"
exec uvicorn app:app --host 0.0.0.0 --port "$PORT"
