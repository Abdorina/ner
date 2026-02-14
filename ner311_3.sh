#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT="${PORT:-8000}"

FORGE_DIR="$HOME/miniforge3"
ENV_NAME="ner311"

echo "=== Debian 10 bootstrap (Miniforge/conda-forge, no Anaconda ToS) ==="

# 1) System deps
sudo apt-get update
sudo apt-get install -y git git-lfs curl bzip2 ca-certificates tar
git lfs install

# 2) Install Miniforge if missing
if [ ! -d "$FORGE_DIR" ]; then
  echo "⬇️ Installing Miniforge..."
  curl -L -o /tmp/miniforge.sh \
    https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
  bash /tmp/miniforge.sh -b -p "$FORGE_DIR"
fi

# 3) Load conda
# shellcheck disable=SC1091
source "$FORGE_DIR/etc/profile.d/conda.sh"

# 4) Ensure only conda-forge channel (no defaults)
conda config --remove-key channels 2>/dev/null || true
conda config --add channels conda-forge
conda config --set channel_priority strict

# 5) Create env if needed
if ! conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
  conda create -n "$ENV_NAME" python=3.11 -y
fi
conda activate "$ENV_NAME"
python -m pip install -U pip

# 6) Pull LFS + unpack model
cd "$REPO_DIR"
git pull || true
git lfs pull

MODEL_DIR="models/ner_rus_bert_coll3_torch"
mkdir -p "$MODEL_DIR"

if [ ! -f "$MODEL_DIR/model.pth.tar" ] || [ ! -f "$MODEL_DIR/tag.dict" ]; then
  echo "🗜 Extracting model..."
  tar -xf ner_rus_bert_coll3_torch.tar -C "$MODEL_DIR"
fi

# 7) Install pinned deps (same working set)
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

echo "✅ Model files:"
ls -lh "$MODEL_DIR/model.pth.tar" "$MODEL_DIR/tag.dict"

echo "🚀 Starting NER service on http://0.0.0.0:${PORT}"
exec uvicorn app:app --host 0.0.0.0 --port "$PORT"