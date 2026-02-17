FROM python:3.11-slim

WORKDIR /app

RUN apt-get update \ && apt-get install -y --no-install-recommends \
    tar curl ca-certificates \
    && apt-get clean \   
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir -U pip && pip install --no-cache-dir \
  deeppavlov==1.7.0 \
  fastapi==0.89.1 \
  uvicorn==0.40.0 \
  "pydantic<2" \
  torch \
  numpy==1.23.5 \
  tqdm==4.64.1 \
  transformers==4.30.2 \
  tokenizers==0.13.3 \
  huggingface_hub==0.16.4 \
  filelock==3.9.1 \
  pytorch-crf

COPY app.py /app/app.py

COPY deeppavlov_cache.tar.gz /tmp/
COPY hf_rubert_only.tar.gz /tmp/

RUN mkdir -p /root/.cache /root/.deeppavlov /app/models \
 && tar -xzf /tmp/deeppavlov_cache.tar.gz -C /root \
 && tar -xzf /tmp/hf_rubert_only.tar.gz -C /root \
 && ln -s /root/.deeppavlov/models/ner_rus_bert_torch /app/models/ner_rus_bert_coll3_torch

EXPOSE 8000

CMD ["uvicorn","app:app","--host","0.0.0.0","--port","8000"]
