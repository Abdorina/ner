# DeepPavlov NER RU service

## Run (macOS)

1. Распаковать модель в:
   `models/ner_rus_bert_coll3_torch/` (должны быть `model.pth.tar` и `tag.dict`)

2. Запуск:

```bash
./run_ner_service.sh
# ner
```

# Russian NER service (DeepPavlov)

Сервис распознавания именованных сущностей (NER) для русского языка  
на основе модели DeepPavlov.

---

## 📦 Структура проекта

ner/
├── app.py
├── run_ner_service.sh
├── requirements.txt
├── ner_rus_bert_coll3_torch.tar
└── models/
└── ner_rus_bert_coll3_torch/
├── model.pth.tar
└── tag.dict

---

## 🚀 Запуск сервиса (macOS)

### 1. Распаковать модель

```bash
mkdir -p models/ner_rus_bert_coll3_torch
tar -xf ner_rus_bert_coll3_torch.tar -C models/ner_rus_bert_coll3_torch

2. Запустить сервис
./run_ner_service.sh

cервис стартует здесь
http://127.0.0.1:8000

проверка
curl -X POST "http://127.0.0.1:8000/ner" \
  -H "Content-Type: application/json" \
  -d '{"text":"Привет, меня зовут Яна, я живу в Москве."}'

ответ сервиса
{
  "result": [
    [["Яна"], ["Москве"]],
    [["B-PER"], ["B-LOC"]]
  ]
}


```
