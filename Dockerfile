FROM python:3.11-slim

WORKDIR /app

ENV PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_PROGRESS_BAR=off \
    MAKEFLAGS="-j1" \
    MAX_JOBS=1

RUN pip install \
  deeppavlov==1.7.0 \
  fastapi==0.89.1 \
  uvicorn==0.18.3 \
  "pydantic<2" \
  torch==2.1.2+cpu --index-url https://download.pytorch.org/whl/cpu \
  pytorch-crf \
  numpy==1.23.5 \
  tqdm==4.64.1 \
  transformers==4.30.2 \
  tokenizers==0.13.3 \
  huggingface_hub==0.16.4 \
  filelock==3.9.1

COPY app.py /app/app.py

ADD deeppavlov_cache.tar.gz /root/
ADD hf_rubert_only.tar.gz /root/

RUN mkdir -p /root/.cache /root/.deeppavlov /app/models \
 && ln -s /root/.deeppavlov/models/ner_rus_bert_torch \
    /app/models/ner_rus_bert_coll3_torch

EXPOSE 8000

CMD ["uvicorn","app:app","--host","0.0.0.0","--port","8000"]