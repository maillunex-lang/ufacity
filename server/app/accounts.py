"""Accounts stay in memory until Postgres is attached. A restart drops them."""

from __future__ import annotations

import hashlib
import hmac
import secrets


def _hash(password: str) -> str:
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 120_000).hex()
    return f"{salt}${digest}"


def _check(password: str, stored: str | None) -> bool:
    if not stored or "$" not in stored:
        return False
    salt, digest = stored.split("$", 1)
    got = hashlib.pbkdf2_hmac("sha256", password.encode(), salt.encode(), 120_000).hex()
    return hmac.compare_digest(got, digest)


class Store:
    def __init__(self) -> None:
        self.users: dict[str, dict] = {}
        self.by_login: dict[str, str] = {}
        self.tokens: dict[str, str] = {}

    def reset(self) -> None:
        self.users.clear()
        self.by_login.clear()
        self.tokens.clear()

    def guest(self) -> str:
        uid = secrets.token_hex(8)
        login = f"guest-{uid[:6]}"
        self.users[uid] = self._blank(uid, login, "guest", None)
        self.by_login[login] = uid
        return self._issue(uid)

    def register(self, login: str, password: str) -> str:
        self._valid_login(login, password)
        if login in self.by_login:
            raise ValueError("login taken")
        uid = secrets.token_hex(8)
        self.users[uid] = self._blank(uid, login, "account", _hash(password))
        self.by_login[login] = uid
        return self._issue(uid)

    def login(self, login: str, password: str) -> str:
        uid = self.by_login.get(login)
        if uid is None or not _check(password, self.users[uid]["password"]):
            raise ValueError("bad credentials")
        return self._issue(uid)

    def bind(self, token: str, login: str, password: str) -> dict:
        user = self.user_for(token)
        if user["kind"] != "guest":
            raise ValueError("already bound")
        self._valid_login(login, password)
        if login in self.by_login:
            raise ValueError("login taken")
        del self.by_login[user["login"]]
        user["login"] = login
        user["kind"] = "account"
        user["password"] = _hash(password)
        self.by_login[login] = user["id"]
        return user

    def user_for(self, header: str) -> dict:
        token = header.removeprefix("Bearer ").strip()
        uid = self.tokens.get(token)
        if not uid:
            raise ValueError("unauthorized")
        return self.users[uid]

    def set_formation(self, user: dict, formation: list[str]) -> None:
        if len(formation) != 5 or len(set(formation)) != 5:
            raise ValueError("formation needs 5 ids")
        user["progress"]["formation"] = list(formation)

    def _blank(self, uid: str, login: str, kind: str, password: str | None) -> dict:
        return {
            "id": uid,
            "login": login,
            "kind": kind,
            "password": password,
            "progress": {"stage": 1, "gold": 0, "formation": []},
        }

    def _issue(self, uid: str) -> str:
        token = secrets.token_urlsafe(24)
        self.tokens[token] = uid
        return token

    def _valid_login(self, login: str, password: str) -> None:
        if len(login) < 3 or len(password) < 8:
            raise ValueError("login or password too short")
