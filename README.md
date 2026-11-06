# Ufacity

Вертикальная 3D idle RPG, бой 5 на 5. Клиент на Godot 4, API на своём VPS, исходники здесь.

Это не копия чужой игры. Формация и прогрессия свои, герои и арт свои.

Состояние этапов: [docs/ROADMAP.md](docs/ROADMAP.md). Аудит, после которого начался код: [docs/AUDIT.md](docs/AUDIT.md).

## Папки

| Путь | Что там |
|---|---|
| `client/` | проект Godot, пока с временными капсулами TEMP |
| `server/` | API. Health и предварительный бой без выдачи наград |
| `docs/` | аудит, архитектура, выкладка, модели |
| `.claude/skills/` | скиллы Claude Code |
| `.agents/skills/` | те же скиллы для Codex |

Тексты скиллов в двух папках одинаковые. Правило меняется сразу в обеих.

## Проверка API

```bash
cd server
python -m pip install -r requirements.txt
PYTHONPATH=. python -m pytest -q
PYTHONPATH=. uvicorn app.main:app --host 127.0.0.1 --port 8080
```

Godot-редактор этот проект ещё не открывал. Android APK не собирался.

## Claude Code и Codex

Claude: `claude`, затем `/skills`. Codex: `codex`, затем `$auto-battle`.

Правила сеанса: [CLAUDE.md](CLAUDE.md) и [AGENTS.md](AGENTS.md).

## Секреты

Шаблон окружения: [.env.example](.env.example). Настоящий `.env` не коммитить.

Тяжёлые модели и звук идут через Git LFS. Один раз на машине:

```bash
git lfs install
```
