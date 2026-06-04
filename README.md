# Cosmic Catch 🌟

A fast, mobile-friendly arcade catcher built with **Godot 4.6.3** and exported to the
web (single-threaded / `nothreads` WebGL2 build). Catch falling **stars** and **gems**
for points, dodge the spiky **bombs**, and chase a new best score.

Runs in Safari, Chrome, and Firefox on phones and desktops.

## How to play

- **Move:** drag anywhere on screen, or use the **← / →** (or **A / D**) keys.
- **Catch** stars (10 pts) and gems (30 pts) with the glowing catcher.
- **Avoid** bombs — catching one costs a life. Three lives, then it's game over.
- Build a **combo** by catching without missing: every 5 in a row adds a points
  multiplier.
- Difficulty ramps up as your score climbs — things fall faster and more often.
- Your **best score** is saved locally in the browser and survives reloads.

## Tech notes

- **Renderer:** Compatibility (OpenGL / WebGL2) — required for mobile browsers.
- **Export:** Web preset with `thread_support=false` (no SharedArrayBuffer, so it loads
  on hosts that don't send COOP/COEP headers).
- **Input:** dual touch + keyboard, with `emulate_mouse_from_touch` for desktop.
- **No backend:** the game is fully client-side; the high score persists via Godot's
  `user://` filesystem (IndexedDB on the web).
- All visuals are drawn procedurally in GDScript (no image assets), and sound effects are
  synthesized at runtime — so the project is tiny.

### Project layout

| File | Purpose |
| --- | --- |
| `project.godot` | Project config (Compatibility renderer, portrait viewport, touch). |
| `main.gd` | Game manager: spawning, scoring, lives, HUD, overlays, audio, persistence. |
| `catcher.gd` | The player's glowing catcher (procedural draw). |
| `falling_item.gd` | Falling stars / gems / bombs (procedural draw + movement). |
| `starfield.gd` | Animated twinkling starfield background. |
| `export_presets.cfg` | The `Web` (nothreads) export preset. |

## Building locally

Open the project in **Godot 4.6.3**, then export with the **Web** preset:

```bash
godot --headless --path . --import
godot --headless --path . --export-release "Web" out/index.html
```

Serve the `out/` folder over HTTP (a `.wasm` mime of `application/wasm` is required) and
open it in a browser:

```bash
npx serve out
```
