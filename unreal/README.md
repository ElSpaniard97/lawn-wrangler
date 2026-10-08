# Lawn Wrangler for Unreal Engine 5

This folder is the Unreal Engine 5 version of Lawn Wrangler. It sits beside
the Godot version in `godot/`, which stays the game people play in the
browser. Unreal gives us Lumen lighting, Nanite and photo-scanned plants,
houses and rocks from Fab (Quixel Megascans), so it can get much closer to
the reference picture. Unreal cannot export to the web, so this version is
for downloads only.

## What is already done (C++, in `Source/LawnWrangler`)

The gameplay is ported from Godot. You will not need to write any code to
get it running:

- `LawnGridComponent`: the lawn as 25 cm cells, with cutting, stripes, and
  a mask texture for the ground material and the minimap.
- `LawnMower`: the zero-turn mower. It drives, steers, burns fuel, crawls
  on an empty tank and cuts with a blade that is narrower than its body.
- `LawnWalker`: the landscaper on foot, who trims with a weed eater.
- `LawnYard`: the 30 x 36 m yard. It holds the colliders for the fence,
  house, porch, beds, trees and patio, the grass, the red gas can, the
  checklist, the timer and your best time, and it handles hopping on and
  off.
- `LawnHUD`: the on-screen checklist, progress bar, minimap, speedometer,
  fuel gauge, keyboard or gamepad prompts, and the pause and finish screens.
- `LawnPlayerController` and `LawnGameMode`: pause, restart and gamepad
  detection.
- `Config/DefaultInput.ini`: keyboard and gamepad controls (W/S or the
  triggers to drive, A/D or the left stick to steer, B or X for the blades,
  Space or Y to hop, P or Start to pause, R or Back to restart).
- `Private/Tests`: automation tests for the grid and the checklist.

- `LawnArt` and the stand-in shapes: until Fab art is added, the yard,
  mower and landscaper are drawn from the engine's basic shapes, and the
  game mode adds the yard, sun and sky to an empty level by itself, so the
  game is playable straight after the first build.

Making it look real happens in the Unreal editor: Fab models and
materials, and a few Blueprints that point the code at them. Unreal saves
these as binary files that only the editor can make. Section 4 walks
through them.

## 1. Install (once)

You need about 100 GB of free disk space.

1. Install the **Epic Games Launcher** from
   [unrealengine.com](https://www.unrealengine.com/download) and sign in
   with a free Epic account.
2. In the launcher, open **Unreal Engine > Library** and install the newest
   **5.x** version.
3. Install the C++ tools Unreal uses to build our code:
   - **Mac:** install **Xcode** from the App Store, open it once and accept
     its licence.
   - **Windows:** install **Visual Studio 2022 Community** with the
     **Game development with C++** workload.
4. Get the code with [GitHub Desktop](https://desktop.github.com/): use
   **File > Clone repository** and pick `ElSpaniard97/lawn-wrangler`.

## 2. Open the project

1. In the cloned folder, open `unreal/LawnWrangler.uproject`. If it asks
   which engine version to use, pick the one you installed. On a Mac you
   can also open it from the launcher with **Library > Browse**.
2. When it says the **LawnWrangler** module is missing or out of date,
   click **Yes** to rebuild it. The first build takes a few minutes.
3. If the build fails, copy the error text into our thread and I'll fix
   the code.

## 3. Play

Press **Play** in the toolbar. There is nothing to set up first: the
project opens the engine's empty level, and the game mode fills it with the
yard, the sun and the sky. Until real art is added, everything is drawn
with simple shapes: an orange mower with its driver, a carpet of grass
tiles that turns into light and dark stripes as you mow, the fence, the
house and porch, shrub beds, trees, flower beds and the patio. Click in the
game window, then drive with W/S and A/D (or a gamepad).

## 4. Swap in real art (optional)

When you want it to look like the reference picture, add art from Fab and
point the code at it:

1. **Your own level:** use **File > New Level > Basic** and save it as
   `Content/Maps/Yard`. Delete its default floor; the yard brings its own
   ground. Then, in **Edit > Project Settings > Maps & Modes**, set both
   default maps to `Yard`.
2. **The yard Blueprint:** in the Content Browser, choose **Add > Blueprint
   Class**, open **All Classes**, search for **LawnYard**, and name the new
   Blueprint `BP_Yard`. Drag it into the level and set its location to
   **0, 0, 0**. A level with its own yard keeps it; no second one is made.
3. **Grass:** open **Window > Fab**, search for a free Megascans grass
   clump, and add it to the project. In `BP_Yard`, set **Grass Mesh** to
   that mesh.
4. **Ground material:** make a material called `M_Lawn` with:
   - a **TextureSampleParameter2D** named exactly `CutMask`, with its
     sampler type set to **Linear Color**;
   - **Lerp** nodes that use the mask's **G** channel to pick between the
     dark stripe colour and the light stripe colour, and its **R** channel
     to blend in the tall grass colour;
   - a Megascans grass texture multiplied in, for detail.

   Connect the result to **Base Color** and set **Roughness** to 0.9. Then,
   in `BP_Yard`, set **Ground Material** to `M_Lawn`. If the stripes come
   out turned sideways, swap the U and V inputs of the texture sample.
5. **Mower:** make a Blueprint from **LawnMower** called `BP_Mower`. Set its
   **Body** mesh to a mower model from Fab; the stand-in shapes hide
   themselves once Body has a different mesh. The front of the model must
   point along +X (the red arrow). In `BP_Yard`, set **Mower Class** to
   `BP_Mower`.
6. **Landscaper:** make a Blueprint from **LawnWalker** called `BP_Walker`.
   For its **Body**, use the Unreal mannequin (**Add > Add Feature or
   Content Pack > Third Person** adds it) or a MetaHuman. In `BP_Yard`, set
   **Walker Class** to `BP_Walker`.
7. Once the level has real houses, fences and plants, untick **Stand In
   Art** in `BP_Yard`. If the level has its own sun, the yard does not add
   one.

## 5. Where things go

The colliders and blocked grass are already in place, so put real art where
they are. Positions are in centimetres from the yard's back-left corner.
**X** runs across the yard and **Y** runs from the back fence (Y = 0)
towards the street (Y = 3600).

| What | Where |
| --- | --- |
| Privacy fence, 1.8 m tall | Round the edge: X 0 to 3000, Y 0 to 3600 |
| House, 10 x 12 m, porch facing +X | Centre X 500, Y 1900 (fills X 0 to 1000, Y 1300 to 2500) |
| Porch deck, steps and landing | X 1000 to 1400, Y 1580 to 2220 |
| Red gas can | X 1350, Y 1660 |
| Shrub beds | X 1000 to 1150 by Y 1300 to 1580; X 1000 to 1150 by Y 2220 to 2500; X 300 to 1700 by Y 0 to 140; X 2860 to 3000 by Y 1000 to 2400 |
| Trees in stone rings (60 cm) | (2000, 800), (2400, 2800), (600, 3100) |
| Round flower beds | (2500, 1750) radius 130; (1400, 600) radius 100 |
| Patio with pergola, table and chairs | X 2150 to 3000, Y 0 to 750 |
| Mower start | (1600, 3050), facing the back fence |

Neighbours' houses, more trees, a **Sky Atmosphere**, **Volumetric Clouds**
and an **Exponential Height Fog** outside the fence finish the picture.
Lumen and virtual shadows are already switched on in
`Config/DefaultEngine.ini`.

## 6. Tests

Open **Tools > Session Frontend > Automation**, type `LawnWrangler` in the
filter, tick the tests and click **Start Tests**.

## 7. Make a download

Use **Platforms > Mac** (or **Windows**) **> Package Project**. The packaged
game is several hundred MB. Before handing it to anyone, read the signing
notes in the main README.

## Assets, licences and Git

- Only add art from Fab (Quixel Megascans) or other sources with a clear
  licence. List every pack in `ASSET_LICENSES.md`, the same rule as the
  Godot version. Megascans use Fab's standard licence, not CC0, which allows
  using them in games made with Unreal.
- No plugins or marketplace code. Art only, so nothing runs that we have
  not read.
- `.uasset` and `.umap` files are binary and can be large. They go through
  Git LFS (see `.gitattributes`), so install Git LFS once with
  `git lfs install`; GitHub Desktop does this for you. GitHub's free LFS
  storage is limited, so keep the project lean and check your GitHub
  billing page if pushes start failing.

## Stability update

Both chase cameras now probe the environment on the Camera collision channel
and pull inward around obstacles. New imported scenery must block that channel.
Completing the yard freezes both pawns, resets their speed/cutting indicators,
and prevents further movement or trimming; controller restart remains available.

The grass mask and minimap upload pixel snapshots into existing GPU textures
instead of recreating texture resources after each cut. Upload memory remains
owned until the render-thread cleanup callback. Profile frame time with dense
grass before claiming a measured performance gain.

The `LawnWrangler.Pawns` automation tests check camera configuration and verify
that stopped pawns cannot move or cut. Visual camera clearance and texture
appearance still require a rendered play test.
