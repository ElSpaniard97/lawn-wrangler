# Lawn Wrangler

A relaxing 3D landscaping game. Ride an orange mower across the open lawn,
hop off to trim along the fence and around the trees and flower beds with a
weed eater, and cut 99% of the grass to finish. Built with Godot 4 and
GDScript, and played in the browser.

[Play Lawn Wrangler](https://ElSpaniard97.github.io/lawn-wrangler/)

![Lawn Wrangler gameplay](screenshot.png)

## Features

- Riding mower with a chase camera, plus walking with a weed eater.
- The mower's blade is narrower than its body, so the strip along the fence
  and the edges of beds and tree rings need the weed eater.
- Two stripe shades depending on which way you mow; cut grass leaves short
  stubble and throws clippings, and tall grass sways in the breeze.
- Missed-patch highlight with H, switched on automatically at 95%.
- Progress, patches left, speed, time and your best time on screen.
- Pause with P / Esc, and an automatic pause when the game loses focus.
- Best time saved in your browser.

## Controls

| Key | Action |
| --- | --- |
| W / S or Up / Down | Drive or walk forward and back |
| A / D or Left / Right | Steer |
| Space | Hop off the mower, or back on when you are next to it |
| B | Mower blades on or off |
| H | Highlight grass you missed |
| P / Esc | Pause or resume |
| R | Restart the yard |

Click inside the game before using the keyboard. A keyboard and a desktop
browser with WebGL 2 are required.

## Work on the game

Install [Godot 4.7.2-stable](https://godotengine.org/download/archive/4.7.2-stable/)
(the standard build, not .NET), then open the `godot/` folder in it and press
Play. From the command line, with `godot` on your path:

```bash
godot --headless --path godot --import
godot --headless --path godot --script res://tests/run_tests.gd
godot --headless --path godot --export-release Web ../site/play/index.html
cp web/index.html site/index.html
python3 -m http.server 9000 --directory site
```

Then open http://localhost:9000. Download Godot only from godotengine.org or
its GitHub releases page.

## How it is published

Every push to `main` runs the tests, exports the game to `site/play/` and
deploys `site/` to GitHub Pages. Pull requests run the tests only. CI
downloads the exact Godot version and checks its SHA-512 sums in
`.github/scripts/setup-godot.sh` before using it; to upgrade Godot, change the
version and both sums there, and the version noted in `godot/project.godot`.

## Project layout

- `godot/scenes/yard.tscn` and `godot/scripts/yard.gd`: builds the yard,
  handles hopping off and on, keys, and finishing.
- `godot/scripts/lawn_grid.gd`: which grass is cut. The one source of truth
  for cutting, progress and the stripes.
- `godot/scripts/lawn_view.gd`: draws the ground stripes and the chunked
  grass clumps, and the missed-patch highlight.
- `godot/shaders/grass.gdshader`: grass colour, breeze sway and highlight.
- `godot/scripts/mower.gd`, `godot/scripts/walker.gd`: driving, walking and
  cutting.
- `godot/scripts/chase_camera.gd`: camera that follows whoever you control.
- `godot/scripts/run_state.gd`: timer, pause and the saved best time.
- `godot/scripts/hud.gd`: on-screen panels and messages.
- `godot/scripts/models.gd`: placeholder meshes, replaced with real models
  in a later phase.
- `godot/tests/run_tests.gd`: headless tests, run in CI before every deploy.
- `web/index.html`: the landing page that frames the game.

## Roadmap

The full plan is in the project's improvement plan document.

| Phase | Status |
| --- | --- |
| Security and CI hardening | Done |
| 0. 3D export spike | Done |
| 1. Graybox gameplay: weed eater, hop off/on, tests ported | Done |
| 2. Grass polish: stubble, sway, clippings, gap-free cutting | Done |
| 3. Visual slice: real models, sound, landscaping | Next |
| 4. Optimize and QA, quality presets | Planned |
| 5. Release | Planned |

The original Python/pygame version was replaced by the Godot version. It is
still in the git history before the merge that removed it.
