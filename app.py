from pathlib import Path
from fastapi import FastAPI
from pydantic import BaseModel
from deeppavlov import build_model, configs
from deeppavlov.core.commands.utils import parse_config

REPO_DIR = Path(__file__).resolve().parent
MODEL_DIR = REPO_DIR / "models" / "ner_rus_bert_coll3_torch"

app = FastAPI(title="DeepPavlov NER RU")

class Req(BaseModel):
    text: str

_ner=None

def get_ner():
	global _ner
	if _ner is None:

		# Берём стандартный конфиг и указываем путь к локальным файлам модели
		cfg = parse_config(configs.ner.ner_rus_bert)
		cfg["metadata"]["variables"]["NER_PATH"] = str(MODEL_DIR)	
		# ВАЖНО: если у тебя ещё не скачаны BERT/токенизатор — DeepPavlov докачает их при первом запуске
		ner = build_model(cfg, download=True)
	return _ner

@app.get("/health")
def health():
	return {"status":"ok"}


@app.post("/ner")
def ner_endpoint(req: Req):
    res = ner([req.text])

@app.get("/readyz")
def readyz():
    return {"model_loaded": model is not None}	
    return {"result": res}
