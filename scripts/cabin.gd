extends Node3D
const G = preload("res://scripts/geometry.gd")
const EYES = [Vector3(-0.49,1.44,0.34),Vector3(0.49,1.44,0.34),Vector3(0,1.56,1.34)]
var camera: Camera3D
var look: Node3D
var wheel: Node3D
var map_prop: Node3D
var cam_prop: Node3D
var heads: Array[Node3D] = []
var people: Array[Node3D] = []
var remote_tools: Array[Node3D] = []
var pendant: Node3D
var speed_label: Label3D
var mirror_camera: Camera3D
var map_material: ShaderMaterial
var radio_display: Label3D
var arms: Array = []
var base_fov = 78.0
var sway_amount = 0.65
var local_seat = 0
var tool_blend = 0.0
var zooming = false
var wing_cameras: Array[Camera3D] = []
var hands: Array = []
var point_fingers: Array = []
var gesture_blend = [0.0,0.0,0.0]
var clock_display: Label3D
var radio_targets: Array = []
var radio_knobs: Array[Node3D] = []

func _ready() -> void:
	_build_shell()
	_build_instruments()
	_build_people()
	look = Node3D.new()
	look.position = EYES[0]
	add_child(look)
	camera = Camera3D.new()
	camera.fov = 78
	camera.near = 0.025
	camera.far = 180
	camera.current = true
	look.add_child(camera)
	_build_tools()
	select_seat(0)

func _build_shell() -> void:
	var vinyl = G.material(Color("66685e"),load("res://assets/vinyl.png"))
	var trim = G.material(Color("242a26"))
	var cloth = G.material(Color("a3a08a"),load("res://assets/cloth.png"))
	var metal = G.material(Color("727367"))
	G.box(self,Vector3(0,0.25,0.15),Vector3(2.22,0.18,3.95),trim)
	G.box(self,Vector3(0,1.99,0.18),Vector3(2.1,0.13,3.0),vinyl)
	G.box(self,Vector3(0,0.92,-0.9),Vector3(2.07,0.25,0.71),vinyl)
	G.box(self,Vector3(0,0.82,-1.62),Vector3(1.97,0.14,1.04),G.material(Color("29302a")))
	G.box(self,Vector3(0,0.65,-0.62),Vector3(2.04,0.43,0.18),trim)
	for s in [-1,1]:
		G.box(self,Vector3(s*1.055,0.65,0.4),Vector3(0.13,0.83,3.3),vinyl)
		G.box(self,Vector3(s*1.015,1.01,0.5),Vector3(0.12,0.07,3.0),trim)
		G.rod(self,Vector3(s*1.02,1.02,-1.1),Vector3(s*0.90,1.96,-0.68),0.055,trim)
		G.rod(self,Vector3(s*1.055,0.96,0.77),Vector3(s*1.00,1.97,0.71),0.062,trim)
		G.rod(self,Vector3(s*1.02,1.0,1.95),Vector3(s*0.93,1.96,1.58),0.065,trim)
		G.box(self,Vector3(s*0.99,0.83,0.07),Vector3(0.09,0.075,0.36),trim)
		G.box(self,Vector3(s*0.982,0.92,-0.18),Vector3(0.028,0.026,0.14),metal)
		# Exterior wing mirrors, visible when looking to either side.
		var housing = Node3D.new()
		housing.position = Vector3(s*1.17,1.22,-0.77)
		housing.rotation.y = -s*0.55
		add_child(housing)
		G.rod(self,Vector3(s*1.01,1.12,-0.79),housing.position,0.028,trim)
		G.box(housing,Vector3.ZERO,Vector3(0.31,0.20,0.12),trim)
		_wing_mirror(housing,s)
	G.box(self,Vector3(0,1.04,1.94),Vector3(2.04,0.15,0.38),vinyl)
	for x in [-0.49,0.49]:
		G.box(self,Vector3(x,0.61,0.18),Vector3(0.74,0.23,0.77),cloth)
		var back = G.box(self,Vector3(x,0.91,0.53),Vector3(0.70,0.68,0.18),cloth)
		back.rotation.x = -0.10
		G.rod(self,Vector3(x-0.13,1.20,0.56),Vector3(x-0.13,1.32,0.56),0.012,metal)
		G.rod(self,Vector3(x+0.13,1.20,0.56),Vector3(x+0.13,1.32,0.56),0.012,metal)
		G.box(self,Vector3(x,1.30,0.58),Vector3(0.39,0.19,0.15),cloth)
	G.box(self,Vector3(0,0.63,1.48),Vector3(1.91,0.25,0.73),cloth)
	G.box(self,Vector3(0,0.99,1.83),Vector3(1.91,0.69,0.18),cloth)
	for x in [-0.58,0.58]: G.box(self,Vector3(x,1.42,1.8),Vector3(0.38,0.26,0.16),cloth)
	# Headlights are mounted ahead of the hood, leaving the interior in shadow.
	for x in [-0.69,0.69]:
		var light = SpotLight3D.new()
		light.position = Vector3(x,0.83,-2.19)
		light.rotation.x = -0.045
		light.light_color = Color("ffe3a1")
		light.light_energy = 5.2
		light.spot_range = 77
		light.spot_angle = 38
		light.spot_attenuation = 0.75
		light.spot_angle_attenuation = 0.5
		light.shadow_enabled = true
		light.shadow_bias = 0.08
		add_child(light)
	var glow = OmniLight3D.new()
	glow.position = Vector3(0,1.65,-0.05)
	glow.light_color = Color("a39360")
	glow.light_energy = 0.25
	glow.omni_range = 2.5
	add_child(glow)

func _build_instruments() -> void:
	var dark = G.material(Color("141815"))
	var bezel = G.material(Color("626559"))
	var amber = G.material(Color("b8ba79"),null,0.5)
	G.box(self,Vector3(-0.49,1.015,-0.53),Vector3(0.70,0.34,0.12),dark)
	var panel = QuadMesh.new()
	panel.size = Vector2(0.60,0.30)
	var gauge_mat = G.material(Color.WHITE,load("res://assets/gauges.png"))
	gauge_mat.emission_enabled = true
	gauge_mat.emission_texture = load("res://assets/gauges.png")
	gauge_mat.emission = Color("c5d17e")
	gauge_mat.emission_energy_multiplier = 0.8
	gauge_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	G.mesh(self,panel,Vector3(-0.49,1.025,-0.458),gauge_mat)
	wheel = Node3D.new()
	wheel.position = Vector3(-0.49,0.95,-0.22)
	wheel.rotation.x = deg_to_rad(68)
	add_child(wheel)
	var ring = TorusMesh.new()
	ring.inner_radius = 0.193
	ring.outer_radius = 0.23
	ring.rings = 24
	ring.ring_segments = 8
	G.mesh(wheel,ring,Vector3.ZERO,dark)
	G.box(wheel,Vector3.ZERO,Vector3(0.36,0.045,0.046),dark)
	G.box(wheel,Vector3(0,0,0.09),Vector3(0.04,0.045,0.19),dark)
	G.box(wheel,Vector3.ZERO,Vector3(0.115,0.065,0.095),bezel)
	# Cassette radio, vent slats, glovebox and manual gear lever.
	G.box(self,Vector3(0.1,0.83,-0.516),Vector3(0.48,0.16,0.07),bezel)
	G.box(self,Vector3(0.1,0.83,-0.472),Vector3(0.42,0.12,0.015),dark)
	G.box(self,Vector3(0.10,0.86,-0.46),Vector3(0.23,0.031,0.008),G.material(Color("5e643d"),null,0.35))
	radio_display = G.label(self,"FM   87.6",Vector3(0.1,0.86,-0.452),13,Color("b4ba7a"))
	radio_display.pixel_size = 0.0008
	for x in [-0.076,0.276]:
		var knob = G.cylinder(self,Vector3(x,0.82,-0.441),0.032,0.03,dark)
		knob.rotation.x = PI/2
		radio_knobs.append(knob)
		G.box(knob,Vector3(0,0.017,-0.019),Vector3(0.006,0.006,0.019),amber)
	for x in [-0.07,0.0,0.07,0.14,0.21]: G.box(self,Vector3(x,0.788,-0.446),Vector3(0.045,0.024,0.025),bezel)
	# Hit regions sit on the real radio face. The center of the view is the pointer.
	for entry in [["power",-0.076,0.825,0.053,0.049],["station",0.276,0.825,0.05,0.049],["quieter",-0.07,0.788,0.028,0.018],["louder",0.0,0.788,0.028,0.018],["preset0",0.07,0.788,0.028,0.018],["preset1",0.14,0.788,0.028,0.018],["preset2",0.21,0.788,0.028,0.018]]:
		radio_targets.append(entry)
	for entry in [["−",-0.07],["+",0.0],["1",0.07],["2",0.14],["3",0.21]]:
		G.label(self,entry[0],Vector3(entry[1],0.789,-0.430),16,Color("c3b990")).pixel_size=0.0007
	G.label(self,"VOL / PWR                         TUNE",Vector3(0.1,0.902,-0.449),12,Color("b5ad92")).pixel_size=0.00065
	G.box(self,Vector3(0.52,1.034,-0.56),Vector3(0.26,0.105,0.095),dark)
	clock_display=G.label(self,"15:00",Vector3(0.52,1.034,-0.505),30,Color("e1a76b"))
	clock_display.pixel_size=0.0012
	var digits=SystemFont.new()
	digits.font_names=PackedStringArray(["Consolas","Courier New"])
	clock_display.font=digits
	for center in [-0.02,0.29,0.86,-0.9]:
		G.box(self,Vector3(center,1.013,-0.532),Vector3(0.18,0.075,0.032),dark)
		for i in 6: G.box(self,Vector3(center-0.075+i*0.029,1.013,-0.51),Vector3(0.008,0.058,0.008),bezel)
	G.box(self,Vector3(0.64,0.80,-0.516),Vector3(0.48,0.26,0.019),dark)
	G.box(self,Vector3(0.64,0.88,-0.501),Vector3(0.10,0.025,0.012),bezel)
	G.box(self,Vector3(0,0.46,0.05),Vector3(0.25,0.20,0.72),dark)
	G.rod(self,Vector3(0,0.55,0),Vector3(0,0.79,-0.055),0.016,bezel)
	G.sphere(self,Vector3(0,0.79,-0.055),Vector3(0.065,0.065,0.065),dark)
	speed_label = G.label(self,"0",Vector3(-0.49,0.946,-0.447),22,Color("c0c387"))
	speed_label.pixel_size = 0.0009
	# Mirror glass and a small hanging rosary, as in the visual reference.
	G.rod(self,Vector3(0.1,1.95,-0.73),Vector3(0.1,1.78,-0.64),0.018,dark)
	G.box(self,Vector3(0.1,1.76,-0.61),Vector3(0.40,0.16,0.033),dark)
	var mirror_view = SubViewport.new()
	mirror_view.size = Vector2i(256,96)
	mirror_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	mirror_view.world_3d = get_viewport().world_3d
	add_child(mirror_view)
	mirror_camera = Camera3D.new()
	mirror_camera.fov = 74
	mirror_camera.near = 0.04
	mirror_camera.far = 65
	mirror_camera.cull_mask = 29
	mirror_view.add_child(mirror_camera)
	var glass = StandardMaterial3D.new()
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_texture = mirror_view.get_texture()
	glass.albedo_color = Color(0.65,0.73,0.65)
	glass.uv1_scale.x = -1
	var mirror_plane = QuadMesh.new()
	mirror_plane.size = Vector2(0.358,0.122)
	var surface = G.mesh(self,mirror_plane,Vector3(0.1,1.76,-0.586),glass)
	surface.layers = 2
	pendant = Node3D.new()
	pendant.position = Vector3(0.26,1.77,-0.6)
	add_child(pendant)
	for i in 11:
		G.sphere(pendant,Vector3(sin(float(i)*0.3)*0.026,-i*0.025,0),Vector3(0.018,0.023,0.018),dark)
	G.box(pendant,Vector3(0,-0.32,0),Vector3(0.018,0.095,0.012),dark)
	G.box(pendant,Vector3(0,-0.304,0),Vector3(0.062,0.018,0.012),dark)

func _build_people() -> void:
	for seat in 3:
		var n = Node3D.new()
		n.position = Vector3(EYES[seat].x,0,EYES[seat].z)
		add_child(n)
		people.append(n)
		var jacket = G.material([Color("27384b"),Color("572b27"),Color("292c29")][seat])
		var skin = G.material(Color("ae9272"))
		G.sphere(n,Vector3(0,1.03,0.02),Vector3(0.49,0.63,0.31),jacket)
		var limbs: Array = []
		for side in [-1,1]:
			limbs.append(G.cylinder(n,Vector3.ZERO,0.064,1.0,jacket))
			limbs.append(G.cylinder(n,Vector3.ZERO,0.048,1.0,jacket))
		arms.append(limbs)
		var pair: Array = []
		var fingers: Array = []
		for side in [-1,1]:
			var hand=Node3D.new()
			n.add_child(hand)
			G.box(hand,Vector3.ZERO,Vector3(0.085,0.055,0.12),skin)
			G.sphere(hand,Vector3(side*0.038,0,-0.016),Vector3(0.027,0.04,0.062),skin)
			var finger=G.box(hand,Vector3(-side*0.018,0,-0.086),Vector3(0.018,0.021,0.085),skin)
			finger.visible=false
			pair.append(hand)
			fingers.append(finger)
		hands.append(pair)
		point_fingers.append(fingers)
		for x in [-0.12,0.12]:
			G.rod(n,Vector3(x,0.68,0),Vector3(x,0.62,-0.47),0.105,G.material(Color("252a29")))
		var head = Node3D.new()
		head.position = Vector3(0,EYES[seat].y,0)
		n.add_child(head)
		heads.append(head)
		G.sphere(head,Vector3.ZERO,Vector3(0.30,0.36,0.30),skin)
		G.sphere(head,Vector3(0,0.07,0.026),Vector3(0.32,0.30,0.30),G.material(Color("1b1c18")))
		G.sphere(head,Vector3(0,-0.017,-0.15),Vector3(0.045,0.07,0.06),skin)
		var belt = G.material(Color("101510"))
		G.rod(n,Vector3(-0.22,1.25,0.02),Vector3(0.18,0.73,-0.16),0.022,belt)
		var prop = Node3D.new()
		prop.position = Vector3(0,0.96,-0.34)
		n.add_child(prop)
		remote_tools.append(prop)
		if seat == 1:
			_paper(prop,0.72)
			for x in [-0.33,0.33]: G.sphere(prop,Vector3(x,-0.22,0.025),Vector3(0.07,0.11,0.065),skin)
		if seat == 2:
			_camcorder(prop)
			for x in [-0.09,0.09]: G.sphere(prop,Vector3(x,-0.06,0),Vector3(0.055,0.075,0.095),skin)
		prop.visible = false
		_set_layers(head,4<<seat)
		_set_layers(prop,4<<seat)

func _paper(parent: Node3D, width: float) -> void:
	var mesh = SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h = width*0.91
	var verts = [Vector3(-width/2,-h/2,0),Vector3(0,-h/2,0.026),Vector3(width/2,-h/2,0),Vector3(-width/2,h/2,0),Vector3(0,h/2,0.026),Vector3(width/2,h/2,0)]
	var uvs = [Vector2(0,1),Vector2(0.5,1),Vector2(1,1),Vector2(0,0),Vector2(0.5,0),Vector2(1,0)]
	for i in [0,1,3,3,1,4,1,2,4,4,2,5]:
		mesh.set_uv(uvs[i])
		mesh.add_vertex(verts[i])
	mesh.generate_normals()
	if not map_material:
		map_material = ShaderMaterial.new()
		map_material.shader = load("res://shaders/map.gdshader")
		map_material.set_shader_parameter("paper",load("res://assets/sintra_map.png"))
	G.mesh(parent,mesh.commit(),Vector3.ZERO,map_material)

func _camcorder(parent: Node3D) -> void:
	var dark = G.material(Color("242b27"))
	G.box(parent,Vector3.ZERO,Vector3(0.15,0.13,0.28),dark)
	var lens = G.cylinder(parent,Vector3(0,0,-0.17),0.066,0.085,dark)
	lens.rotation.x = PI/2
	G.box(parent,Vector3(-0.13,0,0),Vector3(0.12,0.10,0.022),dark)
	G.box(parent,Vector3(-0.13,0,0.016),Vector3(0.10,0.076,0.005),G.material(Color("465f4e"),null,0.25))
	G.sphere(parent,Vector3(0.04,0.038,0.145),Vector3(0.012,0.012,0.012),G.material(Color("b82920"),null,1.0))

func _build_tools() -> void:
	map_prop = Node3D.new()
	camera.add_child(map_prop)
	_paper(map_prop,0.72)
	for x in [-0.33,0.33]: G.sphere(map_prop,Vector3(x,-0.22,0.02),Vector3(0.069,0.1,0.075),G.material(Color("a58e70")))
	cam_prop = Node3D.new()
	camera.add_child(cam_prop)
	_camcorder(cam_prop)
	_set_layers(map_prop,32)
	_set_layers(cam_prop,32)

func select_seat(seat: int) -> void:
	local_seat = seat
	look.position = EYES[seat]
	look.rotation = Vector3(-0.065,0,0)
	tool_blend = 0.0
	for i in 3: people[i].visible = true
	camera.cull_mask = 0xFFFFF & ~(4<<seat)
	map_prop.visible = false
	cam_prop.visible = seat == 2

func limit_look(tool_on: bool) -> void:
	var yaw_min = -3.02
	var yaw_max = 3.02
	var pitch_min = -0.85
	var pitch_max = 0.70
	if tool_on or tool_blend > 0.015:
		if local_seat == 1:
			yaw_min = -0.22
			yaw_max = 0.88
			pitch_min = -0.28
			pitch_max = 0.30
		elif local_seat == 2:
			yaw_min = -1.02
			yaw_max = 1.02
			pitch_min = -0.36
			pitch_max = 0.43
	look.rotation.y = clampf(look.rotation.y,yaw_min,yaw_max)
	look.rotation.x = clampf(look.rotation.x,pitch_min,pitch_max)

func update_remote(seat: int, pose: Vector3, delta: float, pointing: bool = false) -> void:
	var pitch = clampf(pose.x,-0.85,0.7)
	var yaw = clampf(pose.y,-3.02,3.02)
	var active = pose.z > 0.5
	if active and seat == 1:
		pitch = clampf(pitch,-0.28,0.30)
		yaw = clampf(yaw,-0.22,0.88)
	if active and seat == 2:
		pitch = clampf(pitch,-0.36,0.43)
		yaw = clampf(yaw,-1.02,1.02)
	heads[seat].rotation = Vector3(pitch,yaw,0)
	var prop: Node3D = remote_tools[seat]
	prop.visible = active and seat != 0
	prop.rotation = Vector3(pitch,yaw,0)
	var offset = Vector3(-0.06,-0.10,-0.65) if seat == 1 else Vector3(0,-0.02,-0.25)
	prop.position = Vector3(0,EYES[seat].y,0)+Basis.from_euler(prop.rotation)*offset
	gesture_blend[seat] = move_toward(gesture_blend[seat],1.0 if pointing and not active else 0.0,delta*6)
	for side_index in 2:
		var side = -1 if side_index==0 else 1
		var shoulder = Vector3(side*0.22,1.16,0)
		var hand = Vector3(side*0.22,0.82,-0.3)
		if seat == 0:
			hand = people[seat].to_local(wheel.to_global(Vector3(side*0.19,0, -0.072)))
		if active and seat != 0:
			var grip = Vector3(side*0.33,-0.22,0.025) if seat==1 else Vector3(side*0.09,-0.06,0)
			hand = prop.transform*grip
		var is_point = side == (-1 if yaw >= 0 else 1)
		var amount: float = gesture_blend[seat] if is_point else 0.0
		var direction = Basis.from_euler(Vector3(clampf(pitch,-0.45,0.40),yaw,0))*Vector3.FORWARD
		var target = Vector3(side*0.10,1.39,-0.04)+direction*0.52
		# Keep gestures above seat backs and inside the closed windows.
		target.x = clampf(target.x,-0.88-EYES[seat].x,0.88-EYES[seat].x)
		target.y = clampf(target.y,1.37,1.77)
		target.z = clampf(target.z,-0.53,0.16 if seat<2 else 0.22)
		hand = hand.lerp(target,amount)
		var palm: Node3D = hands[seat][side_index]
		palm.position=hand
		palm.rotation=Vector3(pitch,yaw,0) if amount>0.1 else Vector3(-0.7,0,side*0.2)
		palm.visible = not active or seat==0
		point_fingers[seat][side_index].visible=amount>0.5
		var elbow = shoulder.lerp(hand,0.52)+Vector3(side*0.035,-0.10,0.03)
		if amount>0.1 and direction.z>0:
			elbow.y=lerpf(elbow.y,1.39,amount)
			elbow.z=minf(elbow.z,0.06)
		_segment(arms[seat][side_index*2],shoulder,elbow)
		_segment(arms[seat][side_index*2+1],elbow,hand+(elbow-hand).normalized()*0.085)

func _segment(n: Node3D, a: Vector3, b: Vector3) -> void:
	var axis = (b-a).normalized()
	var helper = Vector3.RIGHT if absf(axis.dot(Vector3.UP))>0.98 else Vector3.UP
	var right = helper.cross(axis).normalized()
	n.transform = Transform3D(Basis(right,axis*(b-a).length(),right.cross(axis).normalized()),(a+b)*0.5)

func animate(delta: float, speed: float, steer: float, tool_on: bool, time: float) -> void:
	mirror_camera.global_transform = global_transform*Transform3D(Basis(Vector3.UP,PI),Vector3(0.1,1.69,-0.57))
	for i in wing_cameras.size():
		var side = -1 if i==0 else 1
		wing_cameras[i].global_transform=global_transform*Transform3D(Basis(Vector3.UP,PI+side*0.24),Vector3(side*1.32,1.24,-0.57))
	limit_look(tool_on)
	tool_blend = move_toward(tool_blend,1.0 if tool_on else 0.0,delta*3.0)
	var blend = smoothstep(0.0,1.0,tool_blend)
	# Lean into the aisle when turning to look at the rear passenger.
	var rear_lean = smoothstep(0.85,2.15,absf(look.rotation.y)) if not tool_on and tool_blend < 0.01 else 0.0
	var lean = Vector3(0.29 if local_seat==0 else -0.29,0.10,-0.03)*rear_lean if local_seat<2 else Vector3.ZERO
	look.position = EYES[local_seat]+lean
	map_prop.visible = local_seat == 1 and tool_blend > 0.001
	map_prop.position = Vector3(-0.06,lerpf(-0.48,-0.10,blend),-0.65)
	map_prop.rotation.x = lerpf(-0.90,0.0,blend)
	cam_prop.visible = local_seat == 2 and blend < 0.86
	cam_prop.position = Vector3(lerpf(0.22,0.0,blend),lerpf(-0.43,-0.02,blend),-0.25)
	cam_prop.rotation.x = lerpf(-0.4,0.0,blend)
	var optical = Vector3(0,0,-0.42)*blend if local_seat==2 else Vector3.ZERO
	camera.position = optical+Vector3(0,sin(time*15)*minf(absf(speed)*0.00045,0.006)*sway_amount,0)
	var target_fov = 57.0 if local_seat==2 and tool_on else base_fov
	if zooming: target_fov *= 0.76
	camera.fov = lerpf(camera.fov,target_fov,1.0-exp(-delta*9))
	camera.rotation.z = lerpf(camera.rotation.z,-steer*speed*0.0007*sway_amount,1.0-exp(-delta*3))
	wheel.basis = Basis(Vector3.RIGHT,deg_to_rad(68))*Basis(Vector3.UP,steer*1.65)
	var remaining = maxi(0,ceili(900.0-time))
	clock_display.text = "%02d:%02d" % [remaining/60,remaining%60]
	clock_display.modulate = Color("e17858") if remaining<=60 else Color("e1a76b")
	pendant.rotation.z = sin(time*1.7)*0.02+steer*speed*0.008
	speed_label.text = str(roundi(absf(speed)*3.6))

func _set_layers(root: Node, mask: int) -> void:
	if root is VisualInstance3D: root.layers=mask
	for child in root.get_children(): _set_layers(child,mask)

func _wing_mirror(housing: Node3D, _side: int) -> void:
	var viewport=SubViewport.new()
	viewport.size=Vector2i(192,128)
	viewport.world_3d=get_viewport().world_3d
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var lens=Camera3D.new()
	lens.fov=66
	lens.near=0.04
	lens.far=90
	lens.cull_mask=29
	viewport.add_child(lens)
	wing_cameras.append(lens)
	var glass=StandardMaterial3D.new()
	glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.albedo_texture=viewport.get_texture()
	glass.albedo_color=Color(0.71,0.78,0.72)
	glass.uv1_scale=Vector3(-1,1,1)
	var shape=QuadMesh.new()
	shape.size=Vector2(0.263,0.158)
	G.mesh(housing,shape,Vector3(0,0,0.065),glass).layers=2

func radio_hit() -> String:
	if local_seat!=1 or tool_blend>0.02: return ""
	var origin=to_local(camera.global_position)
	var direction=global_basis.inverse()*(-camera.global_basis.z)
	if direction.z>=-0.05: return ""
	var t=(-0.423-origin.z)/direction.z
	if t<0 or t>1.8: return ""
	var hit=origin+direction*t
	# Presets take priority at the bottom edge of the knobs.
	for i in range(radio_targets.size()-1,-1,-1):
		var r=radio_targets[i]
		if absf(hit.x-r[1])<r[3] and absf(hit.y-r[2])<r[4]: return r[0]
	return ""
