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

- Mower acceleration/reverse, zero-turn steering (it pivots in place when stopped), actual movement speed and obstacle collisions.
- Directional cut stripes and swept grass cutting without frame gaps.
- Dismount/remount proximity and walking weed eater for narrow edges.
- Blocked house/porch, patio and tree rings excluded from lawn coverage.
- Front/side/back/edge checklist; the yard is done when every item is ticked (98% each), so the weed eater is needed for the edges the mower can't reach. Timer, browser personal best, and a results card with stars against par time (three under 7:00, two under 10:00) plus riding time, trimming time, refuels and bumps.
- Driving into the fence, house, patio or a tree stops the mower with a thud and a small camera shake (no shake when the system asks for reduced motion); ticking a checklist item plays a short blip. See `DESIGN.md` for the design review behind these.
- Fuel consumption, empty-tank crawl, stationary refill by red porch can.
- Pause, focus loss, restart; finished games stop moving and cutting.
- Minimap, highlight of missed grass, low/medium/high quality, FPS overlay.
- Synthesized engine/trimmer sound, mute, persisted settings.
- Keyboard, pointer/touch controls and standard gamepad controls.

## Validation and limits

Node tests exercise blocked coverage, swept cuts, pause/finish, mount/reset, collision boundaries, best persistence and storage failures. Browser smoke checks cover rendering, driving/cutting, dismount, pause and reset. Device-specific gamepad and real touchscreen testing still needs physical hardware.

The yard is 30 x 36 m like the Godot edition, laid out from `YARD`, `porch`, `patio`, `gasCan` and `trees` in `lawn.js`; it is not an exact copy of the Godot scenery. WebGL is the baseline renderer. Low quality hides grass meshes and shadows; all presets retain simulation. Find grass (and reaching 95%) makes missed grass glow yellow-green on the lawn and the minimap. Cutting throws grass clippings from the mower's chute or the trimmer head (Medium and High). Audio is synthesized in `sound.js`: engine with rumble, blade whoosh, weed eater, a grass rustle while cutting and a chime when the yard is done. No recordings are used. Browser/Godot saved scores have separate storage and are not transferred. Higher realism, WebGPU and asset optimization remain further graphics work. Babylon is imported module by module rather than through the `@babylonjs/core` index, which cut the main script from 6.8 MB to 1.1 MB (1.5 MB to 0.28 MB compressed). Import new Babylon classes from their own files to keep it that way. Phones and tablets start on Low quality until the player picks another.

## Second graphics pass (2026-10-09)

Built toward Zeke's reference image and second texture sheet. The mower has lathed tyres with rounded shoulders and chevron treads, grey rims with lug nuts, half-round fenders, a tubular orange frame and rear bumper, a rounded deck with spindle covers, a high-back seat with armrests, lap bars, cup holders and a fan-grille engine with a chrome muffler. The driver has a lathed torso in a heather-grey tee with a grass logo on the back, capsule arms and legs, a cap with a brim, ear muffs on a headband, a belt and work boots. Each rigid part of the mower, driver and walker is merged per material when the yard loads, so the extra detail stays cheap to draw.

The house gained gable ends, a stone chimney and foundation, stone column bases, photo windows on three sides and a photo front door. The neighbours have gables and windows (one in grey siding), river-rock beds line the house, a ring of shade trees closes the horizon, and the sky is painted with soft clouds that wrap the dome without seams. The lawn is a softened grass photo, darkened per cell for stripes and tall grass. Grass blades are a little shorter, the chase camera sits higher and further back, and the light is brighter with a little more contrast.

## Reference-inspired graphics pass

The browser scene now uses a detailed procedural zero-turn mower (treaded wheels, fan grille, engine fins, discharge chute, lap bars and fuel tanks), a rounded driver with a cap and hearing protection, and a matching walking landscaper. Wheels roll by the distance each one travels, the driver leans into turns, and on foot the legs stride while the weed eater sweeps side to side with a spinning line. The garden adds siding, pitched shingle roofs, window trim, a covered porch, wood-grain fencing, flowers, branching trees with instanced leaves, and a furnished pergola patio.

Grass is now a curved ribbon with randomized height, heading and color, plus a gentle GPU wind effect. Cut grass retains directional color and short stubble; the coverage texture fills its actual GPU dimensions and updates only changed cells. Static scenery is merged by material to limit draw calls. High uses 18 blades per cell, Medium 9 distributed throughout the yard, and Low uses the lawn surface without blades or shadows.

The HUD follows the supplied reference: a compact checklist, progress bar, circular minimap, speed dial and fuel bar. Models are generated locally at no cost. Fences, house siding, roofs, stone edging, mulch, pavers, bark and the grass outside the fence use the photo textures in `godot/textures/` (listed in `ASSET_LICENSES.md`), projected from world space before scenery is merged so they tile at real-world size. This is a step toward the reference composition, not a photorealistic reproduction; scanned materials and authored character/mower assets would be a later art pass. Gameplay and collision layout remain the same.

Graphics by quality: Low keeps the plain look for phones. Medium adds edge smoothing, a soft glow on bright spots, warmer colour grading and a light vignette. High also adds soft contact shadows in corners (SSAO), a gentle depth blur on the far yard, and a denser patch of grass that follows the player. On every setting, paint, chrome and window glass reflect a one-time snapshot of the yard and sky, and shrubs, flowers and tree crowns are crossed cards with leaf and flower textures painted in code (no image files).

Models: `models.js` loads five Sketchfab models (CC BY 4.0, credited on the credits page and in ASSET_LICENSES.md) from `babylon/models/`: a lawn tractor, an animated landscaper, a string trimmer, a house and oak trees. The procedural models in `graphics.js` show until each one loads and stay if one fails. The tractor's tyre pairs roll with the distance driven; one copy of the landscaper sits on the tractor with his hands on the wheel (bones posed in code) and the other plays the walk animation at walking pace, holding the weed eater. The house is squared up and turned so its porch faces the lawn, and the porch obstacle in `lawn.js` matches it.

## Consistent simulation timing

`simulation-clock.js` advances gameplay at 60 Hz independently of rendering, and interpolates mower/walker poses between ticks. A render frame can process up to eight simulation ticks; excess whole ticks are discarded and counted in `droppedTime`. Long stalls therefore slow simulated run time instead of teleporting the player. Times are comparable across ordinary frame rates (tested at 15, 30, 60 and 144 FPS), not guaranteed wall-clock times under severe stalls. Pause clears backlog; reset and mount changes synchronize presentation. Cutting and events from all ticks are aggregated once per rendered frame.

The fixed-step tests compare movement, fuel, cut cells, timing and statistics for identical inputs, and cover pause/resume, bounded stalls, collision-event aggregation, finish and interpolation/reset. This provides reproducible local behavior, not a promise of cross-platform multiplayer determinism.

## Reference daylight pass

The default hero view keeps the authored orange zero-turn mower and gray-shirted, cap/headset driver. Tractor and landscaper downloads are not loaded because their silhouette and seated pose differ from the reference; imported house, trees and trimmer remain. The chase view is closer/lower, grass blades are thinner and more curved with short stubble, and shadows are focused on the yard. Bloom is subtle, distance blur is disabled, and imported PBR scenery receives the yard reflection environment. This is a no-cost art-direction improvement, not photorealistic parity or a newly licensed mower asset.

## Bright colour pass

Lighting is brighter and warmer (sun 1.5, sky fill 0.82, exposure 1.12, contrast 1.14) and colour grading (saturation +32, warm highlights, cool shadows) now runs on every quality level, Low included, since it is applied inside the material shaders at no extra pass. The sky is a deeper blue with whiter clouds; the dome is 320 m across and unfogged so the distant tree line no longer clips behind it. Grass blades, leaves, the cut-stripe map and the lawn photo use brighter, more saturated greens. Distant trees are leaf-card crowns around a small core instead of smooth spheres (one extra draw call). Medium and High add a light sharpen after FXAA and stronger anisotropic filtering (8x and 16x); High also renders up to 1.25x on high-density screens and uses a 4096 shadow map with high-quality filtering. The post pipeline stays LDR.
