---
name: godot-arena-3d
description: >
  Собирает 3D-арену Godot 4 для автобоя 5 на 5, без открытого мира.
  Use when building the arena scene, formation markers, camera, light, or placing heroes.
---

# Арена 5 на 5

Одна сцена Arena: пол, `DirectionalLight3D`, `WorldEnvironment`, `Camera3D` сбоку-сверху.
Камера статичная, вся формация в кадре. Свободного полёта нет.

10 маркеров позиций, имена фиксированные.
На каждую сторону: `front_0`, `front_1`, `back_0`, `back_1`, `back_2`.

Герой на арене: `Node3D` плюс модель плюс `AnimationPlayer`.
Без `CharacterBody3D` и без `NavigationAgent3D`.

Бой не считать физикой. Сцена ставит модель на маркер и играет клип.

Выход: дерево сцены и кто за что отвечает.
