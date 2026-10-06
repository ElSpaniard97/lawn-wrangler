# Lawn Wrangler

A relaxing landscaping game: mow clean stripes across the open lawn, hop off to
trim around trees, flower beds, the house, and fence, and cut 99% to finish.
Built with Python, pygame-ce, and pygbag for desktop and browser play.

![Lawn Wrangler gameplay](screenshot.png)

## Features

- Riding mower and weed eater with different speeds and cutting reach.
- Light and dark stripes based on mowing direction, plus flying grass clippings.
- Circular tree collisions and a solid parked mower.
- Pause with P / Escape; automatic pause when the game loses focus.
- Remaining-grass highlighting with H, automatically enabled at 95% completion.
- Remaining-patch count, elapsed time, and persistent personal best times.
- Refreshed yard graphics and a responsive green-and-cream browser page with
  visible controls and fullscreen support.

## Controls

| Key | Action |
| --- | --- |
| Arrow keys / WASD | Move |
| Space | Dismount, or remount when next to the mower |
| P / Escape | Pause or resume |
| H | Highlight remaining grass |
| R | Restart the yard |

Click inside the browser game before using the keyboard. Mow horizontally for
light stripes and vertically for dark stripes. A keyboard is required.

## Run on desktop

Python 3.9 or newer is required. From the repository root:

```bash
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python game/main.py
```

On Windows, activate with `.venv\Scripts\activate` instead.
Best times are stored in `~/.lawn-wrangler-best.json` on desktop and browser
localStorage on the web. Records stay on the current device/browser; clearing
browser site data removes the web record. If storage is unavailable, the record
remains available for the current session.

## Play and build for the browser

[Play Lawn Wrangler](https://ElSpaniard97.github.io/lawn-wrangler/).
GitHub Actions builds and publishes the game and landing page on pushes to `main`.

For the standard pygbag development server:

```bash
python -m pygbag game
```

Open http://localhost:8000. To preview the complete redesigned page:

```bash
python -m pygbag --build game
mkdir -p site/play
cp -R game/build/web/. site/play/
cp web/index.html site/index.html
python -m http.server 9000 --directory site
```

Open http://localhost:9000. Use port 9000 for this static preview: pygbag reserves
localhost:8000 for its development dependency proxy. The browser runtime downloads
from the pygame-web CDN, so first launch requires an internet connection.

## Tests and project layout

```bash
SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy python -m unittest discover -s tests
```

The regression checks cover pause behavior, timing, tree and parked-mower
collisions, cutting counts, record persistence, and rendering of game states.

- `game/main.py` — gameplay, yard rendering, HUD, and record storage.
- `web/index.html` — browser landing page and fullscreen control.
- `tests/test_game.py` — gameplay regression checks.
- `.github/workflows/pages.yml` — browser build and Pages deployment.

## 3D preview (Godot)

`godot/` holds the Phase 0 test yard from the improvement plan: a 20 x 20 m
lawn with a fence, a tree, a flower bed, a placeholder mower and a chase
camera. It is published at `/preview-3d/` next to the current game.

It is built with Godot 4.7.2-stable (GDScript, Compatibility renderer,
single-threaded web export). CI downloads that exact version and checks it
against pinned SHA-512 sums in `.github/scripts/setup-godot.sh`. Open the
`godot/` folder in the same Godot version to edit it locally, then run:

```bash
godot --headless --path godot --import
godot --headless --path godot --script res://tests/run_tests.gd
godot --headless --path godot --export-release Web ../site/preview-3d/index.html
```

- `godot/scripts/lawn_grid.gd` — which grass is cut; the one source of truth.
- `godot/scripts/lawn_view.gd` — ground stripes and chunked grass clumps.
- `godot/scripts/mower.gd` — driving, cutting and the placeholder model.
- `godot/scripts/run_state.gd` — timer, pause and the saved best time.
- `godot/tests/run_tests.gd` — headless checks run in CI before export.

## Next graphics direction

The next phase targets a third-person 3D presentation inspired by the supplied
visual reference: detailed residential landscaping, an orange riding mower,
textured tall grass and cut stripes, sunlight and shadows, and an immersive HUD.
This is a planned engine/rendering upgrade; the current playable version remains
the top-down Pygame game. Further ideas include audio, fuel, more yards, and a
leaderboard.
