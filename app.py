from pathlib import Path
import logging

from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel

from deeppavlov import build_model, configs
from deeppavlov.core.commands.utils import parse_config


logging.basicConfig(level=logging.INFO)
log = logging.getLogger("app")

REPO_DIR = Path(__file__).resolve().parent
MODEL_DIR = REPO_DIR / "models" / "ner_rus_bert_coll3_torch"

app = FastAPI(title="DeepPavlov NER RU")


class Req(BaseModel):
    text: str


_ner = None
_model_loading = False
_model_error = None


def get_ner():
    global _ner, _model_loading, _model_error

    if _ner is not None:
        return _ner

    if _model_loading:
        raise RuntimeError("model is loading")

    _model_loading = True
    try:
        cfg = parse_config(configs.ner.ner_rus_bert)

        # попытка направить DeepPavlov на локальную папку
        cfg["metadata"]["variables"]["NER_PATH"] = str(MODEL_DIR)

        _ner = build_model(cfg, download=False)
        _model_error = None
        return _ner
    except Exception as e:
        _model_error = f"{type(e).__name__}: {e}"
        log.exception("Model load failed")
        raise
    finally:
        _model_loading = False


@app.exception_handler(Exception)
async def unhandled(request: Request, exc: Exception):
    log.exception("ERROR %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": "internal error", "type": exc.__class__.__name__, "msg": str(exc)},
    )


@app.get("/health")
def health():
    return {"status": "ok"}


@app.get("/readyz")
def readyz():
    return {
        "ok": _ner is not None,
        "model_loaded": _ner is not None,
        "loading": _model_loading,
        "error": _model_error,
        "model_dir_exists": MODEL_DIR.exists(),
        "model_dir": str(MODEL_DIR),
    }


@app.post("/ner")
def ner_endpoint(req: Req):
    model = get_ner()
    res = model([req.text])
    return JSONResponse(content={"result": jsonable_encoder(res)})


@app.get("/test_ru")
def test_ru():
    model = get_ner()
    res = model(["Привет, меня зовут Яна. Я живу в Москве"])
    return JSONResponse(content={"result": jsonable_encoder(res)})

@app.get("/model_files")
def model_files():
    if not MODEL_DIR.exists():
        return {"exists": False, "dir": str(MODEL_DIR), "count": 0, "files": []}

    files = sorted([str(p.relative_to(MODEL_DIR)) for p in MODEL_DIR.rglob("*") if p.is_file()])
    return {"exists": True, "dir": str(MODEL_DIR), "count": len(files), "files": files}

