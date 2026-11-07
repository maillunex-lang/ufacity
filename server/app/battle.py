"""Deterministic 5v5 preview. Does not grant rewards."""

from __future__ import annotations

import json
from pathlib import Path

MELEE = {"tank", "warrior"}
TICK = 0.1
LIMIT = 90.0
MELEE_RANGE = 1.6
RANGED_RANGE = 6.0
STEP = 1.4
URALDAR_REACH = 9.0

_FORMATION = Path(__file__).resolve().parents[2] / "client" / "data" / "formation.json"


def _load_slots() -> dict[int, tuple[float, float]]:
    rows = json.loads(_FORMATION.read_text(encoding="utf-8"))["slots"]
    if len(rows) != 5:
        raise ValueError("formation.json must list 5 slots")
    return {index: (float(row[0]), float(row[1])) for index, row in enumerate(rows)}


# Left faces +Z, right faces -Z. Front line is closer to the center.
SLOTS = _load_slots()


def _slot_pos(side: str, slot: int) -> tuple[float, float]:
    x, z = SLOTS[slot]
    if side == "left":
        return (x, -z)
    return (x, z)


def _dist(a: tuple[float, float], b: tuple[float, float]) -> float:
    return ((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2) ** 0.5


def _toward(src: tuple[float, float], dst: tuple[float, float], step: float) -> tuple[float, float]:
    d = _dist(src, dst)
    if d <= step or d == 0:
        return dst
    k = step / d
    return (src[0] + (dst[0] - src[0]) * k, src[1] + (dst[1] - src[1]) * k)


def _pick_target(actor: dict, foes: list[dict]) -> dict | None:
    alive = [u for u in foes if u["hp"] > 0]
    if not alive:
        return None
    if actor["role"] == "healer":
        return None
    front = [u for u in alive if u["slot"] in (0, 1)]
    pool = front or alive
    return min(pool, key=lambda u: (u["slot"], u["id"]))


def _perform(actor: dict, target: dict, allies: list[dict], events: list[dict], now: float, kind: str) -> None:
    if now >= actor["might_until"]:
        actor["might"] = 1.0
    if kind == "oath":
        actor["guard_until"] = round(now + 1.5, 2)
        actor["cooldown"] = 1.0 / max(actor["speed"], 0.1)
        events.append({"t": round(now, 2), "type": "skill", "name": "oath", "src": actor["id"], "amount": 0})
        return
    if kind == "spirit":
        until = round(now + 1.5, 2)
        for ally in allies:
            if ally["hp"] > 0:
                ally["might"] = 1.25
                ally["might_until"] = until
    amount = _strike(actor, target, now)
    if kind == "cleave":
        amount += 6
    target["hp"] = max(0, target["hp"] - amount)
    event_type = "attack" if kind == "attack" else "skill"
    row = {
        "t": round(now, 2),
        "type": event_type,
        "src": actor["id"],
        "dst": target["id"],
        "amount": amount,
        "hp": target["hp"],
    }
    if event_type == "skill":
        row["name"] = kind
    events.append(row)
    if target["hp"] == 0:
        events.append({"t": round(now, 2), "type": "down", "unit": target["id"]})
    actor["cooldown"] = 1.0 / max(actor["speed"], 0.1)


def _uraldar_action(actor: dict) -> str:
    if actor.get("model") != "uraldar":
        return "attack"
    actor["swing"] = int(actor.get("swing", 0)) + 1
    spot = (actor["swing"] - 1) % 4
    return ("attack", "cleave", "oath", "spirit")[spot]


def _strike(actor: dict, target: dict, now: float) -> int:
    power = actor["atk"] * float(actor.get("might", 1.0))
    amount = max(1, int(power) - target["def"] // 2)
    if now < target.get("guard_until", 0.0):
        amount = max(1, int(amount * 0.65))
    return amount


def _heal_target(allies: list[dict]) -> dict | None:
    alive = [u for u in allies if u["hp"] > 0]
    if not alive:
        return None
    return min(alive, key=lambda u: (u["hp"] / u["max_hp"], u["slot"]))


def make_unit(side: str, raw: dict) -> dict:
    slot = int(raw["slot"])
    role = raw["role"]
    max_hp = int(raw.get("hp", 100))
    return {
        "id": f"{side[0].upper()}{slot}",
        "side": side,
        "slot": slot,
        "role": role,
        "model": raw.get("model", "TEMP"),
        "hp": max_hp,
        "max_hp": max_hp,
        "atk": int(raw.get("atk", 10)),
        "def": int(raw.get("def", 0)),
        "speed": float(raw.get("speed", 1)),
        "pos": _slot_pos(side, slot),
        "cooldown": 0.0,
        "swing": 0,
        "guard_until": 0.0,
        "might": 1.0,
        "might_until": 0.0,
        "did_cleave": False,
        "did_oath": False,
        "did_spirit": False,
    }


def simulate(left: list[dict], right: list[dict], seed: int = 1) -> dict:
    if len(left) != 5 or len(right) != 5:
        raise ValueError("need exactly 5 units per side")
    units = [make_unit("left", u) for u in left] + [make_unit("right", u) for u in right]
    events: list[dict] = []
    t = 0.0
    # seed is accepted so a future crit table stays deterministic. Damage is currently fixed.
    _ = seed
    while t < LIMIT:
        alive_left = [u for u in units if u["side"] == "left" and u["hp"] > 0]
        alive_right = [u for u in units if u["side"] == "right" and u["hp"] > 0]
        if not alive_left or not alive_right:
            break
        for actor in sorted(units, key=lambda u: u["id"]):
            if actor["hp"] <= 0:
                continue
            actor["cooldown"] = max(0.0, actor["cooldown"] - TICK)
            foes = alive_right if actor["side"] == "left" else alive_left
            allies = alive_left if actor["side"] == "left" else alive_right
            if actor["role"] == "healer":
                target = _heal_target(allies)
                melee = False
            else:
                target = _pick_target(actor, foes)
                melee = actor["role"] in MELEE
            if target is None or target is actor:
                continue
            reach = MELEE_RANGE if melee else RANGED_RANGE
            gap = _dist(actor["pos"], target["pos"])
            lunging = (
                actor.get("model") == "uraldar"
                and actor["cooldown"] <= 0
                and t >= 0.45
                and gap <= URALDAR_REACH
            )
            if melee and gap > reach and not lunging:
                actor["pos"] = _toward(actor["pos"], target["pos"], STEP * TICK * actor["speed"])
                events.append({
                    "t": round(t, 2),
                    "type": "move",
                    "unit": actor["id"],
                    "to": [round(actor["pos"][0], 3), 0, round(actor["pos"][1], 3)],
                })
                continue
            if actor["cooldown"] > 0:
                continue
            if actor["role"] == "healer":
                amount = max(1, actor["atk"] - target["def"] // 2)
                healed = min(amount, target["max_hp"] - target["hp"])
                target["hp"] += healed
                events.append({
                    "t": round(t, 2),
                    "type": "heal",
                    "src": actor["id"],
                    "dst": target["id"],
                    "amount": healed,
                })
                actor["cooldown"] = 1.0 / max(actor["speed"], 0.1)
                continue
            if t >= actor["might_until"]:
                actor["might"] = 1.0
            kind = _uraldar_action(actor)
            _perform(actor, target, allies, events, t, kind)
        t = round(t + TICK, 2)
    left_hp = sum(u["hp"] for u in units if u["side"] == "left")
    right_hp = sum(u["hp"] for u in units if u["side"] == "right")
    if left_hp <= 0:
        winner = "right"
    elif right_hp <= 0:
        winner = "left"
    else:
        winner = "draw"
    return {
        "seed": seed,
        "winner": winner,
        "duration": round(min(t, LIMIT), 2),
        "reward_granted": False,
        "events": events,
        "units": [
            {"id": u["id"], "model": u["model"], "hp": u["hp"], "max_hp": u["max_hp"], "role": u["role"]}
            for u in units
        ],
    }
