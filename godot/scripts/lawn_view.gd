class_name LawnView
extends Node3D
## Draws the LawnGrid: a ground texture with one pixel per cell (tall, two
## stripe shades, or mulch) and chunked MultiMesh grass clumps that vanish
## when their cell is cut. Chunks let the renderer cull what is off screen.

const CHUNK := 10 # cells per chunk side
const TALL_COLOR := Color(0.17, 0.30, 0.09)
const STRIPE_A_COLOR := Color(0.30, 0.47, 0.15)
const STRIPE_B_COLOR := Color(0.22, 0.38, 0.11)
const BLOCKED_COLOR := Color(0.33, 0.24, 0.16)
const HIGHLIGHT_COLOR := Color(0.95, 0.78, 0.15)

var grid: LawnGrid
var image: Image
var texture: ImageTexture
var shade := PackedFloat32Array()
var chunks: Array[MultiMesh] = []
var chunk_columns := 0
var dirty := false
var highlight := false
var clump_material: StandardMaterial3D


func build(lawn: LawnGrid) -> void:
	grid = lawn
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	shade.resize(grid.columns * grid.rows)
	for i in shade.size():
		shade[i] = rng.randf_range(-0.035, 0.035)
	_build_ground()
	_build_clumps(rng)
	grid.cell_cut.connect(_on_cell_cut)


func _build_ground() -> void:
	image = Image.create(grid.columns, grid.rows, false, Image.FORMAT_RGB8)
	for z in grid.rows:
		for x in grid.columns:
			image.set_pixel(x, z, _color_for(x, z))
	texture = ImageTexture.create_from_image(image)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 1.0
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	var plane := PlaneMesh.new()
	plane.size = Vector2(grid.columns, grid.rows) * grid.cell_size
	plane.material = material
	var ground := MeshInstance3D.new()
	ground.name = "Ground"
	ground.mesh = plane
	ground.position = Vector3(plane.size.x / 2.0, 0.0, plane.size.y / 2.0)
	add_child(ground)


func _build_clumps(rng: RandomNumberGenerator) -> void:
	var clump := _clump_mesh()
	chunk_columns = ceili(float(grid.columns) / CHUNK)
	var chunk_rows := ceili(float(grid.rows) / CHUNK)
	for cz in chunk_rows:
		for cx in chunk_columns:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = clump
			mm.instance_count = CHUNK * CHUNK
			for lz in CHUNK:
				for lx in CHUNK:
					var x := cx * CHUNK + lx
					var z := cz * CHUNK + lz
					var t := Transform3D()
					if x < grid.columns and z < grid.rows and grid.cell(x, z) == LawnGrid.TALL:
						var s := rng.randf_range(0.8, 1.25)
						t = Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)),
							Vector3((x + rng.randf_range(0.2, 0.8)) * grid.cell_size, 0.0,
								(z + rng.randf_range(0.2, 0.8)) * grid.cell_size))
					else:
						t = t.scaled(Vector3.ZERO)
					mm.set_instance_transform(lz * CHUNK + lx, t)
			chunks.append(mm)
			var instance := MultiMeshInstance3D.new()
			instance.multimesh = mm
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(instance)


## Three tapered blades, darker at the root, as one small mesh.
func _clump_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var root := Color(0.12, 0.24, 0.06)
	var tip := Color(0.36, 0.55, 0.17)
	for blade in 5:
		var angle := blade * TAU / 5.0
		var side := Vector3(cos(angle), 0, sin(angle)) * 0.03
		var lean := Vector3(-sin(angle), 0, cos(angle)) * 0.05
		var height := 0.24 + 0.06 * (blade % 2)
		var points := [-side, side, Vector3(0, height, 0) + lean]
		# Both windings with an upward normal, so blades are lit from
		# either side instead of going dark on their back faces.
		for order in [[0, 1, 2], [1, 0, 2]]:
			for i in order:
				st.set_normal(Vector3.UP)
				st.set_color(tip if i == 2 else root)
				st.add_vertex(points[i])
	clump_material = StandardMaterial3D.new()
	clump_material.vertex_color_use_as_albedo = true
	clump_material.roughness = 1.0
	st.set_material(clump_material)
	return st.commit()


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


func _on_cell_cut(x: int, z: int, _stripe: int) -> void:
	image.set_pixel(x, z, _color_for(x, z))
	var chunk := chunks[(z / CHUNK) * chunk_columns + (x / CHUNK)]
	chunk.set_instance_transform((z % CHUNK) * CHUNK + (x % CHUNK), Transform3D().scaled(Vector3.ZERO))
	dirty = true


## Paints every uncut patch bright yellow so the last few are easy to find.
func set_highlight(on: bool) -> void:
	highlight = on
	clump_material.albedo_color = Color(3.0, 2.4, 0.4) if on else Color.WHITE
	for z in grid.rows:
		for x in grid.columns:
			image.set_pixel(x, z, _color_for(x, z))
	dirty = true


func _process(_delta: float) -> void:
	if dirty:
		texture.update(image)
		dirty = false
