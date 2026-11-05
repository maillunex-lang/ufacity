---
name: github-godot
description: >
  Как лежат в git исходники Godot и сервера этого репозитория.
  Use when adding gitignore, Git LFS, export presets, secrets, or splitting client and server.
---

# Git для этого репозитория

Клиент в `client/`, сервер в `server/`.
В `main` только то, что собирается. Боевые числа менять отдельным коммитом, чтобы откат баланса был виден.

Не коммитить: `.godot/`, билды, `.env`, ключи подписи Android, пароли базы, TLS-ключи, ключ Meshy.
`export_presets.cfg` можно коммитить, если в нём нет пароля и пути к ключу. Сам ключ не коммитить.

GLB, FBX, wav, ogg и mp3 идут через Git LFS. Это уже задано в `.gitattributes`.
Мелкие PNG интерфейса через LFS не гнать.

README держать в актуальном состоянии: версия Godot, как поднять API локально, какой URL ждёт клиент.

Выход: что именно меняется в git и чего в коммите не будет.
