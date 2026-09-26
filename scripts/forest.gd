extends Node3D
const G = preload("res://scripts/geometry.gd")
const Features = preload("res://scripts/road_features.gd")

var roads: Array[PackedVector3Array] = []
var road_samples: PackedVector3Array = []
var destination = Vector3(48, 0, -560)
var ghost: Node3D
var rng = RandomNumberGenerator.new()
var region: Dictionary
var cells: Dictionary = {}
var segments: Array = []
var sign_positions: Array[Vector3] = []
var dead_ends: Array[Vector3] = []
var main_route: Array = []
var environment: Environment
var vegetation: Array[MultiMeshInstance3D] = []
var roadside_positions: Array[Vector3] = []
var junctions: Array[Vector3] = []
var shelter: Node3D
var obstacles: Array[Dictionary] = []
var landmark_positions: Array[Vector3] = []
var landmark_clearings: Array[Transform3D] = []

func _ready() -> void:
	rng.seed = 173
	region = JSON.parse_string(FileAccess.get_file_as_string("res://assets/region.json"))
	destination = Vector3(region.destination[0],0,region.destination[1])
	main_route = region.main_route
	for feature in region.get("landmarks",[]):
		landmark_positions.append(Vector3(feature.position[0],0,feature.position[1]))
	for feature in region.get("obstacles",[]):
		obstacles.append({"position":Vector3(feature.position[0],0,feature.position[1]),"basis":Basis(Vector3.UP,feature.yaw),"half":Vector2(feature.half_size[0],feature.half_size[1])})
	_build_environment()
	_build_roads()
	for feature in region.get("landmarks",[]):
		var road: PackedVector3Array=roads[int(feature.road)]
		var i: int=feature.sample
		var forward=(road[i+1]-road[i]).normalized()
		var at=Vector3(feature.position[0],0,feature.position[1])
		landmark_clearings.append(Transform3D(Basis(Vector3.UP,atan2(-forward.x,-forward.z)),(at+road[i])*0.5))
	_build_trees()
	_build_landmarks()
	Features.build(self)

func _build_environment() -> void:
	var e = Environment.new()
	environment = e
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color("040709")
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color("697571")
	e.ambient_light_energy = 0.13
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color("101714")
	e.fog_light_energy = 0.5
	e.fog_density = 0.021
	var world_env = WorldEnvironment.new()
	world_env.environment = e
	add_child(world_env)
	var moon = DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38,-20,0)
	moon.light_color = Color("758c9a")
	moon.light_energy = 0.075
	add_child(moon)
	var ground_mat = G.material(Color("77765c"), load("res://assets/ground.png"))
	ground_mat.uv1_scale = Vector3(1500,1500,1)
	G.box(self, Vector3(0,-0.18,-1500), Vector3(8000,0.3,8000),ground_mat)

func _build_roads() -> void:
	var asphalt = G.material(Color("aaaa91"),load("res://assets/asphalt.png"))
	var shoulder = G.material(Color("797651"),load("res://assets/ground.png"))
	var stripe = G.material(Color("939380"))
	for road in region.roads:
		var pts = PackedVector3Array()
		for p in road.samples: pts.append(Vector3(p[0],0,p[1]))
		roads.append(pts)
		for i in pts.size()-1:
			var id = segments.size()
			segments.append([pts[i],pts[i+1]])
			var key = Vector2i(floori(pts[i].x/16),floori(pts[i].z/16))
			if not cells.has(key): cells[key] = []
			cells[key].append(id)
		if road.kind == "spur": dead_ends.append(pts[-1])
	for pts in roads:
		junctions.append(pts[0])
		junctions.append(pts[-1])
	# Rounded aprons join branches into one continuous, unmarked surface.
	for i in range(1,9):
		var at=Vector3(region.nodes[i][0],0,region.nodes[i][1])
		_disc(at,6.8,0.003,shoulder)
		_disc(at,5.3,0.024,asphalt)
	var post_mat = G.material(Color("86877a"))
	var red_mat = G.material(Color("54251c"),null,0.1)
	for pts in roads:
		_ribbon(pts,5.3,0.002,shoulder)
		_ribbon(pts,3.65,0.022,asphalt)
		var st = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in pts.size()-1:
			if i%7 < 2 and not near_junction(pts[i],15): _quad(st,pts[i],pts[i+1],0.045,0.033)
		st.generate_normals()
		G.mesh(self,st.commit(),Vector3.ZERO,stripe)
		for i in range(10,pts.size()-1,13):
			var side = (pts[i+1]-pts[i]).normalized().cross(Vector3.UP)
			for sign_side in [-1,1]:
				var p = pts[i]+side*4.65*sign_side
				if distance_to_road(p) < 4.5 or near_junction(p,17) or p.distance_to(destination)<23: continue
				G.box(self,p+Vector3(0,0.45,0),Vector3(0.12,0.9,0.12),post_mat)
				G.box(self,p+Vector3(0,0.73,0),Vector3(0.14,0.12,0.14),red_mat)

func _disc(at: Vector3, radius: float, height: float, mat: Material) -> void:
	var st=SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 40:
		var a=float(i)*TAU/40
		var b=float(i+1)*TAU/40
		for p in [at,at+Vector3(cos(b),0,sin(b))*radius,at+Vector3(cos(a),0,sin(a))*radius]:
			st.set_uv(Vector2(p.x,p.z)*0.17)
			st.add_vertex(p+Vector3.UP*height)
	st.generate_normals()
	G.mesh(self,st.commit(),Vector3.ZERO,mat)

func is_drivable(p: Vector3) -> bool:
	return distance_to_road(p)<=4.4 or near_junction(p,4.9)

func blocked_by_obstacle(p: Vector3, yaw: float) -> bool:
	# Four separating axes test the full car footprint against solid hazards.
	# The same authoritative simulation handles driving forwards and reversing.
	var car_basis=Basis(Vector3.UP,yaw)
	for obstacle in obstacles:
		var separation: Vector3=p-obstacle.position
		if separation.length_squared()>100: continue
		var frame: Basis=obstacle.basis
		var half: Vector2=obstacle.half
		var overlap=true
		for axis in [frame.x,frame.z,car_basis.x,car_basis.z]:
			var radius=absf(axis.dot(frame.x))*half.x+absf(axis.dot(frame.z))*half.y
			radius+=absf(axis.dot(car_basis.x))*1.11+absf(axis.dot(car_basis.z))*1.98
			if absf(separation.dot(axis))>=radius:
				overlap=false
				break
		if overlap: return true
	return false

func near_landmark(p: Vector3) -> bool:
	for at in landmark_positions:
		if p.distance_squared_to(at)<81: return true
	for clearing in landmark_clearings:
		var local=clearing.affine_inverse()*p
		if absf(local.x)<11 and absf(local.z)<22: return true
	return false

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
	var sides: Array[Vector3] = []
	for i in pts.size():
		var previous=(pts[i]-pts[maxi(0,i-1)]).normalized() if i>0 else (pts[1]-pts[0]).normalized()
		var next=(pts[mini(i+1,pts.size()-1)]-pts[i]).normalized() if i<pts.size()-1 else previous
		var side=(previous+next).normalized().cross(Vector3.UP)
		sides.append(side*width/maxf(0.7,side.dot(next.cross(Vector3.UP))))
	for i in pts.size()-1:
		var verts=[pts[i]-sides[i],pts[i]+sides[i],pts[i+1]-sides[i+1],pts[i+1]+sides[i+1]]
		for k in [0,2,1,1,2,3]:
			var p=verts[k]+Vector3.UP*height
			st.set_uv(Vector2(p.x,p.z)*0.17)
			st.add_vertex(p)
	st.generate_normals()
	G.mesh(self,st.commit(),Vector3.ZERO,mat)

func distance_to_road(p: Vector3) -> float:
	var key = Vector2i(floori(p.x/16),floori(p.z/16))
	var best = 100000.0
	for x in range(-1,2):
		for z in range(-1,2):
			for id in cells.get(key+Vector2i(x,z),[]):
				var a: Vector3 = segments[id][0]
				var b: Vector3 = segments[id][1]
				var ab = b-a
				var t = clampf((p-a).dot(ab)/ab.length_squared(),0,1)
				best = minf(best,p.distance_squared_to(a+ab*t))
	return sqrt(best)

func map_uv(p: Vector3) -> Vector2:
	var b = region.bounds
	return Vector2((150.0+(p.x-b[0])/(b[2]-b[0])*1500.0)/1800.0,(200.0+(p.z-b[1])/(b[3]-b[1])*1400.0)/1800.0)

func _build_trees() -> void:
	var placements: Array[Transform3D] = []
	for pts in roads:
		for i in range(0,pts.size()-2,4):
			var right = (pts[i+1]-pts[i]).normalized().cross(Vector3.UP)
			for side in [-1,1]:
				for depth in [8.0,15.0,24.0,37.0]:
					var p = pts[i] + right*(depth+rng.randf_range(-1.8,1.8))*side
					p += Vector3(rng.randf_range(-2.8,2.8),0,rng.randf_range(-2.8,2.8))
					if distance_to_road(p) < 6.4 or p.distance_to(destination)<24 or near_landmark(p) or near_junction(p,9): continue
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
	# Sparse mossy stones sit beyond the verge. Every placement checks all roads.
	var rocks: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var grasses: Array[Transform3D] = []
	for pts in roads:
		for i in range(0,pts.size()-1,3):
			var side=(pts[i+1]-pts[i]).normalized().cross(Vector3.UP)
			for sign_side in [-1,1]:
				var p=pts[i]+side*rng.randf_range(5.1,8.5)*sign_side
				if distance_to_road(p)<4.9 or p.distance_to(destination)<23 or near_landmark(p) or near_junction(p,8): continue
				roadside_positions.append(p)
				var turn=Basis(Vector3.UP,rng.randf()*TAU)
				grasses.append(Transform3D(turn.scaled(Vector3.ONE*rng.randf_range(0.6,1.4)),p))
				if i%9==0:
					ferns.append(Transform3D(turn.scaled(Vector3.ONE*rng.randf_range(0.65,1.3)),p))
				if rng.randf()<0.085 and not near_junction(p,22):
					rocks.append(Transform3D(turn.scaled(Vector3(rng.randf_range(0.4,0.8),rng.randf_range(0.15,0.3),rng.randf_range(0.3,0.65))),p-Vector3.UP*0.045))
	var rock=SphereMesh.new()
	rock.radial_segments=7
	rock.rings=4
	_multimesh(rock,G.material(Color("444b37"),load("res://assets/ground.png")),rocks)
	var foliage=G.material(Color("3d4929"))
	foliage.cull_mode=BaseMaterial3D.CULL_DISABLED
	var grass=SurfaceTool.new()
	grass.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 13:
		var angle=i*2.4
		var p=Vector3(cos(angle),0,sin(angle))*rng.randf_range(0.08,0.38)
		var tip=p*1.45+Vector3.UP*rng.randf_range(0.18,0.63)
		for v in [p-Vector3(0.03,0,0.018),p+Vector3(0.03,0,-0.018),tip]: grass.add_vertex(v)
	grass.generate_normals()
	_multimesh(grass.commit(),foliage,grasses)
	var fern=SurfaceTool.new()
	fern.begin(Mesh.PRIMITIVE_TRIANGLES)
	for frond in 7:
		var angle=frond*TAU/7
		var dir=Vector3(cos(angle),0,sin(angle))
		var across=Vector3(-sin(angle),0,cos(angle))
		for leaf in 7:
			var t=(leaf+1)/8.0
			var center=dir*t*0.85+Vector3.UP*(0.13+sin(t*PI)*0.43)
			for side in [-1,1]:
				for v in [center,center+across*side*(1-t)*0.3-dir*0.09,center+dir*0.15]: fern.add_vertex(v)
	fern.generate_normals()
	_multimesh(fern.commit(),foliage,ferns)

func _multimesh(shape: Mesh, mat: Material, transforms: Array[Transform3D]) -> void:
	# Spatial batches keep the enlarged forest inexpensive to draw.
	var chunks: Dictionary = {}
	for t in transforms:
		var key = Vector2i(floori(t.origin.x/128),floori(t.origin.z/128))
		if not chunks.has(key): chunks[key] = []
		chunks[key].append(t)
	for key in chunks:
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = shape
		mm.instance_count = chunks[key].size()
		for i in chunks[key].size(): mm.set_instance_transform(i,chunks[key][i])
		var n = MultiMeshInstance3D.new()
		n.multimesh = mm
		n.material_override = mat
		n.visibility_range_end = 240
		add_child(n)
		vegetation.append(n)

func _build_landmarks() -> void:
	var names = ["LAGOA","CANCELA","CRUZ ALTA","PEDREIRA","FONTE FRIA","MONTE","VALE","ERMITA"]
	for i in 8:
		var pts: PackedVector3Array = roads[i]
		var at = pts.size()-16
		_place_sign(pts[at],(pts[at+1]-pts[at]).normalized(),"%02d\n%s" % [i+1,names[i]])
	for road_index in roads.size():
		if region.roads[road_index].kind != "spur": continue
		var pts: PackedVector3Array = roads[road_index]
		var end = pts[-1]
		var side = (end-pts[-2]).normalized().cross(Vector3.UP)
		G.rod(self,end-side*3.6+Vector3.UP*0.6,end+side*3.6+Vector3.UP*0.6,0.18,G.material(Color("655843")))
		_place_sign(pts[-12],(pts[-11]-pts[-12]).normalized(),"CAMINHO\nFECHADO")
	_build_shelter()
	_place_sign(roads[8][-18],(roads[8][-17]-roads[8][-18]).normalized(),"S. PEDRO\nABRIGO")
	# A restrained camcorder-only apparition; possession is deliberately not in this prototype.
	ghost = Node3D.new()
	ghost.position = roads[0][65]+Vector3(6,0,0)
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

func _place_sign(center: Vector3, forward: Vector3, text: String) -> void:
	var side = forward.cross(Vector3.UP)
	for offset in [6.5,-6.5,8.5,-8.5,11.0,-11.0]:
		var p = center+side*offset
		if distance_to_road(p) >= 5.8:
			_sign(p,text,atan2(-forward.x,-forward.z))
			sign_positions.append(p)
			return

func near_junction(p: Vector3, radius: float) -> bool:
	for at in junctions:
		if p.distance_squared_to(at)<radius*radius: return true
	return false

func _build_shelter() -> void:
	# Orient the clearing and refuge toward the final approach.
	shelter=Node3D.new()
	shelter.name="SaoPedroRefuge"
	shelter.position=destination
	var approach=(roads[8][-1]-roads[8][-2]).normalized()
	shelter.rotation.y=atan2(-approach.x,-approach.z)
	add_child(shelter)
	var stone=G.material(Color("767767"),load("res://assets/ground.png"))
	var plaster=G.material(Color("a2a28a"),load("res://assets/vinyl.png"))
	var timber=G.material(Color("353e30"),load("res://assets/bark.png"))
	var tiles=G.material(Color("514437"),load("res://assets/bark.png"))
	var dark=G.material(Color("171d18"))
	var glass=G.material(Color("f2bb70"),null,1.0)
	G.box(shelter,Vector3(0,-0.015,-6),Vector3(24,0.08,30),stone)
	G.box(shelter,Vector3(0,0.25,-15),Vector3(10.9,0.5,7.8),stone)
	G.box(shelter,Vector3(0,2.1,-15),Vector3(10,3.7,6.8),plaster)
	# Pitched terracotta roof with a ridge and visible courses.
	for side in [-1,1]:
		var roof=G.box(shelter,Vector3(side*2.65,4.65,-15),Vector3(6,0.18,8.2),tiles)
		roof.rotation.z=-side*0.40
		for row in 9:
			var x=side*(0.3+row*0.6)
			G.rod(shelter,Vector3(x,5.72-absf(x)*0.423,-19.15),Vector3(x,5.72-absf(x)*0.423,-10.85),0.044,tiles)
	G.rod(shelter,Vector3(0,5.78,-19.3),Vector3(0,5.78,-10.7),0.13,tiles)
	G.box(shelter,Vector3(3.1,5.2,-16.9),Vector3(0.9,2.9,0.85),stone)
	G.box(shelter,Vector3(3.1,6.69,-16.9),Vector3(1.1,0.18,1.05),dark)
	# Gable end infill, front and back.
	var gable=SurfaceTool.new()
	gable.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in [-11.59,-18.41]:
		for v in [Vector3(-5,3.95,z),Vector3(5,3.95,z),Vector3(0,5.73,z)]: gable.add_vertex(v)
	gable.generate_normals()
	plaster.cull_mode=BaseMaterial3D.CULL_DISABLED
	G.mesh(shelter,gable.commit(),Vector3.ZERO,plaster)
	G.box(shelter,Vector3(0,1.6,-11.5),Vector3(1.52,2.75,0.16),timber)
	G.box(shelter,Vector3(0,2.37,-11.4),Vector3(1.08,0.87,0.035),glass)
	for x in [-0.48,0,0.48]: G.box(shelter,Vector3(x,2.37,-11.36),Vector3(0.045,0.87,0.03),timber)
	G.sphere(shelter,Vector3(0.52,1.25,-11.36),Vector3(0.06,0.06,0.06),stone)
	for x in [-3.2,3.2]:
		G.box(shelter,Vector3(x,2.13,-11.49),Vector3(1.85,1.67,0.17),stone)
		G.box(shelter,Vector3(x,2.13,-11.37),Vector3(1.55,1.35,0.03),glass)
		for offset in [-0.85,0.85]: G.box(shelter,Vector3(x+offset,2.13,-11.24),Vector3(0.45,1.55,0.12),timber)
		G.box(shelter,Vector3(x,2.13,-11.3),Vector3(0.065,1.4,0.06),timber)
		G.box(shelter,Vector3(x,2.13,-11.3),Vector3(1.6,0.065,0.06),timber)
		G.box(shelter,Vector3(x,1.3,-11.2),Vector3(2.0,0.13,0.42),stone)
	# Sheltered porch, stepping stones, a bench and a lit ceramic plaque.
	for step in 3:
		G.box(shelter,Vector3(0,0.055+step*0.075,-9.0-step*0.65),Vector3(4.2-step*0.2,0.12+step*0.15,0.8),stone)
	for x in [-2.25,2.25]: G.box(shelter,Vector3(x,1.65,-9.4),Vector3(0.17,3.3,0.17),timber)
	var canopy=G.box(shelter,Vector3(0,3.36,-10.2),Vector3(5.5,0.16,3.1),tiles)
	canopy.rotation.x=-0.13
	G.box(shelter,Vector3(0,3.02,-11.36),Vector3(1.9,0.33,0.09),dark)
	G.label(shelter,"ABRIGO · SÃO PEDRO",Vector3(0,3.02,-11.30),36,Color("e1d9bd")).pixel_size=0.0023
	G.box(shelter,Vector3(3.5,0.73,-9.9),Vector3(2.15,0.15,0.56),timber)
	G.box(shelter,Vector3(3.5,1.14,-10.12),Vector3(2.15,0.50,0.10),timber)
	for x in [2.7,4.3]: G.box(shelter,Vector3(x,0.38,-9.9),Vector3(0.14,0.65,0.48),timber)
	for x in [-1.2,1.2]:
		G.box(shelter,Vector3(x,2.62,-11.2),Vector3(0.24,0.4,0.25),dark)
		G.box(shelter,Vector3(x,2.62,-11.04),Vector3(0.15,0.28,0.04),glass)
		var lamp=OmniLight3D.new()
		lamp.position=Vector3(x,2.6,-10.7)
		lamp.light_color=Color("ffc27b")
		lamp.light_energy=2.4
		lamp.omni_range=13
		shelter.add_child(lamp)
	for side in [-1,1]:
		G.box(shelter,Vector3(side*9,0.42,-7),Vector3(0.65,0.85,20),stone)
		for z in [-1,-6,-11]:
			G.box(shelter,Vector3(side*9,0.72,z),Vector3(0.95,1.4,0.95),stone)
