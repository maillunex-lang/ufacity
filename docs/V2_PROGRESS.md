# Ufacity V2 — прогресс

## Этап A — 2026-11-07 ✅
- Состояние Git: ветка была `fix/battle-simulation-v1`, 9 изменённых и ~10 неотслеживаемых файлов.
- Сохранено: коммит `c5c0e39` в ветке `backup/pre-v2-20261107` + архив `~/backups/ufacity-pre-v2-20261107.tgz`. Не включены `.claude/settings.local.json`, `.env`, `.godot/`.
- Создана ветка `feature/ufacity-v2` (от бэкап-коммита) и каталог `ufacity-v2/` со слоями core/view/ui/data/assets/tests.
- Godot 4.7.2.stable подтверждён (`/home/gamedev/tools/godot`, Godot MCP отвечает). Нагрузка VPS ~0, диск 50 ГБ свободно.
- Предварительный аудит GLB (3 героя: priest, swordsman, uraldar): клипы Mixamo-стиля, длины 0.6–6.2 с; у swordsman нет Hit, у priest/uraldar нет полного набора Attack/Skill под нужные имена — маппинг клипов на Idle/Run/Attack/Hit/Skill/Death будет решён в этапе B/D.
