extends Node
var g: Node
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("QA: "+message)

func run(game: Node, mode: String) -> void:
	g = game
	g._start_game()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if mode=="driving":
		driving_test()
		return
	if mode=="instruments_screenshots":
		await instruments_screenshots()
		return
	if mode=="display":
		await display_test()
		return
	if mode=="barriers":
		barriers_test()
		return
	if mode=="barrier_screenshots":
		await barrier_screenshots()
		return
	if mode=="roles":
		roles_test()
		return
	if mode=="roles_screenshots":
		await roles_screenshots()
		return
	if mode=="woodland":
		woodland_test()
		return
	if mode=="woodland_screenshots":
		await woodland_screenshots()
		return
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
	for i in 180: g._simulate(1.0/60)
	check(g.car.position.distance_to(start)>8,"Smooth acceleration moves the car")
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
	check(not g.forest.ghost.visible,"No standing forest apparition")
	g.car.update_occupant(1,Vector3(0,0,1),1)
	check(g.car.occupant_tools[1].visible,"Navigator held map")
	g.car.update_occupant(2,Vector3(0,0,1),1)
	check(g.car.occupant_tools[2].visible,"Rear occupant held camcorder")
	g.prefs.bind_key("accelerate",KEY_T)
	check(InputMap.action_get_events("accelerate")[0].physical_keycode==KEY_T,"Key rebinding")
	g.prefs.bind_key("accelerate",KEY_W)
	g.car.position=g.forest.destination
	g._simulate(0.016)
	check(g.won,"Arrival")
	print("QA_SMOKE failures=",failures," signs=",g.forest.sign_positions.size()," minimum_minutes=",g.forest.region.minimum_distance/11.5/60)
	get_tree().quit(0 if failures.is_empty() else 1)

func press_key(code: int) -> void:
	var event=InputEventKey.new()
	event.physical_keycode=code
	event.keycode=code
	event.pressed=true
	g._unhandled_input(event)

func mouse_click(pressed: bool=true) -> void:
	var event=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.pressed=pressed
	g._unhandled_input(event)

func aim(at: Vector3) -> void:
	g.car.look.look_at(g.car.to_global(at))
	g.car.animate(1,0,0,g.tool_on,0)
	g.interactions.animate(1)

func roles_test() -> void:
	check(not g.has_method("_host") and not g.has_method("_join"),"No connection entry points")
	for action in ["horn","headlights","map","camera","interior_light","instrument_light","brake","radio_panel","talk"]:
		check(not InputMap.has_action(action) and not g.prefs.bindings.has(action),"Removed binding "+action)
	for code in [KEY_H,KEY_L,KEY_I,KEY_O,KEY_M,KEY_C,KEY_R]: press_key(code)
	check(g.effects.headlights and not g.effects.honking and g.cabin_lights.front_mode==0,"Old keys do nothing")
	aim(g.car.to_local(g.interactions.headlight_button.global_position))
	check(g.interactions.hit()=="headlights","Reachable wheel button")
	mouse_click()
	check(not g.effects.headlights,"Click switches headlights off")
	mouse_click(false)
	mouse_click()
	check(g.effects.headlights,"Click switches headlights on")
	mouse_click(false)
	for turn in [-1.0,0.0,1.0]:
		g.car.animate(1,0,turn,false,0)
		g.car.look.look_at(g.interactions.headlight_button.global_position)
		g.car.limit_look(false)
		check(g.interactions.hit()=="headlights","Headlight button follows wheel "+str(turn))
		g.car.look.look_at(g.car.horn_pad.global_position)
		check(g.interactions.hit()=="horn","Horn target follows wheel "+str(turn))
		mouse_click()
		g.effects._process(0.01)
		check(g.effects.honking and not g.pointing,"Wheel press honks without pointing")
		mouse_click(false)
		check(not g.effects.honking,"Mouse release stops horn")
	for seat in 3:
		g._set_seat(seat)
		for control in g.cabin_lights.targets:
			var allowed=(seat==2 if control=="rear_light" else seat<2)
			check(g.cabin_lights.use(control)==allowed,"Lamp permission "+control+str(seat))
			if allowed:
				aim(g.cabin_lights.targets[control])
				check(g.cabin_lights.hit()==control,"Reachable lamp "+control+str(seat))
				var state=[g.cabin_lights.front_mode,g.cabin_lights.rear_on]
				mouse_click()
				mouse_click(false)
				check(state!=[g.cabin_lights.front_mode,g.cabin_lights.rear_on],"Click changes lamp")
		check(g.cabin_lights.front_mode in [0,1],"Only warm on/off")
		check(g.car.instruments.face_material.albedo_color.get_luminance()<0.10,"Cabin lamps do not whiten dial faces")
	g._begin(0)
	press_key(KEY_2)
	check(g.local_seat==1,"2 selects navigator")
	press_key(KEY_M)
	check(not g.tool_on,"M cannot pick up map")
	aim(g.interactions.MAP_DOCK)
	check(g.interactions.hit()=="map_pickup" and g.interactions.map_dock.visible,"Folded map reachable on dashboard")
	mouse_click()
	mouse_click(false)
	g._process(1)
	check(g.tool_on and not g.interactions.map_dock.visible and g.car.map_prop.visible,"Click picks up map without duplicate")
	press_key(KEY_1)
	g._process(1)
	check(g.local_seat==0 and g.poses[1].z==1 and not g.interactions.map_dock.visible,"Held map remains with navigator")
	press_key(KEY_2)
	check(g.tool_on,"Returning to navigator preserves held item")
	g._process(1)
	mouse_click()
	mouse_click(false)
	g._process(1)
	check(not g.tool_on and g.interactions.map_dock.visible and not g.car.map_prop.visible,"Second click folds map onto dashboard")
	press_key(KEY_3)
	check(g.local_seat==2,"3 selects camera")
	press_key(KEY_C)
	check(not g.tool_on,"C cannot pick up camera")
	aim(g.interactions.CAMERA_DOCK)
	check(g.interactions.hit()=="camera_pickup" and g.interactions.camera_dock.visible,"Rear seat camera is reachable")
	mouse_click()
	mouse_click(false)
	g._process(1)
	check(g.tool_on and g.cam_hud.visible and not g.interactions.camera_dock.visible,"Click enters camera view")
	mouse_click()
	mouse_click(false)
	g._process(1)
	check(not g.tool_on and g.interactions.camera_dock.visible and not g.car.cam_prop.visible,"Click returns camera to seat")
	g.ui.show_pause()
	g.ui._process(4)
	g._resume()
	g._begin(0)
	g._set_seat(1)
	g.tool_on=false
	g.car.look.look_at(g.car.to_global(Vector3(-0.076,0.825,-0.423)))
	g.car.animate(1,0,0,false,0)
	g.request_radio(0,0.4,true)
	var mouse=InputEventMouseButton.new()
	mouse.button_index=MOUSE_BUTTON_LEFT
	mouse.pressed=true
	g._unhandled_input(mouse)
	check(g.radio_drag,"Volume knob drag capture")
	var motion=InputEventMouseMotion.new()
	motion.relative=Vector2(25,0)
	g._unhandled_input(motion)
	check(g.radio.volume>0.4,"Drag right increases volume")
	motion.relative=Vector2(-50,0)
	g._unhandled_input(motion)
	check(g.radio.volume<0.4,"Drag left decreases volume")
	mouse.pressed=false
	g._unhandled_input(mouse)
	check(g.radio.power and not g.radio_drag,"Drag does not toggle power")
	g.request_radio(0,0.45,true)
	g.radio._process(1)
	var before=g.car.radio_knobs[0].basis*Vector3(0,0,-1)
	g.request_radio(0,0.55,true)
	g.radio._process(1)
	var after=g.car.radio_knobs[0].basis*Vector3(0,0,-1)
	check(before.signed_angle_to(after,Vector3.BACK)<0,"Volume increases clockwise")
	check(g.radio.tuner.stream.get_length()<0.3,"Short selector sound")
	g._begin(0)
	check(g.cabin_lights.front_mode==0 and not g.cabin_lights.rear_on,"New journey light reset")
	print("QA_ROLES failures=",failures)
	get_tree().quit(0 if failures.is_empty() else 1)

func roles_screenshots() -> void:
	g._begin(0)
	await capture("driver_controls")
	aim(g.car.to_local(g.interactions.headlight_button.global_position))
	await capture("wheel_button")
	aim(g.car.to_local(g.car.horn_pad.global_position))
	await capture("horn_pad")
	aim(g.cabin_lights.targets.front_light)
	await capture("roof_off")
	mouse_click()
	mouse_click(false)
	await capture("roof_on")
	g._set_seat(1)
	aim(g.interactions.MAP_DOCK)
	await capture("folded_map")
	mouse_click()
	mouse_click(false)
	await capture("map_held")
	mouse_click()
	mouse_click(false)
	await capture("map_returned")
	g._set_seat(2)
	g.cabin_lights.use("rear_light")
	aim(g.interactions.CAMERA_DOCK)
	await capture("camera_on_seat")
	mouse_click()
	mouse_click(false)
	await capture("camera_view")
	mouse_click()
	mouse_click(false)
	aim(g.cabin_lights.targets.rear_light)
	await capture("rear_lamp")
	g.ui.show_settings()
	await capture("settings")
	get_tree().quit()

func woodland_test() -> void:
	var woods=g.forest.woodland
	check(woods.zones.size()==9,"Quiet and dark regions")
	check(woods.fires.size()==2 and woods.sightings.size()==4,"Sparse roadside encounters")
	check(woods.broadleaf_count>500 and woods.dead_count>200 and woods.shrub_count>1000,"Mixed species and shrubs")
	for at in woods.sightings: check(g.forest.distance_to_road(at)>16,"Sightings clear of all roads")
	for zone in woods.zones:
		woods.update_mood(zone.center,150,100)
		check(woods.fog>=0.008 and woods.fog<0.035,"Fog stays subtle")
		check(g.forest.environment.ambient_light_energy<0.07 if zone.dark else g.forest.environment.ambient_light_energy>0.10,"Dark / open contrast")
	var at=woods.zones[4].center
	var min_fog=1.0
	var max_fog=0.0
	for i in 180:
		woods.update_mood(at,i*3.0,100)
		min_fog=minf(min_fog,woods.fog)
		max_fog=maxf(max_fog,woods.fog)
	check(max_fog-min_fog>0.008,"Mist comes and goes")
	for p in g.forest.roadside_positions: check(g.forest.distance_to_road(p)>=4.9,"New growth leaves roads clear")
	g._begin(0)
	g.ui.show_pause()
	var frozen_fog=woods.fog
	g._process(1)
	check(is_equal_approx(frozen_fog,woods.fog),"Solo pause holds atmosphere")
	print("QA_WOODLAND failures=",failures," broadleaf=",woods.broadleaf_count," dead=",woods.dead_count," shrubs=",woods.shrub_count," sightings=",woods.sightings.size()," fog_range=",min_fog,"..",max_fog)
	get_tree().quit(0 if failures.is_empty() else 1)

func woodland_screenshots() -> void:
	var woods=g.forest.woodland
	for which in [0,2,4,5]:
		var zone=woods.zones[which]
		var road: PackedVector3Array=g.forest.roads[zone.road]
		g.car.position=road[zone.sample]
		var direction=(road[zone.sample+1]-g.car.position).normalized()
		g.car.rotation.y=atan2(-direction.x,-direction.z)
		g.car.look.rotation=Vector3.ZERO
		g.elapsed=210
		woods.update_mood(g.car.position,g.elapsed,100)
		await capture("area_%d"%which)
	for i in woods.sightings.size():
		var spot: Vector3=woods.sightings[i]
		var encounter=woods.encounters[i]
		var road: PackedVector3Array=g.forest.roads[encounter.road]
		var at: int=maxi(1,encounter.sample-15)
		g.car.position=road[at]
		var direction=(road[at+1]-road[at]).normalized()
		g.car.rotation.y=atan2(-direction.x,-direction.z)
		g._set_seat(1 if encounter.side>0 else 0)
		g.car.look.look_at(spot+Vector3.UP*1.4)
		woods.update_mood(g.car.position,g.elapsed,100)
		await capture("sighting_%d"%i)
		g._set_seat(2)
		g.car.look.look_at(spot+Vector3.UP*1.4)
		g.tool_on=true
		await get_tree().create_timer(0.5).timeout
		await capture("sighting_camera_%d"%i)
		g.tool_on=false
	print("QA_WOODLAND_SCREENSHOTS fps=",Engine.get_frames_per_second())
	get_tree().quit()

func effects_test() -> void:
	check(not InputMap.has_action("headlights"),"No headlights binding")
	check(not InputMap.has_action("horn"),"No horn binding")
	g.effects.request_lights()
	check(not g.effects.headlights,"Lights toggle off")
	for light in g.effects.lights: check(not light.visible,"Both beams off")
	g.horn_pressed=true
	g.effects._process(0.02)
	check(g.effects.honking,"Horn held")
	g.ui.show_pause()
	g.effects._process(0.02)
	check(not g.effects.honking,"Menu releases horn")
	g.horn_pressed=false
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
		# Look ahead for junctions and brake before a tight turn, as a human driver would.
		var ahead=(points[mini(target+10,points.size()-1)]-points[target]).normalized()
		var bend=absf(direction.signed_angle_to(ahead,Vector3.UP))
		var desired=clampf(11.2/(1+absf(angle)*1.5),3.0,11.2)
		if bend>0.65: desired=minf(desired,maxf(3.0,10.0/(1+bend*2)))
		g.controls=Vector3(1 if g.speed<desired else (-1 if g.speed>desired+0.7 else 0),clampf(angle*3.2,-1,1),0)
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

func capture(name: String) -> void:
	await get_tree().create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var directory=OS.get_environment("SINTRA_QA_OUTPUT")
	if directory.is_empty(): directory="user://"
	get_viewport().get_texture().get_image().save_png(directory.path_join(name+".png"))

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
	g.car.update_occupant(0,Vector3.ZERO,1)
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
			g.car.update_occupant(seat,Vector3(0,yaw,0),1,true)
			var hand=g.car.hands[seat][0 if yaw>=0 else 1]
			var p=g.car.to_local(hand.global_position)
			check(absf(p.x)<=0.89 and p.y<1.8,"Point stays inside cabin")
		g.car.update_occupant(seat,Vector3(0,0,1),1,true)
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

func driving_test() -> void:
	var yaws: Array[float]=[]
	for rate in [30,60,120]:
		g._begin(0)
		g.speed=10
		g.controls=Vector3(0,1,0)
		for i in int(rate*0.2): g._simulate(1.0/rate)
		var yaw=absf(g.car.rotation.y)
		yaws.append(yaw)
		check(yaw>0.01 and yaw<0.065,"Short steering tap is controlled at "+str(rate)+" Hz")
		g.controls=Vector3.ZERO
		for i in int(rate*0.3): g._simulate(1.0/rate)
		check(absf(g.steering)<0.001,"Steering recentres after release")
	check(absf(yaws[0]-yaws[2])<0.007,"Steering consistent across simulation rates")
	g._begin(0)
	g.controls=Vector3(1,0,0)
	for i in 180: g._simulate(1.0/60)
	check(g.speed>5 and g.speed<8,"Progressive acceleration instead of a sudden launch")
	check(g.trip_distance>8,"Trip records actual movement")
	g.controls=Vector3(-1,0,0)
	for i in 90: g._simulate(1.0/60)
	check(g.speed<=0 and g.speed>-1,"Braking settles before reverse builds")
	for i in 90: g._simulate(1.0/60)
	check(g.speed< -1 and g.speed>=-3.4,"Reverse remains controllable")
	var instruments=g.car.instruments
	instruments.reset()
	var rest=instruments.speed_needle.rotation.z
	for i in 120: instruments.update_readings(1.0/60,10,3000,1234,true)
	check(absf(instruments.shown_speed-36)<0.1,"Speed dial reads actual km/h")
	check(instruments.speed_needle.rotation.z<rest-1,"Physical speed needle moves")
	check(absf(rad_to_deg(instruments.speed_needle.rotation.z)-14)<1,"36 km/h aligns with the dial scale")
	check(absf(instruments.rpm_needle.rotation.z)<0.01,"3000 RPM aligns with middle of tachometer")
	check(instruments.trip.text=="001.2","Trip kilometres displayed")
	instruments.update_readings(1,0,850,1234,false)
	check(instruments.shown_speed<0.1 and not instruments.headlight_indicator.visible,"Stop and headlight state reflected")
	g._begin(0)
	check(g.trip_distance==0 and instruments.trip.text=="000.0","New journey resets instruments")
	g.ui.show_settings()
	for node in g.ui.find_children("*","Label",true,false):
		check(not "controller" in node.text.to_lower(),"No controller options in settings")
	print("QA_DRIVING failures=",failures," tap_yaw_radians=",yaws)
	get_tree().quit(0 if failures.is_empty() else 1)

func instruments_screenshots() -> void:
	g._begin(0)
	g.set_physics_process(false)
	g.set_process(false)
	g.car.look.rotation=Vector3(-0.13,0,0)
	g.car.animate(1,0,0,false,0)
	g.car.instruments.update_readings(1,0,850,0,true)
	for seat in 3: g.car.update_occupant(seat,Vector3.ZERO,1)
	await capture("instruments_idle")
	g.car.zooming=true
	g.car.look.look_at(g.car.instruments.global_position)
	g.car.animate(1,10,0.14,false,60)
	g.car.instruments.update_readings(1,10,3000,1234,true)
	for seat in 3: g.car.update_occupant(seat,Vector3.ZERO,1)
	await capture("instruments_moving")
	g.car.instruments.update_readings(1,0,850,1234,false)
	await capture("instruments_stopped")
	get_tree().quit()

func display_choice(key: String, value: int) -> void:
	for node in g.ui.find_children("*","OptionButton",true,false):
		if node.get_meta("setting","")==key:
			node.select(value)
			node.item_selected.emit(value)
			return
	check(false,"Missing display choice "+key)

func display_settle() -> void:
	await get_tree().create_timer(0.4).timeout
	while g.ui.display_busy: await get_tree().process_frame

func display_test() -> void:
	check(DisplayServer.get_name()!="headless","Display tests require a real OS window")
	g.prefs.values.window_mode=0
	g.prefs.values.resolution=0
	await g.prefs.apply_display()
	g.ui.show_settings()
	await display_settle()
	display_choice("resolution",1)
	await display_settle()
	check(DisplayServer.window_get_size()==Vector2i(1600,900),"Resolution previews immediately")
	check(g.ui.display_dialog.visible and g.ui.display_remaining>0,"Confirmation visible")
	await capture("display_confirmation")
	g.ui.display_dialog.confirmed.emit()
	check(g.ui.old_display.is_empty(),"Confirmation resets rollback baseline")
	var saved=ConfigFile.new()
	saved.load(g.prefs.FILE)
	check(saved.get_value("settings","resolution")==1,"Confirmed resolution persisted")
	display_choice("resolution",0)
	await display_settle()
	g.ui.display_dialog.canceled.emit()
	await display_settle()
	check(DisplayServer.window_get_size()==Vector2i(1600,900) and g.prefs.values.resolution==1,"Cancel restores most recent confirmed size")
	display_choice("resolution",0)
	await display_settle()
	g.ui._process(13)
	await display_settle()
	check(DisplayServer.window_get_size()==Vector2i(1600,900),"Timeout restores confirmed size")
	display_choice("window_mode",2)
	await display_settle()
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"Fullscreen applies live")
	g.ui.display_dialog.confirmed.emit()
	display_choice("resolution",0)
	await display_settle()
	var scale_before=get_tree().root.scaling_3d_scale
	check(is_equal_approx(scale_before,1280.0/DisplayServer.window_get_size().x),"Fullscreen resolution updates scene rendering")
	g.ui.display_dialog.confirmed.emit()
	display_choice("resolution",1)
	await display_settle()
	check(get_tree().root.scaling_3d_scale>scale_before,"Higher fullscreen resolution increases scene detail")
	g.ui.display_dialog.confirmed.emit()
	display_choice("window_mode",1)
	await display_settle()
	check(DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),"Borderless applies live")
	check(DisplayServer.window_get_size()==DisplayServer.screen_get_size(get_tree().root.current_screen),"Borderless fills monitor")
	g.ui.display_dialog.confirmed.emit()
	display_choice("window_mode",0)
	await display_settle()
	check(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_size()==Vector2i(1600,900),"Returning to windowed restores selected size")
	check(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),"Window borders restored")
	g.ui.display_dialog.confirmed.emit()
	g.ui._restore_defaults()
	await display_settle()
	check(DisplayServer.window_get_size()==Vector2i(1280,720),"Defaults apply window size immediately")
	g.ui.display_dialog.confirmed.emit()
	await capture("display_settings")
	g.ui._save_return()
	print("QA_DISPLAY failures=",failures," mode=",DisplayServer.window_get_mode()," size=",DisplayServer.window_get_size())
	get_tree().quit(0 if failures.is_empty() else 1)

func barriers_test() -> void:
	check(g.forest.guardrails.spans.size()>8000,"Continuous barrier network")
	# Check mesh endpoints against their independent collision span, on every bend.
	for i in g.forest.guardrails.spans.size():
		var span=g.forest.guardrails.spans[i]
		var rail: Transform3D=g.forest.guardrails.rail_transforms[i*2]
		for sign_value in [-1,1]:
			var rendered=rail*Vector3(0,0,sign_value*0.5)
			var post: Vector3=span.position+span.basis.z*(span.half.y-0.075)*sign_value
			rendered.y=0
			check(rendered.distance_to(post)<0.03,"Rail meets post on span "+str(i))
	for road in g.forest.roads:
		for i in range(1,road.size()-2,9):
			var direction=(road[i+1]-road[i]).normalized()
			var yaw=atan2(-direction.x,-direction.z)
			check(not g.forest.guardrails.blocked(road[i],yaw),"Barriers leave centreline open")
	for side in [-1,1]:
		g._begin(0)
		var road=g.forest.roads[0]
		var forward=(road[61]-road[60]).normalized()
		var across=forward.cross(Vector3.UP)*side
		g.car.position=road[60]
		g.car.rotation.y=atan2(-across.x,-across.z)
		g.speed=6
		g.controls=Vector3(1,0,0)
		var count=g.effects.impact_count
		for i in 120:g._simulate(1.0/60)
		check(g.effects.impact_count>count,"Barrier contact plays impact")
		check(g.forest.distance_to_road(g.car.position)<3.5,"Cannot leave road through barrier")
		check(not g.forest.guardrails.blocked(g.car.position,g.car.rotation.y),"Car remains outside solid railing")
		count=g.effects.impact_count
		g.effects.barrier_hit(10)
		check(g.effects.impact_count==count,"Contact cooldown avoids repeated noise")
	check(g.forest.woodland.fires.size()==2,"Campfires preserved")
	g._set_seat(2)
	g.tool_on=true
	g._process(1)
	check(not g.forest.ghost.visible,"No random standing figure through camera")
	print("QA_BARRIERS failures=",failures," spans=",g.forest.guardrails.spans.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func barrier_screenshots() -> void:
	g._begin(0)
	await capture("driver_barriers")
	g.car.look.look_at(g.car.pendant.global_position+Vector3(0,-0.25,0))
	await capture("wooden_ist")
	for index in [0,1,3]:
		var road=g.forest.roads[index]
		var at=road.size()-19
		g.car.position=road[at]
		var direction=(road[at+1]-road[at]).normalized()
		g.car.rotation.y=atan2(-direction.x,-direction.z)
		g.car.look.rotation=Vector3(-0.065,0,0)
		await capture("junction_%d"%index)
	var overhead=Camera3D.new()
	g.add_child(overhead)
	overhead.position=Vector3(g.forest.region.nodes[1][0],65,g.forest.region.nodes[1][1]+20)
	overhead.look_at(Vector3(g.forest.region.nodes[1][0],0,g.forest.region.nodes[1][1]),Vector3.FORWARD)
	overhead.current=true
	g.forest.environment.ambient_light_energy=0.65
	g.menu.visible=true
	g.menu.modulate.a=0
	await capture("junction_overhead")
	overhead.queue_free()
	g.menu.visible=false
	g.menu.modulate.a=1
	g.car.camera.current=true
	g._set_seat(1)
	g.tool_on=true
	await capture("paper_map")
	get_tree().quit()
