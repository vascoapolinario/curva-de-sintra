extends Node3D
const G=preload("res://scripts/geometry.gd")
const WARM=Color("f2ca8e")
var game: Node
var front_mode=0
var rear_on=false
var front: OmniLight3D
var rear: OmniLight3D
var instruments: Array[OmniLight3D]=[]
var lenses: Array[StandardMaterial3D]=[]
var covers: Array[Node3D]=[]
var targets={"front_light":Vector3(0,1.875,-0.43),"rear_light":Vector3(0,1.875,0.88)}

func setup(owner_game: Node) -> void:
	game=owner_game
	var trim=G.material(Color("393e37"))
	var gasket=G.material(Color("171d18"))
	for i in 2:
		var z=-0.43 if i==0 else 0.88
		G.box(self,Vector3(0,1.911,z),Vector3(0.32,0.045,0.20),trim)
		G.box(self,Vector3(0,1.889,z),Vector3(0.278,0.018,0.16),gasket)
		var lens=G.material(Color("aaa58b"))
		lens.emission_enabled=true
		lenses.append(lens)
		var cover=Node3D.new()
		cover.position=Vector3(0,1.880,z)
		add_child(cover)
		covers.append(cover)
		G.box(cover,Vector3.ZERO,Vector3(0.258,0.026,0.143),lens)
		# Fine fluting is moulded into the press-to-switch lens, without a separate button.
		var flute=G.material(Color("b0a991"))
		for rib in 13:
			G.box(cover,Vector3(-0.114+rib*0.019,-0.014,0),Vector3(0.002,0.002,0.124),flute)
		for x in [-0.146,0.146]:
			G.cylinder(self,Vector3(x,1.886,z),0.004,0.002,gasket)
		var bulb=OmniLight3D.new()
		bulb.position=Vector3(0,1.79,z)
		bulb.omni_range=1.9 if i==0 else 1.5
		bulb.light_energy=0.30 if i==0 else 0.24
		bulb.light_color=WARM
		add_child(bulb)
		if i==0: front=bulb
		else: rear=bulb
	for at in [Vector3(-0.49,1.07,-0.35),Vector3(0.12,0.96,-0.37)]:
		var bulb=OmniLight3D.new()
		bulb.position=at
		bulb.light_color=Color("d7a864")
		bulb.omni_range=0.9
		bulb.light_energy=0.15
		add_child(bulb)
		instruments.append(bulb)
	reset()

func reset() -> void:
	front_mode=0
	rear_on=false
	_apply()

func use(control: String) -> bool:
	if control.is_empty() or not game.running or game.input_blocked(): return false
	match control:
		"front_light":
			if game.local_seat==2: return false
			front_mode=1-front_mode
		"rear_light":
			if game.local_seat!=2: return false
			rear_on=not rear_on
		_: return false
	_apply()
	if DisplayServer.get_name()!="headless": game.effects.switch_sound.play()
	return true

func _apply() -> void:
	front.visible=front_mode>0
	rear.visible=rear_on
	for i in 2:
		var enabled=front_mode>0 if i==0 else rear_on
		lenses[i].albedo_color=WARM if enabled else Color("8c8978")
		lenses[i].emission=WARM
		lenses[i].emission_energy_multiplier=0.32 if enabled else 0.0
		covers[i].rotation.z=0.015 if enabled else -0.015
	game.car.gauge_material.albedo_color=Color.WHITE
	game.car.gauge_material.emission_energy_multiplier=0.55

func hit() -> String:
	if not game.running or game.input_blocked() or game.tool_on or game.car.tool_blend>0.02: return ""
	var origin=game.car.to_local(game.car.camera.global_position)
	var direction=game.car.global_basis.inverse()*(-game.car.camera.global_basis.z)
	var controls=["rear_light"] if game.local_seat==2 else ["front_light"]
	for control in controls:
		var center: Vector3=targets[control]
		var size=Vector3(0.28,0.052,0.165)
		var result=AABB(center-size*0.5,size).intersects_ray(origin,direction)
		if result!=null and origin.distance_to(result)<1.8: return control
	return ""
