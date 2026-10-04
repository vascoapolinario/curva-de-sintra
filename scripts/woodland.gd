extends Node3D
## Spatial woodland moods are deterministic across all three players.
const G=preload("res://scripts/geometry.gd")
var forest: Node3D
var zones: Array[Dictionary]=[]
var sightings: Array[Vector3]=[]
var clearings: Array[Transform3D]=[]
var sightlines: Array[PackedVector3Array]=[]
var encounters: Array[Dictionary]=[]
var fires: Array[Dictionary]=[]
var tension=0.0
var fog=0.012
var broadleaf_count=0
var dead_count=0
var shrub_count=0

func setup(world: Node3D) -> void:
	forest=world
	# Long quiet intervals separate the denser, unsettling stretches.
	for entry in [[0,0.30,130.0,false],[3,0.65,155.0,false],[6,0.33,130.0,false],[12,0.60,125.0,false],[1,0.70,155.0,true],[4,0.68,170.0,true],[7,0.44,160.0,true],[9,0.48,140.0,true],[11,0.62,160.0,true]]:
		var road: PackedVector3Array=forest.roads[entry[0]]
		var index=int(float(road.size()-2)*entry[1])
		zones.append({"center":road[index],"radius":entry[2],"dark":entry[3],"road":entry[0],"sample":index})
	for entry in [[1,0.73,-31.0,true],[4,0.72,29.0,false],[7,0.47,34.0,true],[11,0.66,-32.0,false]]:
		var road: PackedVector3Array=forest.roads[entry[0]]
		var index=int(float(road.size()-2)*entry[1])
		var forward=(road[index+1]-road[index]).normalized()
		var right=forward.cross(Vector3.UP)
		var p=road[index]+right*entry[2]
		# Avoid other routes and the mapped landmark clearings.
		if forest.distance_to_road(p)<16 or forest.near_landmark(p): continue
		sightings.append(p)
		encounters.append({"road":entry[0],"sample":index,"position":p,"side":entry[2]})
		clearings.append(Transform3D(Basis(Vector3.UP,atan2(-forward.x,-forward.z)),p))
		for approach in [-32,-12,8]:
			sightlines.append(PackedVector3Array([road[clampi(index+approach,0,road.size()-1)],p]))
		_build_encounter(p,atan2(-forward.x,-forward.z),entry[3],sightings.size())

func weights(p: Vector3) -> Vector2:
	var result=Vector2.ZERO
	for zone in zones:
		var d=p.distance_to(zone.center)/float(zone.radius)
		var strength=1.0-smoothstep(0.35,1.0,d)
		if zone.dark: result.y=maxf(result.y,strength)
		else: result.x=maxf(result.x,strength)
	return result

func tree_density(p: Vector3) -> float:
	var mood=weights(p)
	return clampf(0.74-mood.x*0.65+mood.y*0.24+sin(p.x*0.009+p.z*0.013)*0.08,0.07,1)

func in_sighting_clearing(p: Vector3) -> bool:
	for space in clearings:
		var local=space.affine_inverse()*p
		# A gap across the verge provides brief views of the fire/silhouettes.
		if absf(local.x)<9 and absf(local.z)<10: return true
	for ray in sightlines:
		var along=ray[1]-ray[0]
		var t=clampf((p-ray[0]).dot(along)/along.length_squared(),0,1)
		if p.distance_squared_to(ray[0]+along*t)<30.25: return true
	return false

func update_mood(p: Vector3, time: float, delta: float) -> void:
	var mood=weights(p)
	tension=lerpf(tension,mood.y,1-exp(-delta*0.7))
	# Mist rises and recedes in slow banks; it never becomes a white wall.
	var bank=smoothstep(-0.1,0.8,sin(time*0.038+p.x*0.004+p.z*0.002))
	var target_fog=0.008+mood.y*0.010+bank*(0.004+mood.y*0.009)
	fog=lerpf(fog,target_fog,1-exp(-delta*0.45))
	forest.environment.fog_density=fog
	forest.environment.fog_light_color=Color("0d1413").lerp(Color("1e2928"),bank*0.38)
	forest.environment.ambient_light_energy=lerpf(forest.environment.ambient_light_energy,0.10+mood.x*0.014-mood.y*0.044,1-exp(-delta*0.55))
	forest.moon.light_energy=lerpf(forest.moon.light_energy,0.056+mood.x*0.014-mood.y*0.033,1-exp(-delta*0.55))
	for fire in fires:
		var phase=time+fire.phase
		fire.light.light_energy=2.0+0.30*sin(phase*7.3)+0.18*sin(phase*13.7)
		fire.material.set_shader_parameter("clock",phase)
		fire.root.visible=p.distance_squared_to(fire.root.position)<220*220

func build_species(broadleaf: Array[Transform3D], dead: Array[Transform3D]) -> void:
	broadleaf_count=broadleaf.size()
	dead_count=dead.size()
	var timber=SurfaceTool.new()
	timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	_branch(timber,Vector3.ZERO,Vector3(0.25,4.2,0.12),0.21)
	_branch(timber,Vector3(0.25,4.2,0.12),Vector3(-0.4,8.1,0.3),0.15)
	var leaves=SurfaceTool.new()
	leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 8:
		var angle=i*2.4
		var start=Vector3(0.15,3.5+i*0.44,0)
		var tip=start+Vector3(cos(angle)*2.7,1.5,sin(angle)*2.7)
		_branch(timber,start,tip,0.09)
		for tuft in 18:
			var a=tuft*2.4
			var center=tip+Vector3(cos(a)*1.5,sin(tuft*1.7)*0.38,sin(a)*1.5)
			_leaf(leaves,center,0.70,a)
	forest._multimesh(timber.commit(),G.material(Color("929582"),load("res://assets/bark.png")),broadleaf)
	leaves.generate_normals()
	var leaf_mat=G.material(Color("293921"))
	leaf_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	forest._multimesh(leaves.commit(),leaf_mat,broadleaf)
	var skeleton=SurfaceTool.new()
	skeleton.begin(Mesh.PRIMITIVE_TRIANGLES)
	_branch(skeleton,Vector3.ZERO,Vector3(-0.24,4.5,0.1),0.24)
	_branch(skeleton,Vector3(-0.24,4.5,0.1),Vector3(0.4,9.4,-0.3),0.12)
	for i in 7:
		var a=i*2.4
		var start=Vector3(0,3+i*0.65,0)
		var elbow=start+Vector3(cos(a)*1.7,0.4,sin(a)*1.7)
		var tip=elbow+Vector3(cos(a+0.4)*0.7,1.3,sin(a+0.4)*0.7)
		_branch(skeleton,start,elbow,0.10)
		_branch(skeleton,elbow,tip,0.055)
	forest._multimesh(skeleton.commit(),G.material(Color("646951"),load("res://assets/bark.png")),dead)

func build_undergrowth() -> void:
	var random=RandomNumberGenerator.new()
	random.seed=2941
	var grass: Array[Transform3D]=[]
	var shrubs: Array[Transform3D]=[]
	for road in forest.roads:
		for i in range(1,road.size()-2,5):
			var right=(road[i+1]-road[i]).normalized().cross(Vector3.UP)
			for side in [-1,1]:
				for depth in [6.0,9.0,14.0,21.0,30.0]:
					var p=road[i]+right*side*(depth+random.randf_range(-0.7,1.7))
					p+=Vector3(random.randf_range(-2,2),0,random.randf_range(-2,2))
					if forest.distance_to_road(p)<5.0 or forest.near_junction(p,9) or forest.near_landmark(p) or p.distance_to(forest.destination)<25: continue
					var mood=weights(p)
					var turn=Basis(Vector3.UP,random.randf()*TAU)
					var size=random.randf_range(0.8,1.6)
					grass.append(Transform3D(turn.scaled(Vector3(size,0.8+mood.x*0.6,size)),p))
					forest.roadside_positions.append(p)
					if random.randf()<0.47+mood.y*0.25-mood.x*0.35 and not in_sighting_clearing(p):
						shrubs.append(Transform3D(turn.scaled(Vector3.ONE*random.randf_range(0.75,1.4)),p))
	shrub_count=shrubs.size()
	var blades=SurfaceTool.new()
	blades.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 24:
		var a=i*2.4
		var p=Vector3(cos(a),0,sin(a))*random.randf_range(0.15,1.1)
		var side=Vector3(-sin(a),0,cos(a))*0.045
		for v in [p-side,p+side,p*1.17+Vector3.UP*random.randf_range(0.25,0.75)]: blades.add_vertex(v)
	blades.generate_normals()
	var grass_mat=G.material(Color("4a5030"))
	grass_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	forest._multimesh(blades.commit(),grass_mat,grass)
	var bush=SurfaceTool.new()
	bush.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 45:
		var a=i*2.4
		var radius=random.randf_range(0.12,1.05)
		var center=Vector3(cos(a)*radius,0.18+sqrt(1.3-radius)*random.randf_range(0.4,1.1),sin(a)*radius)
		_leaf(bush,center,random.randf_range(0.20,0.45),a)
	bush.generate_normals()
	var bush_mat=G.material(Color("303e28"))
	bush_mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	forest._multimesh(bush.commit(),bush_mat,shrubs)

func _build_encounter(p: Vector3, yaw: float, burning: bool, number: int) -> void:
	var root=Node3D.new()
	root.position=p
	root.rotation.y=yaw
	add_child(root)
	var char=G.material(Color("30372d"))
	char.disable_receive_shadows=true
	var pale=G.material(Color("777e6c"),null,0.045)
	pale.disable_receive_shadows=true
	# Tall, asymmetrical shapes: their silhouettes could almost be dead trees.
	for i in (2 if burning else 3):
		var figure=Node3D.new()
		figure.position=Vector3((i-1)*3.6,0,-3-i*1.2)
		figure.rotation=Vector3(0.06,0.4*i,-0.08 if i%2==0 else 0.11)
		figure.scale.y=1.10+i*0.10
		root.add_child(figure)
		G.cylinder(figure,Vector3(0,1.5,0),0.34,1.8,char,0.15)
		G.sphere(figure,Vector3(0.05,2.65,0),Vector3(0.28,0.46,0.25),pale)
		for side in [-1,1]:
			G.rod(figure,Vector3(side*0.13,0.8,0),Vector3(side*0.20,0.1,0.03),0.07,char)
			var elbow=Vector3(side*0.56,1.68+0.2*side,0.04)
			G.rod(figure,Vector3(side*0.19,2.24,0),elbow,0.07,char)
			G.rod(figure,elbow,Vector3(side*0.65,0.79+0.2*side,0.23),0.045,char)
		if i==1:
			G.rod(figure,Vector3(0.02,2.78,0),Vector3(-0.42,3.1,0.05),0.035,char)
			G.rod(figure,Vector3(-0.42,3.1,0.05),Vector3(-0.54,3.45,0),0.024,char)
	if not burning: return
	var earth=G.material(Color("646347"),load("res://assets/ground.png"))
	G.cylinder(root,Vector3(0,-0.015,0),7,0.04,earth)
	var stone=G.material(Color("494b3e"))
	for i in 9:
		var a=i*TAU/9
		G.sphere(root,Vector3(cos(a)*0.7,0.10,sin(a)*0.7),Vector3(0.3,0.25,0.27),stone)
	for i in 4:
		var a=i*PI/4
		G.rod(root,Vector3(cos(a)*-0.65,0.2,sin(a)*-0.65),Vector3(cos(a)*0.65,0.2,sin(a)*0.65),0.11,char)
	var fire=ShaderMaterial.new()
	fire.shader=load("res://shaders/fire.gdshader")
	for angle in [0.0,PI/2]:
		var quad=QuadMesh.new()
		quad.size=Vector2(1.5,1.7)
		var flame=G.mesh(root,quad,Vector3(0,0.85,0),fire)
		flame.rotation.y=angle
		flame.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow=OmniLight3D.new()
	glow.position=Vector3(0,1.15,0)
	glow.light_color=Color("ff8b36")
	glow.light_energy=2.0
	glow.omni_range=18
	root.add_child(glow)
	fires.append({"root":root,"light":glow,"material":fire,"phase":number*13.7})

static func _branch(st: SurfaceTool, a: Vector3, b: Vector3, radius: float) -> void:
	var shape=CylinderMesh.new()
	shape.radial_segments=5
	shape.bottom_radius=radius
	shape.top_radius=radius*0.5
	shape.height=a.distance_to(b)
	var up=(b-a).normalized()
	var right=(Vector3.RIGHT if absf(up.y)>0.98 else Vector3.UP).cross(up).normalized()
	st.append_from(shape,0,Transform3D(Basis(right,up,right.cross(up)),(a+b)*0.5))

static func _leaf(st: SurfaceTool, center: Vector3, width: float, angle: float) -> void:
	var side=Vector3(cos(angle),0.15,sin(angle))*width
	var across=Vector3(-sin(angle),0,cos(angle))*width*0.65
	for p in [center-side,center+across,center+Vector3.UP*0.19,center+across,center+side,center+Vector3.UP*0.19,center+side,center-across,center+Vector3.UP*0.19,center-across,center-side,center+Vector3.UP*0.19]: st.add_vertex(p)
