# Ufacity

Вертикальная 3D idle RPG, бой 5 на 5. Клиент на Godot 4, API на своём VPS, исходники здесь.

Это не копия чужой игры. Формация и прогрессия свои, герои и арт свои.

Состояние этапов: [docs/ROADMAP.md](docs/ROADMAP.md). Аудит, после которого начался код: [docs/AUDIT.md](docs/AUDIT.md).

## Папки

| Путь | Что там |
|---|---|
| `client/` | Godot 4. Сцены города и боя, GLB мечника и жреца через Git LFS |
| `server/` | API: health, бой без наград, гость в памяти процесса |
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

Godot 4.7.2 этот проект импортировал и собирал. Модели качаются так: `git lfs pull`. Отладочный APK для телефона лежит в GitHub Releases (последний тег `v0.1.4-debug`), это не артефакт Actions. Подпись debug, не для магазина. Папка `client/android/` после экспорта не коммитится.

## Claude Code и Codex

Claude: `claude`, затем `/skills`. Codex: `codex`, затем `$auto-battle`.

Правила сеанса: [CLAUDE.md](CLAUDE.md) и [AGENTS.md](AGENTS.md).

## Секреты

Шаблон окружения: [.env.example](.env.example). Настоящий `.env` не коммитить.

Тяжёлые модели и звук идут через Git LFS. Один раз на машине:

```bash
git lfs install
```
