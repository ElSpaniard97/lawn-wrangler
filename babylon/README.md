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

This port rebuilds a smaller yard and procedural models; it does not preserve identical Godot scenery. WebGL is the baseline renderer. Low quality hides grass meshes and shadows; all presets retain simulation. Highlight currently shows missed patches on the minimap. Audio is a basic synthesized motor, not recordings. Browser/Godot saved scores have separate storage and are not transferred. Higher realism, WebGPU and asset optimization remain further graphics work. The initial engine bundle needs modular import optimization before download size can be considered final.
