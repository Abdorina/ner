#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8000
FORGE_DIR="$HOME/miniforge3"
ENV_NAME="ner311"

echo "=== LIGHT CPU bootstrap ==="

# --------------------------------------------------
# 1) System deps
# --------------------------------------------------
sudo apt-get update
sudo apt-get install -y git git-lfs curl bzip2 ca-certificates tar

git lfs install

# --------------------------------------------------
# 2) Install Miniforge (NO Anaconda ToS)
# --------------------------------------------------
if [ ! -d "$FORGE_DIR" ]; then
  echo "⬇️ Installing Miniforge..."
  curl -L -o /tmp/miniforge.sh \
    https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
  bash /tmp/miniforge.sh -b -p "$FORGE_DIR"
fi

source "$FORGE_DIR/etc/profile.d/conda.sh"

conda config --remove-key channels 2>/dev/null || true
conda config --add channels conda-forge
conda config --set channel_priority strict

# --------------------------------------------------
# 3) Create env
# --------------------------------------------------
if ! conda env list | awk '{print $1}' | grep -qx "$ENV_NAME"; then
  conda create -n "$ENV_NAME" python=3.11 -y
fi

conda activate "$ENV_NAME"
python -m pip install -U pip

# --------------------------------------------------
# 4) Pull repo files
# --------------------------------------------------
cd "$REPO_DIR"
git pull || true
git lfs pull

# --------------------------------------------------
# 5) Unpack model
# --------------------------------------------------
# 5) Restore offline caches (DeepPavlov + HuggingFace)
echo "📦 Restoring offline caches..."

# DeepPavlov cache (~/.deeppavlov)
tar -xzf deeppavlov_cache.tar.gz -C "$HOME"

# HuggingFace cache
mkdir -p "$HOME/.cache/huggingface/hub"
tar -xzf hf_rubert_only.tar.gz -C "$HOME/.cache/huggingface/hub"

export HF_HOME="$HOME/.cache/huggingface"
export TRANSFORMERS_CACHE="$HOME/.cache/huggingface"

# --------------------------------------------------
# 6) Install LIGHT dependencies (CPU ONLY)
# --------------------------------------------------
echo "📦 Installing LIGHT dependencies..."

# CPU-only torch (главный момент)
pip install --no-cache-dir \
  "torch" \
  --index-url https://download.pytorch.org/whl/cpu

pip install --no-cache-dir \
  "deeppavlov==1.7.0" \
  "fastapi==0.89.1" \
  "uvicorn==0.18.3" \
  "pydantic<2" \
  "numpy==1.23.5" \
  "tqdm==4.64.1" \
  "transformers==4.30.2" \
  "tokenizers==0.13.3" \
  "huggingface_hub==0.16.4" \
  "filelock==3.9.1" \
  "pytorch-crf"

# --------------------------------------------------
# 7) Run service
# --------------------------------------------------
echo "🚀 Starting NER service on http://0.0.0.0:${PORT}"

exec uvicorn app:app --host 0.0.0.0 --port ${PORT}