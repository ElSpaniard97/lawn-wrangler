# Design notes (browser edition)

A design review of the Babylon edition using three lenses: design, architecture and game theory. Written 2026-10-10 with the PR that added the results card.

## Verdict

The yard looked and sounded good but the game had no real decisions: the riding mower alone could reach 99.2% of the lawn, past the old 99% finish line, so the weed eater was never needed and the timer was the only goal. The most important change was making the finish require every checklist item, which brings back the ride-then-trim loop the game was designed around.

## Intended experience and pillars

> "I plan neat passes on the mower, hop off at the right moments to trim the edges, and beat my last time."

| Pillar | Feature test | Anti-pillar |
| --- | --- | --- |
| Each tool has a job | Is there a place where the other tool is clearly better? | One tool that does everything |
| Efficiency is readable | After a run, can the player say where the time went? | A time with no explanation |
| Relaxed, never punishing | Can every mistake be fixed by driving back over it? | Fail states, lives, damage |

## Design findings

- Core loop (seconds): driving and cutting feel good, with stripes, clippings and sound. Collisions were silent: the mower just stopped. It now bumps with a thud, a small camera shake and lost speed (no shake when the system asks for reduced motion).
- Job loop (minutes): the finish line ignored the "Trim around objects" item. Now the yard is done when every item is ticked (98% each). When the lawn is past 95% the status line says to hop off and trim the glowing edges.
- Meta loop: only a best time. The new results card gives stars against par time and shows riding time, trimming time, refuels and bumps, so the player can see where time went and try again.
- Feedback: ticking a checklist item now plays a short blip.

## Architecture findings

- `lawn.js` owns all rules and stays engine-free, so it is tested with `node --test`. New rules live there: `DONE`, `PAR`, `stats`, and `events` (a per-step list such as `bump` and `finish`) that `main.js` turns into sound and camera effects.
- The finish check only computes the checklist once overall progress reaches 98%, so it costs nothing for most of the run.
- There is no telemetry server; the results card is the measurement, which keeps the static site private.

## Game theory findings

Area cut per second, the payoff of each tool on a cell both can reach:

| Tool | Speed | Cut width | Area per second |
| --- | --- | --- | --- |
| Riding mower | 4.0 m/s | 1.1 m | 4.4 m²/s |
| Weed eater | 2.2 m/s | 0.68 m | 1.5 m²/s |

The mower strictly dominates wherever it fits, which is fine, as long as some cells are out of its reach. Measured by sweeping every legal mower pose (tests/lawn.test.js does the same): the mower can reach 99.2% of the lawn but only 90.5% of edge cells. With a 99% overall finish the weed eater was dominated everywhere; with every item at 98% the player must trim about 8% of the edges on foot. The decision that remains is when and where to park the mower so the walk to the edges is short.

Blades off only saves fuel. A tidy run is about 1,000 m of driving against a 1,200 m tank, so fuel rarely forces a choice. That is left as is for now (see next ideas).

## Metrics and thresholds

Read from the results card after each run:

- Trimming share of the time: expect 15 to 35%. Under 10% means edges are too easy; over 40% means the mower reaches too little.
- Bumps: should fall below 5 by a player's second run. If not, the yard is too cramped or the camera hides obstacles.
- Stars: par is a guess (three stars under 7:00, two under 10:00) from a simulated lane-by-lane run of about 5 minutes plus trimming. If most second runs get three stars, lower `PAR[0]`; if almost nobody does, raise it.
- Refuels: 0 or 1. If players never refuel, fuel is decoration.

## Next experiment

Zeke and two or three friends each play two runs and note the four numbers on the results card. Tune `PAR` from that, and decide whether fuel should matter more.

## Next ideas, in order

1. Stripe neatness score: reward straight, consistent stripes on the results card (fits "pride in a neat lawn").
2. Fuel as a planning choice: a smaller tank so a run needs one planned refill.
3. Flower beds that lower the neatness score if mowed (a soft penalty, not a fail state), giving careful steering a reason to exist.
4. A second yard and a daily layout, already on the README idea list.
