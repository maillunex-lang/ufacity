import random

import pytest
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


@pytest.fixture(autouse=True)
def clean_accounts():
    app.state.accounts.reset()
    app.state.clock = lambda: 1_700_000_000
    app.state.rng = random.Random(1)
    yield
    app.state.accounts.reset()


def team(model: str, atk: int) -> list[dict]:
    roles = ["tank", "warrior", "ranger", "mage", "healer"]
    return [
        {"slot": i, "role": roles[i], "model": model, "hp": 80, "atk": atk, "def": 4, "speed": 1}
        for i in range(5)
    ]


def test_health_paths():
    for path in ("/health", "/LunexGame/health"):
        response = client.get(path)
        assert response.status_code == 200
        assert response.json()["ok"] is True


def test_same_seed_same_log():
    payload = {"seed": 7, "left": team("TEMP_A", 18), "right": team("TEMP_B", 12)}
    a = client.post("/LunexGame/battle/sim", json=payload)
    b = client.post("/LunexGame/battle/sim", json=payload)
    assert a.status_code == 200
    assert a.json() == b.json()
    assert a.json()["reward_granted"] is False
    assert a.json()["units"][0]["max_hp"] == 80


def test_melee_moves_before_standing_still():
    log = client.post(
        "/LunexGame/battle/sim",
        json={"seed": 1, "left": team("TEMP_A", 14), "right": team("TEMP_B", 14)},
    ).json()
    kinds = [event["type"] for event in log["events"]]
    assert "move" in kinds
    assert kinds.index("move") < kinds.index("attack")


def test_no_reward_route():
    paths = {route.path for route in app.routes}
    assert "/LunexGame/battle/sim" in paths
    assert not any("reward" in path or "gold" in path for path in paths)


def test_rejects_wrong_team_size():
    response = client.post(
        "/LunexGame/battle/sim",
        json={"seed": 1, "left": team("TEMP_A", 10)[:4], "right": team("TEMP_B", 10)},
    )
    assert response.status_code == 422


def test_guest_register_login_and_bind():
    guest = client.post("/LunexGame/auth/guest")
    assert guest.status_code == 200
    guest_token = guest.json()["token"]
    assert guest.json()["profile"]["gold"] == 0
    bound = client.post(
        "/LunexGame/auth/bind",
        headers={"Authorization": f"Bearer {guest_token}"},
        json={"login": "pilot", "password": "long-enough"},
    )
    assert bound.status_code == 200
    assert bound.json()["kind"] == "account"
    logged = client.post("/LunexGame/auth/login", json={"login": "pilot", "password": "long-enough"})
    assert logged.status_code == 200
    bad = client.post("/LunexGame/auth/login", json={"login": "pilot", "password": "wrong-pass"})
    assert bad.status_code == 401


def test_formation_save_ignores_client_gold():
    token = client.post(
        "/LunexGame/auth/register",
        json={"login": "keeper", "password": "long-enough"},
    ).json()["token"]
    headers = {"Authorization": f"Bearer {token}"}
    saved = client.put(
        "/LunexGame/me/formation",
        headers=headers,
        json={"formation": ["a", "b", "c", "d", "e"], "gold": 999999, "stage": 40},
    )
    assert saved.status_code == 200
    body = saved.json()
    assert body["formation"] == ["a", "b", "c", "d", "e"]
    assert body["gold"] == 0
    assert body["stage"] == 1
    assert body["persisted"] is False


def test_recover_is_not_pretending_to_send_mail():
    response = client.post("/LunexGame/auth/recover")
    assert response.status_code == 501


def _auth() -> dict:
    token = client.post(
        "/LunexGame/auth/register",
        json={"login": "earner", "password": "long-enough"},
    ).json()["token"]
    return {"Authorization": f"Bearer {token}"}


def test_idle_gold_comes_from_server_clock_only():
    headers = _auth()
    first = client.post("/LunexGame/idle/claim", headers=headers)
    assert first.json()["gained"] == 0
    app.state.clock = lambda: 1_700_000_000 + 100
    second = client.post("/LunexGame/idle/claim", headers=headers, json={"gold": 99999})
    assert second.status_code == 200
    assert second.json()["gained"] == 10
    assert second.json()["gold"] == 10


def test_level_spends_server_gold():
    headers = _auth()
    app.state.clock = lambda: 1_700_000_000 + 300
    client.post("/LunexGame/idle/claim", headers=headers)
    upgraded = client.post("/LunexGame/heroes/level", headers=headers, json={"hero": "temp_a"})
    assert upgraded.status_code == 200
    assert upgraded.json()["level"] == 2
    assert upgraded.json()["gold"] == 5
    missing = client.post("/LunexGame/heroes/level", headers=headers, json={"hero": "temp_a"})
    assert missing.status_code == 422


def test_summon_does_not_accept_a_client_rarity():
    headers = _auth()
    app.state.clock = lambda: 1_700_000_000 + 500
    client.post("/LunexGame/idle/claim", headers=headers)
    rolled = client.post("/LunexGame/summon", headers=headers, json={"rarity": "legendary", "hero": "temp_c"})
    assert rolled.status_code == 200
    assert rolled.json()["hero"] in {"temp_a", "temp_b", "temp_c"}
    assert rolled.json()["gold"] == 0


def test_stage_clear_grants_only_when_the_server_wins():
    headers = _auth()
    cleared = client.post("/LunexGame/campaign/clear", headers=headers, json={"winner": "left", "gold": 999})
    assert cleared.status_code == 200
    body = cleared.json()
    assert body["winner"] == "left"
    assert body["reward_granted"] is True
    assert body["reward_gold"] == 30
    assert body["stage"] == 2
    assert body["gold"] == 30

