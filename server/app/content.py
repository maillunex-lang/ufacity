"""Server-side stage, idle gold, summon and level. The client does not name the reward."""

from __future__ import annotations

import random

from app.battle import simulate

HEROES = {
    "temp_a": {"model": "swordsman", "role": "tank", "rarity": "common", "hp": 120, "atk": 20, "def": 6, "speed": 1},
    "temp_b": {"model": "priest", "role": "ranger", "rarity": "common", "hp": 90, "atk": 16, "def": 3, "speed": 1},
    "temp_c": {"model": "priest", "role": "healer", "rarity": "uncommon", "hp": 100, "atk": 12, "def": 4, "speed": 1},
    "uraldar": {"model": "uraldar", "role": "warrior", "rarity": "epic", "hp": 110, "atk": 22, "def": 5, "speed": 1.45},
}

IDLE_CAP = 8 * 3600
SUMMON_COST = 50
PITY = 10


def ensure_progress(user: dict, now: int) -> dict:
    progress = user["progress"]
    heroes = progress.setdefault("heroes", {
        "temp_a": {"level": 1, "copies": 1},
        "temp_b": {"level": 1, "copies": 1},
    })
    heroes.setdefault("uraldar", {"level": 1, "copies": 1})
    progress.setdefault("pity", 0)
    if progress.get("last_claim") is None:
        progress["last_claim"] = now
    if not progress.get("formation"):
        progress["formation"] = ["temp_a", "uraldar", "temp_b", "temp_b", "temp_b"]
    return progress


def claim_idle(user: dict, now: int) -> dict:
    progress = ensure_progress(user, now)
    elapsed = max(0, min(IDLE_CAP, int(now) - int(progress["last_claim"])))
    # One gold every 10 seconds at stage 1. Stage raises the rate, the cap stays.
    gained = elapsed * progress["stage"] // 10
    progress["gold"] += gained
    progress["last_claim"] = int(now)
    return {"gained": gained, "gold": progress["gold"], "elapsed": elapsed}


def level_up(user: dict, hero_id: str, now: int) -> dict:
    progress = ensure_progress(user, now)
    if hero_id not in progress["heroes"]:
        raise ValueError("hero not owned")
    hero = progress["heroes"][hero_id]
    cost = hero["level"] * 25
    if progress["gold"] < cost:
        raise ValueError("not enough gold")
    progress["gold"] -= cost
    hero["level"] += 1
    return {"hero": hero_id, "level": hero["level"], "gold": progress["gold"], "spent": cost}


def summon(user: dict, rng: random.Random, now: int) -> dict:
    progress = ensure_progress(user, now)
    if progress["gold"] < SUMMON_COST:
        raise ValueError("not enough gold")
    progress["gold"] -= SUMMON_COST
    progress["pity"] += 1
    if progress["pity"] >= PITY:
        hero_id = "temp_c"
        progress["pity"] = 0
    else:
        hero_id = rng.choice(["temp_a", "temp_b", "temp_a"])
    owned = progress["heroes"]
    if hero_id in owned:
        owned[hero_id]["copies"] += 1
        duplicate = True
    else:
        owned[hero_id] = {"level": 1, "copies": 1}
        duplicate = False
    return {
        "hero": hero_id,
        "duplicate": duplicate,
        "copies": owned[hero_id]["copies"],
        "gold": progress["gold"],
        "pity": progress["pity"],
    }


def _side(ids: list[str], levels: dict[str, dict], stage: int, enemy: bool) -> list[dict]:
    roles = ["tank", "warrior", "ranger", "mage", "healer"]
    units = []
    for slot, hero_id in enumerate(ids):
        base = HEROES.get(hero_id, HEROES["temp_a"])
        level = 1 if enemy else levels.get(hero_id, {}).get("level", 1)
        scale = stage if enemy else level
        model = base["model"] if not enemy else "priest"
        units.append({
            "slot": slot,
            "role": base["role"] if not enemy else roles[slot],
            "model": model,
            "hp": 40 * scale if enemy else base["hp"] + (level - 1) * 20,
            "atk": 6 * scale if enemy else base["atk"] + (level - 1) * 4,
            "def": 1 if enemy else base["def"],
            "speed": 1 if enemy else float(base.get("speed", 1)),
        })
    return units


def clear_stage(user: dict, seed: int, now: int) -> dict:
    progress = ensure_progress(user, now)
    ids = list(progress["formation"])
    if len(ids) != 5:
        raise ValueError("formation needs 5 ids")
    stage = progress["stage"]
    log = simulate(_side(ids, progress["heroes"], stage, False), _side(ids, {}, stage, True), seed)
    granted = log["winner"] == "left"
    reward = 0
    if granted:
        reward = 30 * stage
        progress["stage"] += 1
        progress["gold"] += reward
    log["reward_granted"] = granted
    log["reward_gold"] = reward
    log["stage"] = progress["stage"]
    log["gold"] = progress["gold"]
    return log
