# Ufacity V2 — прогресс

## Этап A — 2026-11-07 ✅
- Состояние Git: ветка была `fix/battle-simulation-v1`, 9 изменённых и ~10 неотслеживаемых файлов.
- Сохранено: коммит `c5c0e39` в ветке `backup/pre-v2-20261107` + архив `~/backups/ufacity-pre-v2-20261107.tgz`. Не включены `.claude/settings.local.json`, `.env`, `.godot/`.
- Создана ветка `feature/ufacity-v2` (от бэкап-коммита) и каталог `ufacity-v2/` со слоями core/view/ui/data/assets/tests.
- Godot 4.7.2.stable подтверждён (`/home/gamedev/tools/godot`, Godot MCP отвечает). Нагрузка VPS ~0, диск 50 ГБ свободно.
- Предварительный аудит GLB (3 героя: priest, swordsman, uraldar): клипы Mixamo-стиля, длины 0.6–6.2 с; у swordsman нет Hit, у priest/uraldar нет полного набора Attack/Skill под нужные имена — маппинг клипов на Idle/Run/Attack/Hit/Skill/Death будет решён в этапе B/D.

## Этап B — 2026-11-07 ✅
Ветки `backup/pre-v2-20261107` и `feature/ufacity-v2` отправлены в origin (без force, main не тронут).

**Импорт.** `priest.glb`, `swordsman.glb`, `uraldar.glb` скопированы (байт-в-байт, `cmp`) в `ufacity-v2/assets/heroes/`; оригиналы в `client/` не изменены. GLB идут через Git LFS. Текстуры, которые Godot сам извлекает из GLB, в git не кладутся (`.gitignore`), пересоздаются при импорте.

**Совместимость с Godot 4.7.2.** `godot --headless --import` без ошибок. Все 3 модели загружаются, 24 кости `mixamorig_*` (+ `headfront`), один материал, масштаб корня применён.

**Находки аудита (`tests/audit_assets.gd`, `~/tools/v2/audit_glb.py`):**
| Герой | Рост, м | Треугольники | Текстура | Стиль |
|---|---|---|---|---|
| priest | 1.10 | 9 826 | 1 PNG | чиби |
| swordsman | 1.70 | 10 543 | 1 PNG | реалистичный аниме |
| uraldar | 1.80 | 21 089 | 3 JPG | реалистичный аниме |

- Модели смотрят в **+Z**; для боя нужен поворот на арене (команда А → +Z/−Z по построению).
- Все клипы импортируются с `loop_mode = none`: Idle и Run нужно зациклить в коде.
- **Сдвиг бёдер (root motion)** в клипах (кости в см): `Hit_Reaction` priest 38, uraldar 101; `Thrust_Slash` ~28; `Jump_and_Slam_Back_Down` ~23; `Dead` до 90. `Running`/`Walking` замкнуты (сдвиг 0 между первым и последним ключом) — но смещение внутри цикла надо мерить в этапе D. План: вырезать позиционные дорожки Hips (сделано для заимствованного клипа в `view/model_check.gd`).
- Разный рост (чиби 1.1 м против 1.7–1.8 м): нормализация масштаба — решение этапа C.
- Клипы длинные (атака 2.2–3.2 с). Момент удара внутри клипа ещё не измерен — этап D.

**Клипы героев → роли** (`data/hero_assets.json`):
| Роль | priest | swordsman | uraldar |
|---|---|---|---|
| Idle | Idle_11 (1.87 с) | Idle_9 (2.00 с) | Combat_Stance (1.67 с) |
| Run | Running (0.63 с) | Running (0.63 с) | Running (0.63 с) |
| Attack | Attack (2.80 с) | Thrust_Slash (3.00 с) | Thrust_Slash (3.00 с) |
| Hit | Hit_Reaction (1.63 с) | **нет** → заимствован Hit_Reaction priest без позиционных дорожек | Hit_Reaction (1.63 с) |
| Skill | Charged_Spell_Cast (2.67 с) | Jump_and_Slam_Back_Down (2.73 с) | Skill_01 (1.07 с) |
| Death | Dead (2.97 с) | Dead (2.97 с) | Dead (2.97 с) |
Остальные клипы (не в боевом наборе): priest — Walking; swordsman — Walking; uraldar — Walking, Charged_Slash (2.20), Left_Slash (3.17), Sword_Shout (6.17).

**Тестовая сцена** `scenes/model_check.tscn` (`view/model_check.gd`): ставит героев в ряд и проигрывает все 6 ролей. Headless: `MODEL_CHECK failures=0`, выход 0. Снимок через Xvfb: `docs/v2_shots/stageB_model_check.png` (3 героя с текстурами, лицом к камере).

**Состояние:** в наборе пока 3 героя; для 10 слотов нужны повторы (по 5 на сторону) или новые модели.
