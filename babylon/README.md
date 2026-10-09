# Lawn Wrangler — Babylon browser edition

Babylon.js is now the primary browser implementation. Godot remains available for desktop and as a reference. The Pages workflow copies this Vite build to `site/play`; the landing page embeds it. The migration changes the browser engine, not the desktop engines.

## Run

Node.js 22.12+:

```sh
cd babylon
npm ci
npm run dev
npm test
npm run build
```

`dist/` is a static web artifact; paths are relative so it works on GitHub project Pages. No CDN engine dependencies or remote fonts. Assets are procedural geometry. Babylon.js is Apache-2.0; Vite is MIT. No paid services required.

## Migrated gameplay

- Mower acceleration/reverse/steering, actual movement speed and obstacle collisions.
- Directional cut stripes and swept grass cutting without frame gaps.
- Dismount/remount proximity and walking weed eater for narrow edges.
- Blocked house/porch, patio and tree rings excluded from lawn coverage.
- Front/side/back/edge checklist, 99% finish, timer and browser personal best.
- Fuel consumption, empty-tank crawl, stationary refill by red porch can.
- Pause, focus loss, restart; finished games stop moving and cutting.
- Minimap, highlight of missed grass, low/medium/high quality, FPS overlay.
- Synthesized engine/trimmer sound, mute, persisted settings.
- Keyboard, pointer/touch controls and standard gamepad controls.

## Validation and limits

Node tests exercise blocked coverage, swept cuts, pause/finish, mount/reset, collision boundaries, best persistence and storage failures. Browser smoke checks cover rendering, driving/cutting, dismount, pause and reset. Device-specific gamepad and real touchscreen testing still needs physical hardware.

The yard is 30 x 36 m like the Godot edition, laid out from `YARD`, `porch`, `patio`, `gasCan` and `trees` in `lawn.js`; it is not an exact copy of the Godot scenery. WebGL is the baseline renderer. Low quality hides grass meshes and shadows; all presets retain simulation. Find grass (and reaching 95%) makes missed grass glow yellow-green on the lawn and the minimap. Cutting throws grass clippings from the mower's chute or the trimmer head (Medium and High). Audio is synthesized in `sound.js`: engine with rumble, blade whoosh, weed eater, a grass rustle while cutting and a chime when the yard is done. No recordings are used. Browser/Godot saved scores have separate storage and are not transferred. Higher realism, WebGPU and asset optimization remain further graphics work. Babylon is imported module by module rather than through the `@babylonjs/core` index, which cut the main script from 6.8 MB to 1.1 MB (1.5 MB to 0.28 MB compressed). Import new Babylon classes from their own files to keep it that way. Phones and tablets start on Low quality until the player picks another.

## Reference-inspired graphics pass

The browser scene now uses a detailed procedural zero-turn mower (treaded wheels, fan grille, engine fins, discharge chute, lap bars and fuel tanks), a rounded driver with a cap and hearing protection, and a matching walking landscaper. The garden adds siding, pitched shingle roofs, window trim, a covered porch, wood-grain fencing, flowers, branching trees with instanced leaves, and a furnished pergola patio.

Grass is now a curved ribbon with randomized height, heading and color, plus a gentle GPU wind effect. Cut grass retains directional color and short stubble; the coverage texture fills its actual GPU dimensions and updates only changed cells. Static scenery is merged by material to limit draw calls. High uses 18 blades per cell, Medium 9 distributed throughout the yard, and Low uses the lawn surface without blades or shadows.

The HUD follows the supplied reference: a compact checklist, progress bar, circular minimap, speed dial and fuel bar. Models are generated locally at no cost. Fences, house siding, roofs, stone edging, mulch, pavers, bark and the grass outside the fence use the photo textures in `godot/textures/` (listed in `ASSET_LICENSES.md`), projected from world space before scenery is merged so they tile at real-world size. This is a step toward the reference composition, not a photorealistic reproduction; scanned materials and authored character/mower assets would be a later art pass. Gameplay and collision layout remain the same.
