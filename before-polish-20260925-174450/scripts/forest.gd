extends Node3D
const G = preload("res://scripts/geometry.gd")

var roads: Array[PackedVector3Array] = []
var road_samples: PackedVector3Array = []
var destination = Vector3(48, 0, -560)
var ghost: Node3D
var rng = RandomNumberGenerator.new()
const ROUTES = [
	[Vector2(0,30),Vector2(0,-60),Vector2(-15,-95),Vector2(-42,-125),Vector2(-42,-170),Vector2(-10,-205),Vector2(0,-245)],
	[Vector2(0,-245),Vector2(35,-273),Vector2(70,-290),Vector2(90,-330),Vector2(65,-370),Vector2(45,-405)],
	[Vector2(0,-245),Vector2(-55,-265),Vector2(-90,-310),Vector2(-100,-345)],
	[Vector2(45,-405),Vector2(8,-435),Vector2(-35,-450),Vector2(-50,-490),Vector2(-24,-520),Vector2(15,-530),Vector2(48,-560)],
	[Vector2(45,-405),Vector2(95,-440),Vector2(120,-465),Vector2(145,-460)]
]

func _ready() -> void:
	rng.seed = 173
	_build_environment()
	_build_roads()
	_build_trees()
	_build_landmarks()

func _build_environment() -> void:
	var e = Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("090e10")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("697571")
	e.ambient_light_energy = 0.20
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("151c19")
	e.fog_light_energy = 0.5
	e.fog_density = 0.026
	var world_env = WorldEnvironment.new()
	world_env.environment = e
	add_child(world_env)
	var moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38,-20,0)
	moon.light_color = Color("758c9a")
	moon.light_energy = 0.12
	add_child(moon)
	var ground_mat = G.material(Color("77765c"), load("res://assets/ground.png"))
	ground_mat.uv1_scale = Vector3(180,180,1)
	G.box(self, Vector3(0,-0.18,-290), Vector3(850,0.3,850),ground_mat)

func _build_roads() -> void:
	var asphalt = G.material(Color("aaaa91"),load("res://assets/asphalt.png"))
	var shoulder = G.material(Color("797651"),load("res://assets/ground.png"))
	var stripe = G.material(Color("939380"))
	for control_points in ROUTES:
		var c = Curve3D.new()
		c.bake_interval = 1.4
		for i in control_points.size():
			var p: Vector2 = control_points[i]
			var prev: Vector2 = control_points[maxi(0,i-1)]
			var next: Vector2 = control_points[mini(i+1,control_points.size()-1)]
			var tangent = (next-prev).normalized() * minf(p.distance_to(prev),p.distance_to(next))*0.32
			c.add_point(Vector3(p.x,0,p.y), Vector3(-tangent.x,0,-tangent.y), Vector3(tangent.x,0,tangent.y))
		var pts = c.get_baked_points()
		roads.append(pts)
		for j in range(0,pts.size(),3): road_samples.append(pts[j])
		road_samples.append(pts[-1])
		_ribbon(pts,5.3,0.002,shoulder)
		_ribbon(pts,3.65,0.022,asphalt)
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in range(0,pts.size()-1):
			if i % 9 < 4: _quad(st,pts[i],pts[i+1],0.048,0.03)
		st.generate_normals()
		G.mesh(self,st.commit(),Vector3.ZERO,stripe)
		for i in range(10,pts.size()-1,18):
			var side = (pts[i+1]-pts[i]).normalized().cross(Vector3.UP)
			for sign_side in [-1,1]:
				var p = pts[i]+side*4.45*sign_side
				G.box(self,p+Vector3(0,0.45,0),Vector3(0.12,0.9,0.12),G.material(Color("86877a")))
				G.box(self,p+Vector3(0,0.71,0),Vector3(0.14,0.17,0.14),G.material(Color("45221b")))
				G.box(self,p+Vector3(0,0.76,0.075),Vector3(0.085,0.06,0.014),G.material(Color("dbb789"),null,0.45))

func _quad(st: SurfaceTool, a: Vector3, b: Vector3, width: float, height: float) -> void:
	var side = (b-a).normalized().cross(Vector3.UP)*width
	var up = Vector3.UP*height
	var v = [a-side+up,a+side+up,b-side+up,b+side+up]
	for k in [0,2,1,1,2,3]:
		st.set_uv(Vector2(float(k%2), (a.z if k < 2 else b.z)/7.0))
		st.add_vertex(v[k])

func _ribbon(pts: PackedVector3Array, width: float, height: float, mat: Material) -> void:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in pts.size()-1: _quad(st,pts[i],pts[i+1],width,height)
	st.generate_normals()
	G.mesh(self,st.commit(),Vector3.ZERO,mat)

func distance_to_road(p: Vector3) -> float:
	var best = 100000.0
	for sample in road_samples:
		var dx = p.x-sample.x
		var dz = p.z-sample.z
		var dist = dx*dx+dz*dz
		if dist < best: best = dist
	return sqrt(best)

func _build_trees() -> void:
	var placements: Array[Transform3D] = []
	for pts in roads:
		for i in range(0,pts.size()-2,5):
			var right = (pts[i+1]-pts[i]).normalized().cross(Vector3.UP)
			for side in [-1,1]:
				for depth in [8.0,15.0,24.0,37.0]:
					var p = pts[i] + right*(depth+rng.randf_range(-1.8,1.8))*side
					p += Vector3(rng.randf_range(-2.8,2.8),0,rng.randf_range(-2.8,2.8))
					if distance_to_road(p) < 6.4: continue
					var size = rng.randf_range(0.75,1.5)
					placements.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(size,size*rng.randf_range(0.9,1.4),size)),p))
	var trunk = CylinderMesh.new()
	trunk.height = 10
	trunk.top_radius = 0.08
	trunk.bottom_radius = 0.23
	trunk.radial_segments = 7
	var trunk_transforms: Array[Transform3D] = []
	for t in placements:
		trunk_transforms.append(t.translated_local(Vector3(0,5,0)))
	_multimesh(trunk,G.material(Color("b0a98e"),load("res://assets/bark.png")),trunk_transforms)
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for level in 7:
		var y = 3.1+level*0.93
		var radius = (7-level)*0.43+0.3
		for arm in 9:
			var angle = arm*TAU/9+level*0.57
			var dir = Vector3(cos(angle),0,sin(angle))
			var side = Vector3(-sin(angle),0,cos(angle))
			for tuft in 7:
				var center = dir*radius*(0.14+tuft*0.12)+Vector3.UP*(y-tuft*0.06)
				var w = radius*(0.16-tuft*0.013)
				for tri in [[center+Vector3.UP*0.18, center-side*w, center+dir*0.36+Vector3.DOWN*0.18],[center+Vector3.UP*0.18, center+dir*0.36+Vector3.DOWN*0.18,center+side*w]]:
					for p in tri: st.add_vertex(p)
	st.generate_normals()
	var leaves = G.material(Color("303a22"))
	leaves.cull_mode = BaseMaterial3D.CULL_DISABLED
	_multimesh(st.commit(),leaves,placements)
	# Broken stones and roadside undergrowth give the headlight beam texture.
	var rocks: Array[Transform3D] = []
	for pts in roads:
		for i in range(0,pts.size()-1,4):
			var side = (pts[i+1]-pts[i]).normalized().cross(Vector3.UP)
			for sign_side in [-1,1]:
				var p = pts[i]+side*rng.randf_range(4.8,6.3)*sign_side
				rocks.append(Transform3D(Basis().scaled(Vector3(rng.randf_range(0.2,0.6),rng.randf_range(0.12,0.45),rng.randf_range(0.2,0.5))),p))
	var rock = SphereMesh.new()
	rock.radial_segments = 5
	rock.rings = 3
	_multimesh(rock,G.material(Color("6b6b52")),rocks)

func _multimesh(shape: Mesh, mat: Material, transforms: Array[Transform3D]) -> void:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = shape
	mm.instance_count = transforms.size()
	for i in transforms.size(): mm.set_instance_transform(i,transforms[i])
	var n = MultiMeshInstance3D.new()
	n.multimesh = mm
	n.material_override = mat
	add_child(n)

func _build_landmarks() -> void:
	_sign(Vector3(-4.7,0,-221),"01\nPEDREIRA",0)
	_sign(Vector3(48,0,-391),"02\nSERRA",0)
	for p in [Vector3(-100,0,-344),Vector3(145,0,-460)]:
		G.rod(self,p+Vector3(-3,0.6,0),p+Vector3(3,0.6,0),0.2,G.material(Color("655843")))
		_sign(p+Vector3(-3,0,0),"SEM\nSAÍDA",0)
	var warm = G.material(Color("a48c54"))
	G.box(self,destination+Vector3(4.2,1.7,-7),Vector3(7,3.4,5),G.material(Color("555443"),load("res://assets/ground.png")))
	var roof = G.box(self,destination+Vector3(4.2,3.55,-7),Vector3(8,0.35,6),G.material(Color("282b24")))
	roof.rotation.z = 0.06
	G.box(self,destination+Vector3(4.2,1.2,-4.45),Vector3(1.2,2.4,0.1),G.material(Color("322f22")))
	G.box(self,destination+Vector3(6,1.9,-4.4),Vector3(1.0,1.1,0.08),G.material(Color("ffc985"),null,1.2))
	_sign(destination+Vector3(-3.5,0,-1),"S. PEDRO\nABRIGO",-0.5)
	var lamp = OmniLight3D.new()
	lamp.position = destination+Vector3(3,2.8,-3)
	lamp.light_color = Color("ffc87a")
	lamp.light_energy = 3.0
	lamp.omni_range = 15
	add_child(lamp)
	# A restrained camcorder-only apparition; possession is deliberately not in this prototype.
	ghost = Node3D.new()
	ghost.position = Vector3(-36,0,-151)
	add_child(ghost)
	var dress = G.material(Color("afb8ae"),null,0.2)
	G.cylinder(ghost,Vector3(0,0.78,0),0.31,1.5,dress,0.17)
	G.sphere(ghost,Vector3(0,1.62,0),Vector3(0.29,0.37,0.28),G.material(Color("383b33")))
	G.sphere(ghost,Vector3(0,1.57,0.07),Vector3(0.2,0.23,0.23),dress)
	G.rod(ghost,Vector3(-0.18,1.35,0),Vector3(-0.32,0.67,0.08),0.055,dress)
	G.rod(ghost,Vector3(0.18,1.35,0),Vector3(0.3,0.67,0.08),0.055,dress)
	ghost.visible = false

func _sign(p: Vector3, text: String, angle: float) -> void:
	var n = Node3D.new()
	n.position = p
	n.rotation.y = angle
	add_child(n)
	G.cylinder(n,Vector3(0,1,0),0.045,2,G.material(Color("5c5b50")))
	G.box(n,Vector3(0,1.9,0),Vector3(1.7,0.76,0.08),G.material(Color("383e31")))
	G.label(n,text,Vector3(0,1.9,0.05),85,Color("c2bc99")).pixel_size = 0.003
