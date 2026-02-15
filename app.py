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
		ner = build_model(cfg, download=False)
	return _ner

@app.get("/health")
def health():
	return {"status":"ok"}

@app.post("/ner")
def ner_endpoint(req: Req):
    model = get_ner()
    res = model([req.text])
    return {
        "result": res if isinstance(
            res, (list, dict, str, int, float, bool)
        ) else str(res)
    }

@app.get("/readyz")
def readyz():
	try:
        get_ner()
        return {"ok": True, "model_loaded": True}
    except Exception as e:
        return {"ok": False, "model_loaded": False, "error": f"{type(e).__name__}: {e}"}    return {"result": res}
