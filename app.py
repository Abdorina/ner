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


_ner = None


def get_ner():
    """Lazy-load DeepPavlov NER model on first request."""
    global _ner
    if _ner is None:
        cfg = parse_config(configs.ner.ner_rus_bert)
        cfg["metadata"]["variables"]["NER_PATH"] = str(MODEL_DIR)
        _ner = build_model(cfg, download=False)
    return _ner


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    try:
        get_ner()
        return {"ok": True, "model_loaded": True}
    except Exception as e:
        return {
            "ok": False,
            "model_loaded": False,
            "error": f"{type(e).__name__}: {e}"
        }

@app.post("/ner")
def ner_endpoint(req: Req):
    model = get_ner()
    try:
        res = model([req.text])
        return JSONResponse(content={"result": jsonable_encoder(res)})
    except Exception as e:
        log.exception("NER failed")
        raise

import logging
from fastapi import Request
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("app")

@app.exception_handler(Exception)
async def unhandled(request: Request, exc: Exception):
    log.exception("ERROR %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "internal error", "type": exc.__class__.__name__, "msg": str(exc)},
    )
