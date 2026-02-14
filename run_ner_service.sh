#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

source "$(conda info --base)/etc/profile.d/conda.sh"

# создать env, если нет
if ! conda env list | awk '{print $1}' | grep -qx "ner311"; then
  conda create -n ner311 python=3.11 -y
fi

conda activate ner311
python -m pip install -U pip
pip install -r requirements.txt

# проверка модели
test -f "models/ner_rus_bert_coll3_torch/model.pth.tar" || { echo "❌ Нет model.pth.tar"; exit 1; }
test -f "models/ner_rus_bert_coll3_torch/tag.dict" || { echo "❌ Нет tag.dict"; exit 1; }

echo "🚀 NER service: http://127.0.0.1:8000"
uvicorn app:app --host 127.0.0.1 --port 8000