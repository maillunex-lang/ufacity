from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

from app.battle import simulate

app = FastAPI(title="Ufacity", version="0.1.0")


class UnitIn(BaseModel):
    slot: int = Field(ge=0, le=4)
    role: str
    model: str = "TEMP"
    hp: int = 100
    atk: int = 10
    def_: int = Field(default=0, alias="def")
    speed: float = 1

    model_config = {"populate_by_name": True}


class SimIn(BaseModel):
    seed: int = 1
    left: list[UnitIn]
    right: list[UnitIn]


def _dump(side: list[UnitIn]) -> list[dict]:
    return [
        {
            "slot": u.slot,
            "role": u.role,
            "model": u.model,
            "hp": u.hp,
            "atk": u.atk,
            "def": u.def_,
            "speed": u.speed,
        }
        for u in side
    ]


@app.get("/health")
@app.get("/LunexGame/health")
def health() -> dict:
    return {"ok": True, "service": "ufacity"}


@app.post("/LunexGame/battle/sim")
def battle_sim(body: SimIn) -> dict:
    try:
        log = simulate(_dump(body.left), _dump(body.right), body.seed)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return log
