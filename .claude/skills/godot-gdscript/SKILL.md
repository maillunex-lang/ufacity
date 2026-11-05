---
name: godot-gdscript
description: >
  Пишет типизированный GDScript для Godot 4 в idle-арене 5 на 5.
  Use when writing a script, signal, @export, @onready, await, or Godot 4 node lifecycle.
---

# GDScript для Godot 4

Статическая типизация. `class_name` ставить там, где тип переиспользуется.

Движение и хитбоксы в `_physics_process`. `_process` только для визуала.
Не вызывать `get_node` по длинному пути каждый кадр. Кэш через `@onready`.
Сигнал вместо прямой ссылки на чужую ноду.

Боевые числа не хранить в нодах. Их считает симулятор, сцена только показывает лог.

Не использовать API Godot 3: `yield`, `KinematicBody`, `move_and_slide` с аргументом.
Если версия редактора не 4.7, не выдумывать методы. Сначала сверить с докой этой версии.

Выход: скрипт, на какую ноду его вешать, какие поля `@export`.
