---
name: hero-data
description: >
  Данные героя, скилла, шмота и стадии как ресурсы, не как словари в сцене.
  Use when defining hero stats, skills, items, stages, or turning a definition into battle state.
---

# Данные героев

`HeroDef`, `SkillDef`, `ItemDef`, `StageDef` — отдельные данные, не словарь в сцене.
В Godot это custom `Resource`. На сервере те же поля, чтобы формула статов не разъехалась.

Статы: hp, atk, def, speed, crit, energy_gain.
Итог = база * рост от уровня * множитель возвышения + шмот.

Скилл: id, тип `basic` / `ultimate` / `passive`, цель, коэффициент, статус.
Стадия: вражеская пятёрка, уровни, награда.

id строковый и стабильный. Имя на экране отдельно, его можно менять.

Выход: поля ресурсов и как из определения героя собрать боевое состояние.
