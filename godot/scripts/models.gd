class_name Models
## Models built in code from Godot's primitive meshes: the landscaper, the
## weed eater and clippings, plus small helpers the mower and scenery use.
## Scenery surfaces can use the photo textures in res://textures (listed in
## ASSET_LICENSES.md); no outside model files are loaded.

const SHIRT := Color(0.24, 0.27, 0.31)
const PANTS := Color(0.26, 0.30, 0.38)
const SKIN := Color(0.80, 0.60, 0.46)
const DARK := Color(0.10, 0.10, 0.11)
const SAFETY := Color(0.86, 0.20, 0.12)
const ORANGE := Color(0.95, 0.35, 0.05)

static var _materials := {}


## Shared, cached materials so identical colours reuse one material.
static func material(color: Color, roughness := 0.8, transparent := false) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color.to_html(), roughness, transparent]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_materials[key] = m
	return m


## A photo-textured material. The texture is projected from world space
## (triplanar), so it needs no UVs, survives `bake`, and keeps the same
## real-world size on every part. `tile` is how many metres one copy of the
## texture covers. `tint` multiplies the photo's own colours.
static func textured(texture_name: String, tint := Color.WHITE, tile := 1.0, roughness := 0.9) -> StandardMaterial3D:
	var key := "tex|%s|%s|%s|%s" % [texture_name, tint.to_html(), tile, roughness]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/%s.jpg" % texture_name)
	m.albedo_color = tint
	m.roughness = roughness
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE / tile
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	_materials[key] = m
	return m


static func add_mesh(parent: Node3D, mesh: Mesh, at: Vector3, rotation_degrees := Vector3.ZERO) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.rotation_degrees = rotation_degrees
	parent.add_child(instance)
	return instance


static func add_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, rotation_degrees := Vector3.ZERO) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	return add_mesh(parent, box, at, rotation_degrees)


static func add_cylinder(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material, rotation_degrees := Vector3.ZERO, sides := 16) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = sides
	c.rings = 1
	c.material = mat
	return add_mesh(parent, c, at, rotation_degrees)


## A round rod running from one point to another (rails, bars, shafts).
static func add_rod(parent: Node3D, from: Vector3, to: Vector3, radius: float, mat: Material, sides := 8) -> MeshInstance3D:
	var rod := add_cylinder(parent, radius, from.distance_to(to), (from + to) * 0.5, mat, Vector3.ZERO, sides)
	var y := (to - from).normalized()
	var helper := Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x := y.cross(helper).normalized()
	rod.basis = Basis(x, y, x.cross(y))
	return rod


## A material that glows, for headlights and windows.
static func glow(color: Color, energy := 1.0) -> StandardMaterial3D:
	var key := "glow|%s|%s" % [color.to_html(), energy]
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_materials[key] = m
	return m


static func add_sphere(parent: Node3D, radius: float, at: Vector3, mat: Material, squash := 1.0) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0 * squash
	s.radial_segments = 16
	s.rings = 8
	s.material = mat
	return add_mesh(parent, s, at)


static func add_capsule(parent: Node3D, radius: float, height: float, at: Vector3, mat: Material, rotation_degrees := Vector3.ZERO) -> MeshInstance3D:
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = height
	c.radial_segments = 12
	c.rings = 4
	c.material = mat
	return add_mesh(parent, c, at, rotation_degrees)


## Merges every mesh under `root` into one mesh with a surface per
## material, so the renderer draws a whole model in a handful of calls
## instead of one call per part. Meshes under the `skip` nodes (parts that
## move on their own) are left alone. Returns the baked mesh instance.
static func bake(root: Node3D, skip: Array = []) -> MeshInstance3D:
	var tools := {}
	var order := []
	for node: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		var xf := node.transform
		var parent := node.get_parent()
		var skipped := skip.has(node)
		while parent != root and not skipped:
			skipped = skip.has(parent)
			xf = parent.transform * xf
			parent = parent.get_parent()
		if skipped or not node.visible:
			continue
		for surface in node.mesh.get_surface_count():
			var mat: Material = node.material_override if node.material_override else node.mesh.surface_get_material(surface)
			if not tools.has(mat):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[mat] = st
				order.append(mat)
			tools[mat].append_from(node.mesh, surface, xf)
		node.get_parent().remove_child(node)
		node.free()
	var mesh := ArrayMesh.new()
	for mat in order:
		tools[mat].commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	var baked := MeshInstance3D.new()
	baked.name = "Baked"
	baked.mesh = mesh
	root.add_child(baked)
	return baked


## The landscaper, facing -Z with feet at the origin: boots, work pants,
## t-shirt, arms, cap and red ear protection. Legs and arms hang from pivot
## nodes named LeftLeg, RightLeg, LeftArm and RightArm so they can swing.
## Seated bends the legs forward and reaches the arms to the lap bars.
static func person(seated: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Person"
	var shirt := material(SHIRT, 0.9)
	var pants := material(PANTS, 0.9)
	var skin := material(SKIN, 0.75)
	var dark := material(DARK, 0.7)
	var safety := material(SAFETY, 0.5)
	var hip := 0.85

	for side in [-1, 1]:
		var leg := Node3D.new()
		leg.name = "LeftLeg" if side < 0 else "RightLeg"
		leg.position = Vector3(0.1 * side, hip, 0)
		root.add_child(leg)
		add_box(leg, Vector3(0.15, 0.78, 0.17), Vector3(0, -0.4, 0), pants)
		add_box(leg, Vector3(0.15, 0.1, 0.27), Vector3(0, -0.8, -0.05), dark) # boot
		if seated:
			leg.rotation.x = deg_to_rad(62)

	add_box(root, Vector3(0.36, 0.08, 0.22), Vector3(0, hip + 0.02, 0), dark) # belt
	add_capsule(root, 0.2, 0.66, Vector3(0, hip + 0.33, 0), shirt)
	add_cylinder(root, 0.055, 0.1, Vector3(0, hip + 0.7, 0), skin) # neck

	for side in [-1, 1]:
		var arm := Node3D.new()
		arm.name = "LeftArm" if side < 0 else "RightArm"
		arm.position = Vector3(0.25 * side, hip + 0.56, 0)
		root.add_child(arm)
		add_capsule(arm, 0.08, 0.26, Vector3(0, -0.1, 0), shirt) # sleeve
		add_capsule(arm, 0.055, 0.58, Vector3(0, -0.3, 0), skin)
		add_sphere(arm, 0.06, Vector3(0, -0.6, 0), skin) # hand
		arm.rotation.z = deg_to_rad(4 * side)
		if seated:
			arm.rotation.x = deg_to_rad(55)

	var head_y := hip + 0.86
	add_sphere(root, 0.125, Vector3(0, head_y, 0), skin, 1.08)
	# Cap: crown and brim.
	var crown := SphereMesh.new()
	crown.radius = 0.132
	crown.height = 0.132
	crown.is_hemisphere = true
	crown.material = dark
	add_mesh(root, crown, Vector3(0, head_y + 0.03, 0))
	add_box(root, Vector3(0.2, 0.02, 0.13), Vector3(0, head_y + 0.035, -0.17), dark)
	# Ear protection: two cups and a band over the cap.
	for side in [-1, 1]:
		add_cylinder(root, 0.065, 0.06, Vector3(0.14 * side, head_y, 0.01), safety, Vector3(0, 0, 90))
	var band := TorusMesh.new()
	band.inner_radius = 0.135
	band.outer_radius = 0.155
	band.rings = 16
	band.ring_segments = 6
	band.material = safety
	add_mesh(root, band, Vector3(0, head_y + 0.02, 0.01), Vector3(0, 0, 90))

	if seated:
		root.position.y = -hip
	return root


## Swings legs (and arms unless they are holding a tool) for a walk cycle.
static func animate_walk(person: Node3D, phase: float, amount: float, arms_busy: bool) -> void:
	var swing := sin(phase) * 0.55 * amount
	person.get_node("LeftLeg").rotation.x = swing
	person.get_node("RightLeg").rotation.x = -swing
	if not arms_busy:
		person.get_node("LeftArm").rotation.x = -swing * 0.8
		person.get_node("RightArm").rotation.x = swing * 0.8


## Bits of grass thrown up while cutting. Set `emitting` while cells are cut.
static func clippings(radius: float) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = 40
	p.lifetime = 0.7
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = radius * 0.8
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 1.2
	p.initial_velocity_max = 2.6
	p.gravity = Vector3(0, -7.0, 0)
	p.angular_velocity_min = -360.0
	p.angular_velocity_max = 360.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.2
	var bit := QuadMesh.new()
	bit.size = Vector2(0.05, 0.02)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.50, 0.16)
	mat.roughness = 1.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	bit.material = mat
	p.mesh = bit
	return p
