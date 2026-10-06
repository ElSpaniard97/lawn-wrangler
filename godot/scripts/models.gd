class_name Models
## Placeholder meshes built in code, shared by the mower and the walker.
## These get replaced by real models in Phase 3.


static func material(color: Color, roughness := 0.8, transparent := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if transparent:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


static func add_mesh(parent: Node3D, mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	parent.add_child(instance)
	return instance


static func add_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	box.material = mat
	return add_mesh(parent, box, at)


## The landscaper: shirt, head, cap and ear protection. Feet at the origin
## when standing; seated lowers the legs out of the way.
static func person(seated: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Person"
	var shirt := material(Color(0.25, 0.27, 0.30), 0.9)
	var pants := material(Color(0.20, 0.22, 0.28), 0.9)
	var skin := material(Color(0.78, 0.58, 0.44), 0.8)
	var dark := material(Color(0.12, 0.12, 0.13), 0.8)
	var hip := 0.0 if seated else 0.8
	if not seated:
		add_box(root, Vector3(0.14, 0.8, 0.16), Vector3(-0.11, 0.4, 0), pants)
		add_box(root, Vector3(0.14, 0.8, 0.16), Vector3(0.11, 0.4, 0), pants)
	var torso := CapsuleMesh.new()
	torso.radius = 0.2
	torso.height = 0.7
	torso.material = shirt
	add_mesh(root, torso, Vector3(0, hip + 0.35, 0))
	var head := SphereMesh.new()
	head.radius = 0.13
	head.height = 0.26
	head.material = skin
	add_mesh(root, head, Vector3(0, hip + 0.82, 0))
	add_box(root, Vector3(0.28, 0.08, 0.3), Vector3(0, hip + 0.92, -0.02), dark) # cap
	add_box(root, Vector3(0.32, 0.1, 0.08), Vector3(0, hip + 0.82, 0), material(Color(0.6, 0.15, 0.1), 0.6)) # ear protection
	return root


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
	var mat := material(Color(0.32, 0.50, 0.16), 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	bit.material = mat
	p.mesh = bit
	return p
