# Ufacity

Idle 3D-арена 5 на 5. Клиент на Godot 4, один API на своём VPS, исходники здесь.

Это не копия чужой игры. Формация и айдл-прогрессия свои, герои и арт свои.

## Папки

| Путь | Что там |
|---|---|
| `client/` | проект Godot |
| `server/` | API, который считает бой, награды и призыв |
| `.claude/skills/` | скиллы Claude Code |
| `.agents/skills/` | те же скиллы для Codex |

Пока папок игры нет: git не хранит пустые каталоги. Они появятся с первым файлом.

Тексты скиллов в двух папках одинаковые. Правило меняется сразу в обеих.

## Claude Code

```bash
claude
```

Дальше `/skills`. Вручную: `/auto-battle`, `/meshy-godot`, `/idle-server`.

Правила каждого сеанса: [CLAUDE.md](CLAUDE.md).

## Codex

```bash
codex
```

Дальше `/skills`. Вручную: `$auto-battle`, `$meshy-godot`, `$idle-server`.

Правила каждого сеанса: [AGENTS.md](AGENTS.md).

## Секреты

Шаблон окружения: [.env.example](.env.example). Настоящий `.env` не коммитить.

Тяжёлые модели и звук идут через Git LFS. Один раз на машине:

```bash
git lfs install
```
