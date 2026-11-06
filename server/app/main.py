from fastapi import FastAPI, Header, HTTPException
from pydantic import BaseModel, Field

from app.accounts import Store
from app.battle import simulate

app = FastAPI(title="Ufacity", version="0.2.0")
app.state.accounts = Store()


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
    progress = user["progress"]
    return {
        "id": user["id"],
        "login": user["login"],
        "kind": user["kind"],
        "stage": progress["stage"],
        "gold": progress["gold"],
        "formation": progress["formation"],
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


@app.put("/LunexGame/me/formation")
def save_formation(body: FormationIn, authorization: str = Header(default="")) -> dict:
    user = _user_or_401(authorization)
    try:
        app.state.accounts.set_formation(user, body.formation)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    return public_user(user)
