import random

from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from app.accounts import Store
from app.battle import simulate
from app.content import claim_idle, clear_stage, ensure_progress, level_up, summon

app = FastAPI(title="Ufacity", version="0.3.0")
app.state.accounts = Store()
app.state.clock = lambda: 1_700_000_000
app.state.rng = random.Random(1)


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


class LoginIn(BaseModel):
    login: str
    password: str


class HeroIn(BaseModel):
    hero: str


class FormationIn(BaseModel):
    formation: list[str]


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


def public_user(user: dict) -> dict:
    progress = ensure_progress(user, int(app.state.clock()))
    return {
        "id": user["id"],
        "login": user["login"],
        "kind": user["kind"],
        "stage": progress["stage"],
        "gold": progress["gold"],
        "formation": progress["formation"],
        "heroes": progress["heroes"],
        "pity": progress["pity"],
        "persisted": False,
    }


def _user_or_401(authorization: str) -> dict:
    try:
        return app.state.accounts.user_for(authorization)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc


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


@app.post("/LunexGame/auth/guest")
def auth_guest() -> dict:
    token = app.state.accounts.guest()
    user = app.state.accounts.user_for(f"Bearer {token}")
    return {"token": token, "profile": public_user(user)}


@app.post("/LunexGame/auth/register")
def auth_register(body: LoginIn) -> dict:
    try:
        token = app.state.accounts.register(body.login, body.password)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    user = app.state.accounts.user_for(f"Bearer {token}")
    return {"token": token, "profile": public_user(user)}


@app.post("/LunexGame/auth/login")
def auth_login(body: LoginIn) -> dict:
    try:
        token = app.state.accounts.login(body.login, body.password)
    except ValueError as exc:
        raise HTTPException(status_code=401, detail=str(exc)) from exc
    user = app.state.accounts.user_for(f"Bearer {token}")
    return {"token": token, "profile": public_user(user)}


@app.post("/LunexGame/auth/bind")
def auth_bind(body: LoginIn, authorization: str = Header(default="")) -> dict:
    try:
        user = app.state.accounts.bind(authorization, body.login, body.password)
    except ValueError as exc:
        status = 401 if str(exc) == "unauthorized" else 422
        raise HTTPException(status_code=status, detail=str(exc)) from exc
    return public_user(user)


@app.post("/LunexGame/auth/recover")
def auth_recover() -> dict:
    raise HTTPException(status_code=501, detail="mail delivery is not connected")


@app.get("/LunexGame/me")
def me(authorization: str = Header(default="")) -> dict:
    return public_user(_user_or_401(authorization))


@app.post("/LunexGame/idle/claim")
def idle_claim(authorization: str = Header(default="")) -> dict:
    user = _user_or_401(authorization)
    return claim_idle(user, int(app.state.clock()))


@app.post("/LunexGame/heroes/level")
def hero_level(body: HeroIn, authorization: str = Header(default="")) -> dict:
    user = _user_or_401(authorization)
    try:
        return level_up(user, body.hero, int(app.state.clock()))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/LunexGame/summon")
def summon_hero(authorization: str = Header(default="")) -> dict:
    user = _user_or_401(authorization)
    try:
        return summon(user, app.state.rng, int(app.state.clock()))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.post("/LunexGame/campaign/clear")
def campaign_clear(authorization: str = Header(default="")) -> dict:
    user = _user_or_401(authorization)
    seed = app.state.rng.randint(1, 1_000_000)
    try:
        return clear_stage(user, seed, int(app.state.clock()))
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc


@app.put("/LunexGame/me/formation")
def save_formation(body: FormationIn, authorization: str = Header(default="")) -> dict:
    user = _user_or_401(authorization)
    try:
        app.state.accounts.set_formation(user, body.formation)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return public_user(user)
