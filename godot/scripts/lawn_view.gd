class_name LawnView
extends Node3D
## Draws the LawnGrid: a ground texture with one pixel per cell (tall, two
## stripe shades, or mulch), detailed with a grass photo, and chunked MultiMesh grass clumps. Cutting a
## cell drops its clump to short stubble. Chunks let the renderer cull what
## is off screen.

const CHUNK := 10 # cells per chunk side
const TALL_COLOR := Color(0.13, 0.27, 0.06)
const STRIPE_A_COLOR := Color(0.20, 0.40, 0.07)
const STRIPE_B_COLOR := Color(0.10, 0.24, 0.04)
const BLOCKED_COLOR := Color(0.30, 0.21, 0.14)
const HIGHLIGHT_COLOR := Color(0.85, 0.68, 0.12)
const BLADES := 18
const STUBBLE_HEIGHT := 0.2 # fraction of full clump height left after a cut
const TALL_DATA := Color(1, 0, 0, 0)
const CUT_DATA := Color(0, 0, 0, 0) # dark stripe stubble
const CUT_LIGHT_DATA := Color(0, 1, 0, 0) # light stripe stubble

var grid: LawnGrid
var image: Image
var texture: ImageTexture
var shade := PackedFloat32Array()
var chunks: Array[MultiMesh] = []
## Each cell's full-height clump transform, so a cut can shrink it in place.
var clump_transforms: Array[Transform3D] = []
var chunk_columns := 0
var dirty := false
var highlight := false
var clump_material: ShaderMaterial


func build(lawn: LawnGrid) -> void:
	grid = lawn
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	shade.resize(grid.columns * grid.rows)
	for i in shade.size():
		shade[i] = rng.randf_range(-0.03, 0.03)
	_build_ground()
	_build_clumps(rng)
	grid.cell_cut.connect(_on_cell_cut)


func _build_ground() -> void:
	image = Image.create(grid.columns, grid.rows, false, Image.FORMAT_RGB8)
	for z in grid.rows:
		for x in grid.columns:
			image.set_pixel(x, z, _color_for(x, z))
	texture = ImageTexture.create_from_image(image)
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/ground.gdshader")
	material.set_shader_parameter("cells", texture)
	material.set_shader_parameter("detail", load("res://textures/grass.jpg"))
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid.columns, grid.rows) * grid.cell_size
	plane.material = material
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.position = Vector3(plane.size.x / 2.0, 0.0, plane.size.y / 2.0)
	add_child(ground)


func _build_clumps(rng: RandomNumberGenerator) -> void:
	clump_material = ShaderMaterial.new()
	clump_material.shader = load("res://shaders/grass.gdshader")
	var clump := _clump_mesh()
	clump_transforms.resize(grid.columns * grid.rows)
	chunk_columns = ceili(float(grid.columns) / CHUNK)
	var chunk_rows := ceili(float(grid.rows) / CHUNK)
	for cz in chunk_rows:
		for cx in chunk_columns:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_custom_data = true
			mm.mesh = clump
			mm.instance_count = CHUNK * CHUNK
			for lz in CHUNK:
				for lx in CHUNK:
					var x := cx * CHUNK + lx
					var z := cz * CHUNK + lz
					var index := lz * CHUNK + lx
					if x >= grid.columns or z >= grid.rows or grid.cell(x, z) == LawnGrid.BLOCKED:
						mm.set_instance_transform(index, Transform3D().scaled(Vector3.ZERO))
						mm.set_instance_custom_data(index, CUT_DATA)
						continue
					var s := rng.randf_range(0.8, 1.25)
					var full := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
						Vector3((x + rng.randf_range(0.2, 0.8)) * grid.cell_size, 0.0,
							(z + rng.randf_range(0.2, 0.8)) * grid.cell_size))
					clump_transforms[z * grid.columns + x] = full
					var is_tall := grid.cell(x, z) == LawnGrid.TALL
					mm.set_instance_transform(index, full if is_tall else _stubble(full))
					mm.set_instance_custom_data(index, TALL_DATA if is_tall else _cut_data(grid.cell(x, z)))
			chunks.append(mm)
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = mm
			instance.material_override = clump_material
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)


## Eighteen thin blades scattered over the cell, each a single tapered
## triangle drawn from both sides (the shader turns off back-face culling).
## Normals point up so both faces light the same. UV.x carries a random
## shade per blade so the clump is not one flat colour.
func _clump_mesh() -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in BLADES:
		var root := Vector3(rng.randf_range(-0.14, 0.14), 0, rng.randf_range(-0.14, 0.14))
		var facing := rng.randf() * TAU
		var side := Vector3(cos(facing), 0, sin(facing)) * rng.randf_range(0.009, 0.015)
		var lean := Vector3(-sin(facing), 0, cos(facing)) * rng.randf_range(-0.09, 0.09)
		var height := rng.randf_range(0.2, 0.34)
		var shade := rng.randf()
		for point in [root - side, root + side, root + Vector3(0, height, 0) + lean]:
			st.set_normal(Vector3.UP)
			st.set_uv(Vector2(shade, 0))
			st.add_vertex(point)
	return st.commit()


func _stubble(full: Transform3D) -> Transform3D:
	return Transform3D(full.basis.scaled(Vector3(1.0, STUBBLE_HEIGHT, 1.0)), full.origin)


func _color_for(x: int, z: int) -> Color:
	var base := HIGHLIGHT_COLOR if highlight else TALL_COLOR
	match grid.cell(x, z):
		LawnGrid.STRIPE_A:
			base = STRIPE_A_COLOR
		LawnGrid.STRIPE_B:
			base = STRIPE_B_COLOR
		LawnGrid.BLOCKED:
			base = BLOCKED_COLOR
	var d := shade[z * grid.columns + x]
	return Color(base.r + d, base.g + d, base.b + d * 0.5)


func chunk_for(x: int, z: int) -> MultiMesh:
	return chunks[(z / CHUNK) * chunk_columns + (x / CHUNK)]


func instance_for(x: int, z: int) -> int:
	return (z % CHUNK) * CHUNK + (x % CHUNK)


func _cut_data(stripe: int) -> Color:
	return CUT_LIGHT_DATA if stripe == LawnGrid.STRIPE_A else CUT_DATA


func _on_cell_cut(x: int, z: int, stripe: int) -> void:
	image.set_pixel(x, z, _color_for(x, z))
	var chunk := chunk_for(x, z)
	var index := instance_for(x, z)
	chunk.set_instance_transform(index, _stubble(clump_transforms[z * grid.columns + x]))
	chunk.set_instance_custom_data(index, _cut_data(stripe))
	dirty = true


## Paints every uncut patch yellow so the last few are easy to find.
func set_highlight(on: bool) -> void:
	highlight = on
	clump_material.set_shader_parameter("highlight", 1.0 if on else 0.0)
	for z in grid.rows:
		for x in grid.columns:
			image.set_pixel(x, z, _color_for(x, z))
	dirty = true


func _process(_delta: float) -> void:
	if dirty:
		texture.update(image)
		dirty = false
