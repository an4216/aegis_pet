# DDUNGSIL 14-state remake handoff

## Scope

All 14 animated states use the same remade character system for all three tiers:

- `base`: orange tabby, no accessory
- `evolved`: white office collar and centered navy tie
- `evolved2`: polished gold chain and round medallion

The shared identity is a huge round orange tabby with a cream muzzle and belly, large glossy brown eyes, blush, a warm dark-brown outline, and soft pastel hand-painted shading. Runtime registrations no longer mix prior state art with the remade Idle/Walk art.

## Runtime sheets

Each tier folder contains the complete set below:

| State | Sheet | Grid | Frames | Runtime |
|---|---|---:|---:|---|
| Idle | `idle_4f_remake.png` | 4×1 | 4 | loop, 4 fps |
| Walk | `walk_8f_remake.png` | 4×2 | 8 | loop, 10 fps |
| Sleep | `sleep_6f_remake.png` | 6×1 | 6 | loop, 4 fps |
| Eat | `eat_4f_remake.png` | 4×1 | 4 | loop, 6 fps |
| Sick | `sick_6f_remake.png` | 6×1 | 6 | loop, 5 fps |
| Sulk | `sulk_6f_remake.png` | 6×1 | 6 | loop, 5 fps |
| Play | `play_6f_remake.png` | 6×1 | 6 | loop, 8 fps, airborne |
| Dragged | `dragged_4f_remake.png` | 4×1 | 4 | loop, 10 fps, airborne |
| Fall | `fall_4f_remake.png` | 4×1 | 4 | once, 12 fps, airborne |
| Land | `land_4f_remake.png` | 4×1 | 4 | once, 10 fps |
| FileHover | `file_hover_4f_remake.png` | 4×1 | 4 | once, 12 fps |
| FileConsume | `file_consume_4f_remake.png` | 4×1 | 4 | once, 12 fps |
| Poop | `poop_6f_remake.png` | 6×1 | 6 | loop, 6 fps |
| Pet | `pet_6f_remake.png` | 6×1 | 6 | once, 10 fps |

Tier directories: `assets/sprites/ddungsil/`, `assets/sprites/ddungsil_evolved/`, and `assets/sprites/ddungsil_evolved2/`.

Every frame cell is 192×208 RGBA. Grounded states use a measured 16 px bottom baseline. Play, Dragged, and Fall retain their per-frame airborne padding curves. Horizontal offsets are measured from visible alpha and remain within ±0.5 px. All 42 imports generate mipmaps.

## Evidence

- [14-state runtime board](ddungsil-remake-14state-runtime.png): Godot 4.4.1 OpenGL capture, adult runtime scale, neutral and peak frames for all 42 state/tier combinations.
- [14-state full-frame contact](ddungsil-remake-14state-contact.png): every source frame from all 42 runtime sheets.
- [12-state production contact](ddungsil-remake-12state-contact.png): detailed view of the 36 newly added state sheets.

## Verification

- Godot import completed with mipmaps enabled for all 36 newly added sheets.
- Full project regression: `5111 passed, 0 failed`.
- Visible-alpha audit: correct frame counts, zero occupied pixels on every cell edge, exact registered foot padding, and maximum horizontal offset 0.5 px.
