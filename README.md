# Lawn Wrangler

![Lawn Wrangler screenshot](screenshot.png)

A small top-down landscaping game written in Python with pygame. Ride the
mower to cut the big open areas, then hop off and use the weed eater to trim
the edges around the house, trees, flower beds and fence. Cut 99% of the lawn
to finish the yard.

## Controls

| Key | Action |
| --- | --- |
| Arrow keys / WASD | Move |
| Space | Hop off the mower, or back on when you're next to it |
| R | Restart |

Mow side to side for light stripes and up and down for dark ones.

## Run it on your computer

```bash
pip install -r requirements.txt
python game/main.py
```

## Play it in the browser

The game is built for the web with [pygbag](https://pypi.org/project/pygbag/)
and published with GitHub Pages by `.github/workflows/pages.yml`, on every push
to `main`. To try the web build locally:

```bash
python -m pygbag game
```

then open http://localhost:8000.

## Ideas for what to add next

- Sound effects for the mower engine and weed eater
- Fuel for the mower and a gas can to refill it
- More yards (levels) with different layouts
- A best-time leaderboard
