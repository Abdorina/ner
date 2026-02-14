#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8000
CONDA_DIR="$HOME/miniconda3"

echo "=== NER bootstrap for Debian 10 ==="

# --------------------------------------------------
# 1) System packages
# --------------------------------------------------
echo "📦 Installing system deps..."
sudo apt-get update
sudo apt-get install -y git git-lfs curl bzip2 ca-certificates tar

git lfs install

# --------------------------------------------------
# 2) Install Miniconda if missing
# --------------------------------------------------
if [ ! -d "$CONDA_DIR" ]; then
  echo "⬇️ Installing Miniconda..."
  curl -L -o /tmp/miniconda.sh \
    https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh

  bash /tmp/miniconda.sh -b -p "$CONDA_DIR"
fi

# load conda
source "$CONDA_DIR/etc/profile.d/conda.sh"

# --------------------------------------------------
# 3) Create environment
# --------------------------------------------------
if ! conda env list | awk '{print $1}' | grep -qx "ner311"; then
  echo "🐍 Creating conda env ner311..."
  conda create -n ner311 python=3.11 -y
fi

conda activate ner311
python -m pip install -U pip

# --------------------------------------------------
# 4) Pull LFS files
# --------------------------------------------------
cd "$REPO_DIR"

echo "📥 Pulling Git LFS files..."
git lfs pull

# --------------------------------------------------
# 5) Unpack model
# --------------------------------------------------
MODEL_DIR="models/ner_rus_bert_coll3_torch"
mkdir -p "$MODEL_DIR"

if [ ! -f "$MODEL_DIR/model.pth.tar" ]; then
  echo "🗜 Extracting model..."
  tar -xf ner_rus_bert_coll3_torch.tar -C "$MODEL_DIR"
fi

# --------------------------------------------------
# 6) Install EXACT working versions
# --------------------------------------------------
echo "📦 Installing Python dependencies..."

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

# --------------------------------------------------
# 7) Start service
# --------------------------------------------------
echo "🚀 Starting NER service: http://0.0.0.0:${PORT}"

exec uvicorn app:app --host 0.0.0.0 --port ${PORT}
