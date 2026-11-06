from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


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
