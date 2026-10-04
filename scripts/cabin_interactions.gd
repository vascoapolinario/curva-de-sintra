extends Node3D
const G=preload("res://scripts/geometry.gd")
const MAP_DOCK=Vector3(0.64,1.068,-0.84)
const CAMERA_DOCK=Vector3(0.69,0.83,1.12)
var game: Node
var map_dock: Node3D
var camera_dock: Node3D
var headlight_button: Node3D
var indicator: StandardMaterial3D

func setup(owner_game: Node) -> void:
	game=owner_game
	var black=G.material(Color("1b211d"))
	var rubber=G.material(Color("3a4037"))
	var ivory=G.material(Color("b3b097"))
	# Recessed headlight button on the left spoke; its mesh and hit target rotate with the wheel.
	G.box(game.car.wheel,Vector3(-0.120,0.018,0),Vector3(0.075,0.025,0.066),black)
	headlight_button=Node3D.new()
	headlight_button.position=Vector3(-0.120,0.036,0)
	headlight_button.rotation.x=-PI/2
	game.car.wheel.add_child(headlight_button)
	G.box(headlight_button,Vector3.ZERO,Vector3(0.057,0.040,0.020),rubber)
	# Painted headlight symbol, no text plaque.
	G.rod(headlight_button,Vector3(-0.006,-0.010,0.011),Vector3(-0.006,0.010,0.011),0.0015,ivory)
	for i in 3:
		G.rod(headlight_button,Vector3(-0.023,-0.007+i*0.007,0.011),Vector3(-0.012,-0.007+i*0.007,0.011),0.001,ivory)
	for i in 6:
		var a=-PI/2+PI*i/5.0
		G.sphere(headlight_button,Vector3(-0.006+cos(a)*0.009,sin(a)*0.010,0.011),Vector3.ONE*0.003,ivory)
	indicator=G.material(Color("7b925b"),null,0.3)
	G.box(headlight_button,Vector3(0.022,0,0.011),Vector3(0.004,0.012,0.002),indicator)
	map_dock=Node3D.new()
	map_dock.position=MAP_DOCK
	map_dock.rotation.y=-0.13
	add_child(map_dock)
	var edge=G.material(Color("b8ab7d"))
	for i in 4:
		G.box(map_dock,Vector3((i%2)*0.003,i*0.003,0),Vector3(0.242,0.003,0.185),edge)
	var cover=QuadMesh.new()
	cover.size=Vector2(0.242,0.185)
	var paper=G.material(Color("c6ba94"),load("res://assets/sintra_map.png"))
	paper.uv1_scale=Vector3(0.34,0.48,1)
	paper.uv1_offset=Vector3(0.33,0.22,0)
	var face=G.mesh(map_dock,cover,Vector3(0,0.012,0),paper)
	face.rotation.x=-PI/2
	G.rod(map_dock,Vector3(-0.117,0.014,-0.088),Vector3(-0.117,0.014,0.088),0.002,edge)
	camera_dock=Node3D.new()
	camera_dock.position=CAMERA_DOCK
	camera_dock.rotation.y=-0.35
	add_child(camera_dock)
	game.car._camcorder(camera_dock)
	# A loose carry strap makes its resting position read as a physical object.
	for pair in [[Vector3(0.08,-0.01,0.10),Vector3(0.15,-0.052,0.06)],[Vector3(0.15,-0.052,0.06),Vector3(0.15,-0.052,-0.07)],[Vector3(0.15,-0.052,-0.07),Vector3(0.08,-0.01,-0.10)]]:
		G.rod(camera_dock,pair[0],pair[1],0.008,black)

func _touch(node: Node3D, size: Vector3, offset: Vector3=Vector3.ZERO) -> bool:
	var origin=node.to_local(game.car.camera.global_position)
	var direction=node.global_basis.inverse()*(-game.car.camera.global_basis.z)
	var result=AABB(offset-size*0.5,size).intersects_ray(origin,direction)
	return result!=null and node.to_global(result).distance_to(game.car.camera.global_position)<1.8

func hit() -> String:
	if not game.running or game.input_blocked(): return ""
	if game.tool_on:
		# The paper fills the centre of the view; filming looks through the camera itself.
		return "map_stow" if game.local_seat==1 else "camera_stow"
	if game.car.tool_blend>0.02: return ""
	match game.local_seat:
		0:
			if _touch(game.car.horn_pad,Vector3(0.14,0.085,0.12)): return "horn"
			if _touch(headlight_button,Vector3(0.065,0.050,0.032)): return "headlights"
		1:
			if _touch(map_dock,Vector3(0.27,0.045,0.21)): return "map_pickup"
		2:
			if _touch(camera_dock,Vector3(0.32,0.17,0.43),Vector3(-0.045,0,-0.025)): return "camera_pickup"
	return ""

func use(control: String) -> bool:
	if not game.running or game.input_blocked(): return false
	match control:
		"horn":
			if game.local_seat!=0: return false
			game.horn_pressed=true
			game.effects.request_horn(true)
		"headlights":
			if game.local_seat!=0: return false
			game.effects.request_lights()
		"map_pickup","map_stow":
			if game.local_seat!=1: return false
			game.tool_on=control=="map_pickup"
		"camera_pickup","camera_stow":
			if game.local_seat!=2: return false
			game.tool_on=control=="camera_pickup"
		_: return false
	game.pointing=false
	return true

func animate(delta: float) -> void:
	var map_held: bool=game.tool_on or game.car.tool_blend>0.001 if game.local_seat==1 else game.poses[1].z>0.5
	var camera_held: bool=game.tool_on or game.car.tool_blend>0.001 if game.local_seat==2 else game.poses[2].z>0.5
	map_dock.visible=not map_held
	camera_dock.visible=not camera_held
	game.car.horn_pad.position.y=lerpf(game.car.horn_pad.position.y,-0.007 if game.effects.honking else 0.0,1-exp(-delta*20))
	headlight_button.position.y=0.032 if game.effects.headlights else 0.036
	indicator.emission_energy_multiplier=0.3 if game.effects.headlights else 0.0
