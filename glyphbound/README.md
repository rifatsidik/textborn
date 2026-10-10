# GLYPHBOUND — Character Lab v0.1

A standalone Godot 4 prototype for a side-view human character rendered from runtime text glyphs rather than a PNG character sprite.

## Run

1. Open the `glyphbound/` folder in Godot 4.7.x.
2. Run the project (main scene: `res://scenes/character_lab.tscn`).

## Controls

- **Right Arrow** — walk when in idle mode.
- **Enter / Space** — cycle animation pose.
- **Left Arrow** — previous pose.

## Prototype scope

- Procedural head, torso, arm, hand, hip, knee, ankle and foot contours.
- Glyph characters are drawn at runtime along the articulated outline.
- Idle, walk, run, jump and attack pose studies.
- Dark technical canvas with monochrome glyphs and restrained cyan accents.

## Current limitations

This is an early visual proof-of-concept, not the final production renderer. The limbs use procedural pose points rather than a full skeletal rig. Validate and iterate in Godot before expanding the renderer or integrating survivor gameplay.
