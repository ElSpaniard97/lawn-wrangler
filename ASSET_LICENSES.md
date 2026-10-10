# Asset licenses

Every sound in Lawn Wrangler is generated in code, and so is every model
except the Sketchfab models below (browser edition only). The other outside
art is the set of photo textures below, used on the lawn and the scenery. Nothing else (no scripts, fonts, sounds or Godot add-ons)
comes from outside the project.

Any asset added later must be listed here with where it came from and its
license, and must be a plain image, sound or glTF model file. The tests check that each
texture the game uses is a JPEG in `godot/textures/` and is listed here.
The Babylon browser edition uses the same files from `godot/textures/`
(see `babylon/graphics.js`); Vite copies them into the web build.

## Sketchfab models (CC BY 4.0)

Downloaded from Sketchfab by Zeke on 2026-10-09 and approved for use with
credit. Each is licensed under Creative Commons Attribution 4.0
(http://creativecommons.org/licenses/by/4.0/): free to use, including
commercially, as long as the author is credited. The credits page
(`web/credits.html`) names each one. The files were shrunk for the web:
textures resized to 1024 px or less and saved as WebP, every animation but
`walk` removed from the landscaper, the oak scene's ground and rock pieces
removed and its three trees split apart, and the tractor's tyres split into
front and rear axles.

| File | Model, author and source | Used for |
| --- | --- | --- |
| `babylon/models/tractor.glb` | "Lawn Tractor" by mirrol (https://sketchfab.com/mirrol), https://sketchfab.com/3d-models/lawn-tractor-97ec916314324ed8a828176f3d310f82 | The riding mower |
| `babylon/models/landscaper.glb` | "Bearded man - Low poly animated" by Agor_2012 (https://sketchfab.com/Agor_), https://sketchfab.com/3d-models/bearded-man-low-poly-animated-5718a53d18a142f686b1d9f02a637773 | The landscaper, riding and walking |
| `babylon/models/trimmer.glb` | "String trimmer" by Colin Charles (https://sketchfab.com/Colin_Charles), https://sketchfab.com/3d-models/string-trimmer-b236cda82f4e4517a943e85aef78a2e8 | The weed eater |
| `babylon/models/house.glb` | "Suburban House" by mbuannoart (https://sketchfab.com/mbuannoart), https://sketchfab.com/3d-models/suburban-house-b8375c5e5e6b40639fc06492fbd95fcb | The house and porch |
| `babylon/models/oak.glb` | "Oak Trees FREE Low Poly" by LordSamueliSolo (https://sketchfab.com/LadyLionStudios), https://sketchfab.com/3d-models/oak-trees-free-low-poly-7a689370f9ec46cea2cbc94641c225e6 | The three shade trees in the yard |

## Browser-only textures

Source: a second texture sheet supplied by the project owner, Zeke, on
2026-10-09. Each was cropped from the sheet; the tiling ones were blended to
repeat seamlessly. Only the Babylon browser edition uses these.

| File | Used for |
| --- | --- |
| `babylon/textures/siding_gray.jpg` | The left neighbour's house |
| `babylon/textures/stone_accent.jpg` | House foundation, chimney and porch column bases |
| `babylon/textures/gravel.jpg` | River-rock beds along the house |
| `babylon/textures/window.jpg` | Windows on the house and neighbours |
| `babylon/textures/front_door.jpg` | The front door |
| `babylon/textures/lawn_detail.jpg` | The lawn and outer grass: `godot/textures/grass.jpg` softened and brightened |

## Photo textures

Source: a texture sheet supplied by the project owner, Zeke, on 2026-10-06.
Each texture was cropped from the sheet, made to tile seamlessly, and saved
as a 256 x 256 JPEG.

| File | Used for |
| --- | --- |
| `godot/textures/grass.jpg` | Detail on the lawn and the grass outside the fence |
| `godot/textures/wood.jpg` | Fence pickets, posts and rails; tree bark |
| `godot/textures/siding_white.jpg` | House walls (tinted for the neighbours) |
| `godot/textures/shingles.jpg` | Roofs |
| `godot/textures/stone.jpg` | Foundations, chimneys, tree rings and bed edging |
| `godot/textures/mulch.jpg` | Flower beds and tree rings |
| `godot/textures/leaves.jpg` | Tree canopies, pines and shrubs |
| `godot/textures/concrete.jpg` | Door steps and the driveway |
| `godot/textures/pavers.jpg` | Paver patios |
