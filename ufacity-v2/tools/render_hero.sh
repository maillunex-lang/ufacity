#!/usr/bin/env bash
# GLB -> sprite atlas. Usage: ufacity-v2/tools/render_hero.sh <hero> [--fps=30 --yaw=25 --pitch=18 --out=DIR]
# Needs xvfb-run (software GL). Source GLBs are only read, never modified.
set -euo pipefail
HERO="$1"; shift
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$ROOT/assets/sprites/$HERO"
xvfb-run -a -s "-screen 0 800x600x24" env LIBGL_ALWAYS_SOFTWARE=1 \
  "${GODOT:-$HOME/tools/godot}" --path "$ROOT/art_src" --rendering-driver opengl3 --resolution 512x512 \
  res://render/render_hero.tscn -- --hero="$HERO" --out="$OUT" "$@" 2>&1 | grep -vE "^Godot Engine|libasound|audio driver|audio_server|^\s*$"
