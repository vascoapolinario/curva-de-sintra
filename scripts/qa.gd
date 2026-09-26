extends Node
var g: Node
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("QA: "+message)

func run(game: Node, mode: String) -> void:
	g = game
	if mode.begins_with("effects_"):
		await effects_network(mode)
		return
	if mode.begins_with("nightnet"):
		await nightnet(mode)
		return
	if mode.begins_with("host") or mode.begins_with("join"):
		await network(mode)
		return
	g._start_solo()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if mode=="route":
		route()
		return
	if mode=="routes":
		routes_test()
		return
	if mode=="route_screenshots":
		await route_screenshots()
		return
	if mode=="smoke":
		smoke()
		return
	if mode=="night":
		night()
		return
	if mode=="effects":
		await effects_test()
		return
	await screenshots()

func smoke() -> void:
	var start = g.car.position
	g.controls = Vector3(1,0,0)
	for i in 120: g._simulate(1.0/60)
	check(g.car.position.distance_to(start)>5,"Driving")
	g.controls = Vector3(0,0,1)
	for i in 120: g._simulate(1.0/60)
	check(absf(g.speed)<0.01,"Braking")
	for p in g.forest.sign_positions: check(g.forest.distance_to_road(p)>=5.8,"Roadside sign clearance")
	check(g.forest.region.minimum_distance/11.5 >= 600,"Minimum route duration")
	var a = g.forest.map_uv(g.car.position)
	var b = g.forest.map_uv(g.forest.destination)
	check(a.distance_to(b)>0.1,"Map position transform")
	g._set_seat(1)
	g.tool_on = true
	g.car.look.rotation = Vector3(0.8,-3,0)
	g.car.animate(1,0,0,true,0)
	check(g.car.look.rotation.y >= -0.221,"Navigator tool turn limit")
	check(g.car.map_prop.visible,"Physical map visible")
	# Sample all extreme held-map poses and verify the actual paper vertices stay inside the cabin.
	for pitch in [-0.28,0.0,0.30]:
		for yaw in [-0.22,0.0,0.88]:
			g.car.look.rotation=Vector3(pitch,yaw,0)
			g.car.animate(1,0,0,true,0)
			for x in [-0.36,0.36]:
				for y in [-0.3276,0.3276]:
					var p: Vector3 = g.car.to_local(g.car.map_prop.to_global(Vector3(x,y,0)))
					check(absf(p.x)<0.98 and p.y<1.94 and p.y>0.72 and p.z<0.5,"Held-map bounds: "+str(p))
	g.request_radio(1,0.65,true)
	check(g.radio.station==1 and is_equal_approx(g.radio.volume,0.65),"Navigator radio control")
	g._set_seat(0)
	g.request_radio(2,1.0,true)
	check(g.radio.station==1,"Driver radio access rejected")
	g._set_seat(2)
	g.tool_on=true
	g.car.animate(1,0,0,true,0)
	g._process(0.016)
	check(not g.car.cam_prop.visible and g.car.camera.position.z < -0.4,"Optical camcorder viewpoint")
	check(g.forest.ghost.visible,"Camcorder apparition")
	g.car.update_remote(1,Vector3(0,0,1),1)
	check(g.car.remote_tools[1].visible,"Remote navigator map")
	g.car.update_remote(2,Vector3(0,0,1),1)
	check(g.car.remote_tools[2].visible,"Remote held camcorder")
	g.prefs.bind_key("map",KEY_N)
	check(InputMap.action_get_events("map")[0].physical_keycode==KEY_N,"Key rebinding")
	g.prefs.bind_key("map",KEY_M)
	g.car.position=g.forest.destination
	g._simulate(0.016)
	check(g.won,"Arrival")
	print("QA_SMOKE failures=",failures," signs=",g.forest.sign_positions.size()," minimum_minutes=",g.forest.region.minimum_distance/11.5/60)
	get_tree().quit(0 if failures.is_empty() else 1)

func effects_test() -> void:
	check(InputMap.action_get_events("headlights")[0].physical_keycode==KEY_L,"L binding")
	check(InputMap.action_get_events("horn")[0].physical_keycode==KEY_H,"H binding")
	g.effects.request_lights()
	check(not g.effects.headlights,"Lights toggle off")
	for light in g.effects.lights: check(not light.visible,"Both beams off")
	Input.action_press("horn")
	g.effects._process(0.02)
	check(g.effects.honking,"Horn held")
	g.ui.show_pause()
	g.effects._process(0.02)
	check(not g.effects.honking,"Menu releases horn")
	Input.action_release("horn")
	g._resume()
	g._set_seat(1)
	g.effects.request_lights()
	g.effects.request_horn(true)
	check(not g.effects.headlights and not g.effects.honking,"Passenger control rejected")
	g._set_seat(0)
	g.effects.request_lights()
	check(g.effects.headlights,"Lights toggle on")
	g.effects.next_cue=0
	g.effects._process(0.02)
	check(g.effects.cue_count>0 and g.effects.hush>0,"Environmental cue and hush")
	g.effects.request_horn(true)
	g._lose()
	check(not g.effects.honking,"Outcome stops horn")
	g._begin(0)
	check(g.effects.headlights and not g.effects.honking,"New journey reset")
	print("QA_EFFECTS failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func effects_network(mode: String) -> void:
	if mode=="effects_host":
		g.chosen_seat=1
		g._host()
		g.effects.next_cue=100
		await get_tree().create_timer(4).timeout
		check(not g.effects.headlights and g.effects.honking,"Remote driver controls replicated")
		g.effects.next_cue=0
		await get_tree().create_timer(2).timeout
		check(not g.effects.headlights and g.effects.honking,"Passenger RPC cannot control lights or horn")
		await get_tree().create_timer(3).timeout
		check(not g.effects.honking,"Driver disconnect releases horn")
	else:
		g.chosen_seat=0 if mode=="effects_driver" else 2
		g.ui.show_friends()
		g.address.text="127.0.0.1"
		g._join()
		await get_tree().create_timer(1.2).timeout
		if mode=="effects_driver":
			g.effects.request_lights()
			Input.action_press("horn")
			await get_tree().create_timer(5).timeout
			check(not g.effects.headlights and g.effects.honking,"Driver sees authoritative state")
			g.multiplayer.multiplayer_peer.close()
		else:
			check(not g.effects.headlights and g.effects.honking,"Late join inherits car controls")
			g.effects._driver_request.rpc_id(1,"lights",true)
			g.effects._driver_request.rpc_id(1,"horn",false)
			await get_tree().create_timer(1).timeout
			check(not g.effects.headlights and g.effects.honking,"Unauthorized requests rejected")
			await get_tree().create_timer(3).timeout
			check(g.effects.cue_count>0,"Shared environmental audio event")
			check(not g.effects.honking,"Passenger sees horn release on disconnect")
	print("QA_EFFECTS_NET ",mode," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func driving_points(indices: Array) -> PackedVector3Array:
	var points = PackedVector3Array()
	for index in indices:
		var road: PackedVector3Array=g.forest.roads[int(index)]
		for i in road.size():
			var point=road[i]
			for hazard in g.forest.region.obstacles:
				if int(hazard.road)!=int(index): continue
				var at: Vector3=road[int(hazard.sample)]
				var distance=point.distance_to(at)
				if distance<40:
					var right=Basis(Vector3.UP,hazard.yaw).x
					point-=right*hazard.side*2.05*smoothstep(40,12,distance)
			points.append(point)
	return points

func drive_route(indices: Array) -> float:
	g._begin(0)
	var points=driving_points(indices)
	var target = 3
	var ticks = 0
	var distance = 0.0
	for step in 180000:
		while target<points.size()-1 and g.car.position.distance_to(points[target])<10: target+=1
		var direction=(points[target]-g.car.position).normalized()
		var angle=(-g.car.basis.z).signed_angle_to(direction,Vector3.UP)
		var desired=clampf(11.2/(1+absf(angle)*1.5),4,11.2)
		g.controls=Vector3(1 if g.speed<desired else 0,clampf(angle*1.7,-1,1),0)
		var old: Vector3 = g.car.position
		g._simulate(1.0/60)
		distance+=old.distance_to(g.car.position)
		ticks=step+1
		if g.won: break
	check(g.won,"Complete extended route")
	check(float(ticks)/60>=600,"Actual drive lasts ten minutes")
	check(float(ticks)/60<900,"Route can be finished before ghost deadline")
	print("QA_ROUTE roads=",indices," won=",g.won," minutes=",float(ticks)/3600," distance=",distance," waypoint=",target,"/",points.size())
	return float(ticks)/3600

func route() -> void:
	drive_route(g.forest.main_route)
	get_tree().quit(0 if failures.is_empty() else 1)

func routes_test() -> void:
	# Every hazard blocks its occupied lane but leaves a full car-width passage,
	# including while reversing. Landmarks and map symbols share one position.
	for hazard in g.forest.region.obstacles:
		var road: PackedVector3Array=g.forest.roads[int(hazard.road)]
		var at: Vector3=road[int(hazard.sample)]
		var right=Basis(Vector3.UP,hazard.yaw).x
		check(g.forest.blocked_by_obstacle(at+right*hazard.side*2.75,hazard.yaw),"Solid "+hazard.kind)
		for sign in [-1,1]:
			check(not g.forest.blocked_by_obstacle(at-right*hazard.side*2.05,hazard.yaw+(PI if sign<0 else 0)),"Passable "+hazard.kind)
	check(g.forest.landmark_positions.size()==5,"Five mapped landmarks")
	g._set_seat(1)
	for volume in [0.0,0.5,1.0]:
		for station in 3:
			g.request_radio(station,volume,true)
			g.radio._process(1)
			for knob in g.car.radio_knobs:
				check(knob.basis.y.distance_to(Vector3.BACK)<0.001,"Radio shaft remains fixed")
	drive_route([0,1,2,10,4,5,12,7,8])
	drive_route([0,1,2,3,4,5,6,7,8])
	drive_route([0,9,2,3,4,5,12,13,8])
	print("QA_ROUTES failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func route_screenshots() -> void:
	g._set_seat(1)
	g.tool_on=true
	await get_tree().create_timer(0.6).timeout
	await capture("map")
	var focus=InputEventMouseButton.new()
	focus.button_index=MOUSE_BUTTON_RIGHT
	focus.pressed=true
	Input.parse_input_event(focus)
	await capture("map_focus")
	focus=InputEventMouseButton.new()
	focus.button_index=MOUSE_BUTTON_RIGHT
	focus.pressed=false
	Input.parse_input_event(focus)
	g.tool_on=false
	g._set_seat(0)
	for feature in g.forest.region.landmarks:
		var road: PackedVector3Array=g.forest.roads[int(feature.road)]
		var at: int=maxi(1,int(feature.sample)-18)
		g.car.position=road[at]
		var direction=(road[at+1]-road[at]).normalized()
		g.car.rotation.y=atan2(-direction.x,-direction.z)
		g.car.look.look_at(Vector3(feature.position[0],1.4,feature.position[1]))
		await capture(feature.kind)
	for feature in g.forest.region.obstacles.slice(0,2):
		var road: PackedVector3Array=g.forest.roads[int(feature.road)]
		var at: int=maxi(1,int(feature.sample)-12)
		g.car.position=road[at]
		var direction=(road[at+1]-road[at]).normalized()
		g.car.rotation.y=atan2(-direction.x,-direction.z)
		g.car.look.rotation=Vector3.ZERO
		await capture(feature.kind)
	var approach: PackedVector3Array=g.forest.roads[6]
	g.car.position=approach[-12]
	var direction=(approach[-1]-g.car.position).normalized()
	g.car.rotation.y=atan2(-direction.x,-direction.z)
	g.car.look.rotation=Vector3.ZERO
	await capture("junction")
	g._set_seat(1)
	g.car.look.look_at(g.car.to_global(Vector3(0.1,0.83,-0.43)))
	for station in 3:
		g.request_radio(station,float(station)/2,true)
		await capture("radio_%d"%station)
	get_tree().quit()

func network(mode: String) -> void:
	if mode.begins_with("host"):
		g.chosen_seat=1 if mode=="host_remote" else 0
		g._host()
		var start_z: float = g.car.position.z
		if g.local_seat==1: g.request_radio(1,0.65,true)
		await get_tree().create_timer(8).timeout
		check(g.players.size()==3,"Three seats occupied")
		check(g.car.position.z<start_z-8 if mode=="host_remote" else is_equal_approx(g.car.position.z,start_z),"Driver authority")
		check(g.voice.outputs.size()>0,"Voice relay to host")
		check(g.radio.station==1 and is_equal_approx(g.radio.volume,0.65),"Radio authority and synchronization")
		check(g.poses[2].z>0.5,"Camera pose replication")
		print("QA_HOST ",mode," players=",g.players.size()," car=",g.car.position," radio=",g.radio.station," failures=",failures)
		g.car.position=g.forest.destination
		g._simulate(0.016)
		await get_tree().create_timer(4).timeout
	else:
		g.chosen_seat=int(mode.trim_prefix("join"))
		g.ui.show_friends()
		g.address.text="127.0.0.1"
		g._join()
		await get_tree().create_timer(3).timeout
		g.tool_on = g.local_seat>0
		if g.local_seat==1: g.request_radio(1,0.65,true)
		if g.local_seat==2:
			g._radio_request.rpc_id(1,2,1.0,true)
			var packet=PackedByteArray()
			packet.resize(640)
			for i in 320: packet.encode_s16(i*2,int(sin(i*0.17)*3000))
			for i in 10:
				g.voice._submit.rpc_id(1,packet)
				await get_tree().create_timer(0.02).timeout
		await get_tree().create_timer(6).timeout
		check(g.running and g.local_seat==g.chosen_seat and g.players.size()==3,"Client seat and roster")
		check(g.radio.station==1,"Shared radio")
		check(g.won,"Shared arrival")
		print("QA_CLIENT seat=",g.local_seat," radio=",g.radio.station," failures=",failures)
		await get_tree().create_timer(1).timeout
	get_tree().quit(0 if failures.is_empty() else 1)

func capture(name: String) -> void:
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var directory=OS.get_environment("SINTRA_QA_OUTPUT")
	if directory.is_empty(): directory="user://"
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

func nightnet(mode: String) -> void:
	if mode=="nightnet_host":
		g._host()
		await get_tree().create_timer(5).timeout
		check(g.players.size()==2,"Early passenger joined")
		check(g.gestures[1],"Remote pointing replicated")
		g.elapsed=899.7
		await get_tree().create_timer(1).timeout
		check(g.lost and not g.won,"Host deadline")
		await get_tree().create_timer(5).timeout
		check(2 in g.players.values(),"Late passenger joined expired journey")
	else:
		g.chosen_seat=2 if mode=="nightnet_late" else 1
		g.ui.show_friends()
		g.address.text="127.0.0.1"
		g._join()
		await get_tree().create_timer(2).timeout
		if mode=="nightnet_late":
			check(g.lost and g.elapsed==900,"Late join inherits failure and clock")
		else:
			check(g.running and g.elapsed>0,"Joined synchronized clock")
			g.pointing=true
			await get_tree().create_timer(4).timeout
			check(g.lost and g.elapsed==900 and not g.won,"Client receives same loss")
		await get_tree().create_timer(3).timeout
	print("QA_NIGHTNET ",mode," failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func screenshots() -> void:
	g.ui.show_title()
	await capture("title")
	g.ui.show_settings()
	await capture("settings")
	g._resume()
	await capture("driver")
	g.poses[2]=Vector3(0,0,1)
	g.car.look.rotation=Vector3(0.02,-2.95,0)
	await capture("look_back")
	g.poses[1]=Vector3(0,0.1,1)
	g.car.look.rotation=Vector3(-0.08,-1.55,0)
	await capture("navigator_holding_map")
	g._set_seat(1)
	g.tool_on=true
	await get_tree().create_timer(0.5).timeout
	await capture("map")
	g.tool_on=false
	g.car.look.look_at(g.car.to_global(Vector3(0.1,0.83,-0.43)))
	g.car.tool_blend=0
	g.car.zooming=true
	var zoom=InputEventMouseButton.new()
	zoom.button_index=MOUSE_BUTTON_RIGHT
	zoom.pressed=true
	Input.parse_input_event(zoom)
	await capture("radio")
	zoom=InputEventMouseButton.new()
	zoom.button_index=MOUSE_BUTTON_RIGHT
	zoom.pressed=false
	Input.parse_input_event(zoom)
	g._set_seat(2)
	g.tool_on=true
	await get_tree().create_timer(0.5).timeout
	await capture("viewfinder")
	g.tool_on=false
	g.poses=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	g._set_seat(0)
	g.car.look.look_at(g.car.to_global(Vector3(-1.17,1.22,-0.77)))
	await capture("left_mirror")
	g.car.look.look_at(g.car.to_global(Vector3(1.17,1.22,-0.77)))
	await capture("right_mirror")
	for i in 2:
		g.car.wing_cameras[i].get_viewport().get_texture().get_image().save_png(OS.get_environment("SINTRA_QA_OUTPUT").path_join("mirror_texture_%d.png"%i))
	g.pointing=true
	await capture("pointing")
	g.pointing=false
	g.car.position=g.forest.destination+g.forest.shelter.basis*Vector3(0,0,18)
	g.car.rotation.y=g.forest.shelter.rotation.y
	g.car.look.rotation=Vector3(0,0,0)
	await capture("refuge")
	g._lose()
	await capture("failure")
	print("QA_SCREENSHOTS fps=",Engine.get_frames_per_second())
	get_tree().quit()

func night() -> void:
	for p in g.forest.roadside_positions:
		check(g.forest.distance_to_road(p)>=4.9,"Vegetation clearance at junction")
	check(g.car.wing_cameras.size()==2,"Both wing mirrors have live views")
	g.car.animate(1,5,0.8,false,0)
	check(g.car.wheel.basis != Basis(Vector3.RIGHT,deg_to_rad(68)),"Wheel rotates about column")
	g.car.update_remote(0,Vector3.ZERO,1)
	for i in 2:
		var grip=g.car.wheel.to_global(Vector3((-1 if i==0 else 1)*0.19,0,-0.072))
		check(g.car.hands[0][i].global_position.distance_to(grip)<0.01,"Driver grip tracks wheel")
	check(g.car.people[0].visible,"Driver body visible in first person")
	check((g.car.camera.cull_mask & 4)==0,"Local head excluded from first person")
	check((g.car.mirror_camera.cull_mask & 4)!=0,"Driver head visible in mirrors")
	g.car.zooming=true
	g.car.animate(1,0,0,false,0)
	check(g.car.camera.fov<g.car.base_fov-10,"Focus zoom")
	g.car.zooming=false
	g._set_seat(1)
	for r in g.car.radio_targets:
		g.car.look.look_at(g.car.to_global(Vector3(r[1],r[2],-0.423)))
		g.car.animate(1,0,0,false,0)
		check(g.car.radio_hit()==r[0],"Radio hit "+r[0]+" got "+g.car.radio_hit())
	g._use_radio("preset2")
	check(g.radio.station==2,"Clickable preset")
	var old_volume=g.radio.volume
	g._use_radio("quieter")
	check(g.radio.volume<old_volume,"Clickable volume")
	g._set_seat(0)
	check(not g._use_radio("preset0"),"Only navigator operates radio")
	for seat in 3:
		for yaw in [-2.9,-1.5,0.0,1.5,2.9]:
			g.car.update_remote(seat,Vector3(0,yaw,0),1,true)
			var hand=g.car.hands[seat][0 if yaw>=0 else 1]
			var p=g.car.to_local(hand.global_position)
			check(absf(p.x)<=0.89 and p.y<1.8,"Point stays inside cabin")
		g.car.update_remote(seat,Vector3(0,0,1),1,true)
		check(g.car.gesture_blend[seat]==0,"Equipment suppresses pointing")
	g._begin(0)
	g.elapsed=898
	g.ui.show_pause()
	g._physics_process(1)
	check(g.elapsed==898,"Solo pause freezes clock")
	g._resume()
	g._physics_process(1)
	check(g.elapsed==899 and not g.lost,"Countdown before deadline")
	g._physics_process(1.1)
	check(g.lost and not g.won and g.elapsed==900,"Deadline loses to ghost")
	g.car.position=g.forest.destination
	g._simulate(0.1)
	check(not g.won,"Loss cannot become a win")
	g._begin(0)
	check(not g.lost and g.elapsed==0,"New journey resets clock")
	g.car.position=g.forest.destination
	g._simulate(0.1)
	check(g.won and not g.lost,"Timely arrival wins")
	print("QA_NIGHT failures=",failures," verge_instances=",g.forest.roadside_positions.size())
	get_tree().quit(0 if failures.is_empty() else 1)
