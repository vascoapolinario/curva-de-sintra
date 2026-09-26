extends RefCounted
## Small mesh helpers shared by the cabin and forest. All art is original.

static func material(color: Color, texture: Texture2D = null, emission: float = 0.0) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = texture
	m.roughness = 0.93
	if emission > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emission
	return m

static func mesh(parent: Node3D, shape: Mesh, pos: Vector3, mat: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	n.mesh = shape
	n.material_override = mat
	n.position = pos
	parent.add_child(n)
	return n

static func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape = BoxMesh.new()
	shape.size = size
	# Soft bevels keep the old vinyl interior from reading as flat cubes.
	shape.subdivide_width = 2
	shape.subdivide_height = 2
	shape.subdivide_depth = 2
	var arrays = shape.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var radius = minf(size.x,minf(size.y,size.z))*0.23
	var inner = size*0.5-Vector3.ONE*radius
	for i in vertices.size():
		var q = vertices[i].clamp(-inner,inner)
		var normal = (vertices[i]-q).normalized()
		vertices[i] = q+normal*radius
		normals[i] = normal
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var bevel = ArrayMesh.new()
	bevel.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh(parent, bevel, pos, mat)

static func cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, mat: Material, top: float = -1.0) -> MeshInstance3D:
	var shape = CylinderMesh.new()
	shape.top_radius = radius if top < 0.0 else top
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 9
	return mesh(parent, shape, pos, mat)

static func sphere(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var shape = SphereMesh.new()
	shape.radial_segments = 12
	shape.rings = 6
	var n = mesh(parent, shape, pos, mat)
	n.scale = size
	return n

static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var n = cylinder(parent, (a+b)*0.5, radius, a.distance_to(b), mat)
	var axis = (b-a).normalized()
	var helper = Vector3.RIGHT if absf(axis.dot(Vector3.UP)) > 0.98 else Vector3.UP
	var right = helper.cross(axis).normalized()
	n.basis = Basis(right, axis, right.cross(axis).normalized())
	return n

static func label(parent: Node3D, text: String, pos: Vector3, size: int, color: Color) -> Label3D:
	var n = Label3D.new()
	n.text = text
	n.position = pos
	n.font_size = size
	n.pixel_size = 0.002
	n.modulate = color
	n.outline_size = 0
	n.no_depth_test = false
	parent.add_child(n)
	return n
