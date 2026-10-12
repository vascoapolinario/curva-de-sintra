extends Node3D
## One journey, three switchable roles.
const Forest = preload("res://scripts/forest.gd")
const Cabin = preload("res://scripts/cabin.gd")
const Preferences = preload("res://scripts/settings.gd")
const Interface = preload("res://scripts/interface.gd")
const Radio = preload("res://scripts/radio.gd")
@export var top_speed: float = 11.5
@export var acceleration: float = 2.9
@export var mouse_sensitivity: float = 0.0022

var prefs: Node
var ui: Control
var radio: Node
var forest: Node3D
var car: Node3D
var running = false
var won = false
var lost = false
var pointing = false
var gestures = [false,false,false]
var wildlife: AudioStreamPlayer3D
var effects: Node
var cabin_lights: Node3D
var interactions: Node3D
var horn_pressed=false
var radio_drag=false
var radio_drag_distance=0.0
var local_seat = 0
var chosen_seat = 0
var speed = 0.0
var steering = 0.0
var throttle = 0.0
var engine_rpm = 850.0
var trip_distance = 0.0
var tool_on = false
var controls = Vector3.ZERO
var elapsed = 0.0
var poses = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
var menu: Control
var menu_panel: VBoxContainer
var status: Label
var hud: Label
var cam_hud: Control
var cam_time: Label
var analog: ShaderMaterial
var resume_button: Button
var action_buttons: Array[Control] = []
var outcome: Control
var engine_sound: AudioStreamPlayer
var forest_sound: AudioStreamPlayer
var qa_mode = ""

func _ready() -> void:
	prefs = Preferences.new()
	prefs.name = "Preferences"
	add_child(prefs)
	forest = Forest.new()
	forest.name = "ForestRoads"
	add_child(forest)
	car = Cabin.new()
	car.name = "Car"
	car.position = forest.roads[0][3]
	add_child(car)
	radio = Radio.new()
	radio.name = "Radio"
	add_child(radio)
	radio.setup(self)
	_build_ui()
	_build_audio()
	effects=load("res://scripts/car_effects.gd").new()
	effects.name="CarEffects"
	add_child(effects)
	effects.setup(self)
	cabin_lights=load("res://scripts/cabin_lights.gd").new()
	car.add_child(cabin_lights)
	cabin_lights.setup(self)
	interactions=load("res://scripts/cabin_interactions.gd").new()
	car.add_child(interactions)
	interactions.setup(self)
	prefs.changed.connect(_apply_settings)
	_apply_settings()
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--qa="): qa_mode = arg.trim_prefix("--qa=")
	if qa_mode != "": call_deferred("_run_qa")
	else: prefs.apply_display()

func _exit_tree() -> void:
	if engine_sound: engine_sound.stop()
	if forest_sound: forest_sound.stop()

func _build_audio() -> void:
	engine_sound = _loop_audio("res://assets/engine.wav",-14)
	engine_sound.bus = "Engine"
	forest_sound = _loop_audio("res://assets/forest.wav",-9)
	forest_sound.bus = "Ambience"
	wildlife=AudioStreamPlayer3D.new()
	wildlife.bus="Ambience"
	wildlife.unit_size=22
	wildlife.max_distance=110
	wildlife.volume_db=-12
	add_child(wildlife)

func _loop_audio(path: String, volume: float) -> AudioStreamPlayer:
	var sound = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	sound.stream = stream
	sound.volume_db = volume
	add_child(sound)
	if DisplayServer.get_name() != "headless": sound.play()
	return sound

func _build_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	ui = Interface.new()
	layer.add_child(ui)
	ui.setup(self)

func _apply_settings() -> void:
	mouse_sensitivity = prefs.values.sensitivity
	car.base_fov = prefs.values.fov
	car.sway_amount = prefs.values.sway
	car.camera.far = prefs.values.view_distance
	for child in car.get_children():
		if child is SpotLight3D: child.shadow_enabled = prefs.values.shadows
	for batch in forest.vegetation: batch.visibility_range_end = prefs.values.view_distance+40
	analog.set_shader_parameter("grain_amount",prefs.values.grain)
	analog.set_shader_parameter("pixel_size",prefs.values.pixels)
	analog.set_shader_parameter("brightness",prefs.values.exposure)
	analog.set_shader_parameter("scanlines",prefs.values.scanlines)
	ui.controls_theme.default_font_size = int(16*prefs.values.ui_scale)
	for type in ["Label","Button","CheckButton","OptionButton"]:
		ui.controls_theme.set_color("font_color",type,Color("eee8d8") if prefs.values.contrast else Color("cecbbd"))

func input_blocked() -> bool:
	return menu.visible or won or lost

func _start_game() -> void:
	_begin(chosen_seat)

func _begin(seat: int) -> void:
	forest.ghost.position=forest.roads[0][65]+Vector3(6,0,0)
	forest.ghost.rotation=Vector3.ZERO
	car.position = forest.roads[0][3]
	car.rotation = Vector3.ZERO
	speed = 0
	controls = Vector3.ZERO
	elapsed = 0
	forest.woodland.update_mood(car.position,0,100)
	won = false
	lost = false
	pointing = false
	gestures = [false,false,false]
	car.zooming = false
	running = true
	tool_on = false
	outcome.visible = false
	effects.reset()
	cabin_lights.reset()
	poses=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	steering=0
	throttle=0
	engine_rpm=850
	trip_distance=0
	car.instruments.reset()
	_set_seat(seat)
	poses=[Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _set_seat(seat: int) -> void:
	if effects and local_seat==0 and seat!=0: effects.release_driver()
	poses[local_seat]=Vector3(car.look.rotation.x,car.look.rotation.y,float(tool_on))
	horn_pressed=false
	gestures[local_seat]=false
	pointing=false
	radio_drag=false
	local_seat = seat
	tool_on = poses[seat].z>0.5 if running else false
	car.select_seat(seat)

func _leave() -> void:
	effects.reset()
	running = false
	won = false
	lost = false
	pointing = false
	gestures = [false,false,false]
	car.zooming = false
	speed = 0
	controls = Vector3.ZERO
	tool_on = false
	poses = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	car.position = forest.roads[0][3]
	car.rotation = Vector3.ZERO
	car.select_seat(0)
	local_seat = 0
	outcome.visible = false
	menu.visible = true
	ui.show_title()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _resume() -> void:
	prefs.save()
	menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if ui.display_busy or ui.display_remaining>0: return
	var pause_pressed = (event is InputEventKey and event.pressed and event.keycode==KEY_ESCAPE) or (event is InputEventJoypadButton and event.pressed and event.button_index==JOY_BUTTON_START)
	if event is InputEventKey and event.pressed and event.keycode==KEY_F11:
		prefs.values.window_mode = 0 if DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN else 2
		prefs.apply_display()
		prefs.save()
	if pause_pressed:
		if running and not won and not lost:
			if menu.visible: _resume()
			else: ui.show_pause()
		return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		horn_pressed=false
		effects.release_driver()
	if not running or won or lost: return
	if input_blocked(): return
	if event is InputEventMouseMotion and radio_drag:
		radio_drag_distance+=absf(event.relative.x)+absf(event.relative.y)
		if radio_drag_distance>4: request_radio(radio.station,radio.volume+event.relative.x*0.003,radio.power)
		return
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if not event.pressed and radio_drag:
				radio_drag=false
				if radio_drag_distance<=4: _use_radio("power")
				return
			if event.pressed and not tool_on and car.radio_hit()=="power":
				radio_drag=true
				radio_drag_distance=0
				pointing=false
				return
			if event.pressed and (interactions.use(interactions.hit()) or cabin_lights.use(cabin_lights.hit()) or _use_radio(car.radio_hit())):
				pointing=false
			else: pointing=event.pressed and not tool_on
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and car.radio_hit() in ["power","quieter","louder"]:
			_use_radio("louder" if event.button_index==MOUSE_BUTTON_WHEEL_UP else "quieter")
	for i in 3:
		if event.is_action_pressed(["seat_driver","seat_navigator","seat_camera"][i]): _set_seat(i)
	if event is InputEventMouseMotion:
		car.look.rotation.y -= event.relative.x*mouse_sensitivity*(-1 if prefs.values.invert_x else 1)
		car.look.rotation.x -= event.relative.y*mouse_sensitivity*(-1 if prefs.values.invert_y else 1)
	car.limit_look(tool_on)

func _physics_process(delta: float) -> void:
	if not running or input_blocked(): return
	controls=Vector3.ZERO
	if local_seat==0:
		controls.x=Input.get_action_strength("accelerate")-Input.get_action_strength("reverse")
		controls.y=Input.get_action_strength("left")-Input.get_action_strength("right")

	elapsed+=delta
	if elapsed>=900:
		elapsed=900
		_lose()
		return
	_simulate(delta)

func _simulate(delta: float) -> void:
	if won or lost: return
	# Progressive keyboard steering, with a faster return to centre than turn-in.
	var returning=absf(controls.y)<0.05 or steering*controls.y<0
	steering=move_toward(steering,controls.y,delta*(2.5 if returning else 1.55))
	throttle=move_toward(throttle,controls.x,delta*(4.5 if absf(controls.x)<0.1 else 2.8))
	if controls.z > 0.5:
		speed=move_toward(speed,0,delta*9)
		throttle=0
	elif speed*controls.x < -0.05:
		# Opposite input brakes before engaging the other direction.
		speed=move_toward(speed,0,delta*6.5)
		throttle=0
	elif absf(throttle)>0.01:
		var force=acceleration*(1.0-0.28*clampf(absf(speed)/top_speed,0,1))
		speed=clampf(speed+throttle*force*delta,-3.4,top_speed)
	else:
		speed=move_toward(speed,0,delta*0.95)
	var old_position = car.position
	var old_yaw = car.rotation.y
	car.rotation.y += speed/2.65*tan(road_wheel_angle())*delta
	car.position += -car.basis.z*speed*delta
	var hit_barrier=forest.guardrails.blocked(car.position,car.rotation.y)
	if hit_barrier or not forest.is_drivable(car.position) or forest.blocked_by_obstacle(car.position,car.rotation.y):
		if hit_barrier: effects.barrier_hit(speed)
		car.position = old_position
		car.rotation.y = old_yaw
		speed *= -0.12
	for end in forest.dead_ends:
		if car.position.distance_to(end) < 2.5 and car.position.distance_to(end) < old_position.distance_to(end):
			car.position = old_position
			speed *= -0.12
	trip_distance+=car.position.distance_to(old_position)
	if car.position.distance_to(forest.destination) < 7.5:
		_finish()

func road_wheel_angle() -> float:
	var speed_ratio=clampf(absf(speed)/top_speed,0,1)
	var lock=lerpf(0.50,0.26,speed_ratio)
	return steering*(0.80+0.20*absf(steering))*lock

func _finish() -> void:
	if lost: return
	pointing = false
	car.zooming = false
	won = true
	effects.stop()
	speed = 0
	controls = Vector3.ZERO
	tool_on = false
	outcome.visible = false
	ui.show_ending()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	if not menu.visible: forest.woodland.update_mood(car.position,elapsed,delta)
	car.zooming = running and not input_blocked() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if input_blocked() or tool_on:
		pointing = false
		radio_drag=false
	if input_blocked(): horn_pressed=false
	if running and not input_blocked() and not Input.get_connected_joypads().is_empty():
		var pad = Input.get_connected_joypads()[0]
		var axis = Vector2(Input.get_joy_axis(pad,JOY_AXIS_RIGHT_X),Input.get_joy_axis(pad,JOY_AXIS_RIGHT_Y))
		if axis.length() > prefs.values.deadzone:
			car.look.rotation.y -= axis.x*prefs.values.controller_speed*delta*(-1 if prefs.values.invert_x else 1)
			car.look.rotation.x -= axis.y*prefs.values.controller_speed*delta*(-1 if prefs.values.invert_y else 1)
	car.animate(delta,speed,road_wheel_angle()/0.50,tool_on,elapsed)
	var rpm_target=850.0+absf(speed)*205.0+maxf(0,throttle)*350.0
	engine_rpm=lerpf(engine_rpm,rpm_target,1.0-exp(-delta*5.0))
	car.instruments.update_readings(delta,speed,engine_rpm,trip_distance,effects.headlights)
	interactions.animate(delta)
	var camera_active = running and local_seat==2 and tool_on and car.tool_blend>0.86 and not won and not lost
	analog.set_shader_parameter("camcorder",camera_active)
	forest.ghost.visible = lost
	car.map_material.set_shader_parameter("car_uv",forest.map_uv(car.position))
	car.map_material.set_shader_parameter("heading",car.rotation.y)
	for seat in 3:
		car.update_occupant(seat,poses[seat] if seat!=local_seat else Vector3(car.look.rotation.x,car.look.rotation.y,float(tool_on)),delta,gestures[seat] if seat!=local_seat else pointing)
	cam_hud.visible = camera_active and not input_blocked()
	cam_time.text = "%02d:%02d:%02d" % [int(elapsed)/3600,(int(elapsed)/60)%60,int(elapsed)%60]
	var hit = interactions.hit()
	if hit.is_empty() and running and not input_blocked(): hit=car.radio_hit()
	if hit.is_empty(): hit=cabin_lights.hit()
	ui.set_interaction(hit)
	hud.visible = not hit.is_empty() and prefs.values.prompts and not tool_on
	hud.text = {"horn":"Horn · hold click", "headlights":"Headlights · click", "map_pickup":"Unfold map · click", "map_stow":"Fold map · click", "camera_pickup":"Pick up camcorder · click", "camera_stow":"Put down camcorder · click", "power":"Power · click   /   Volume · drag or scroll", "front_light":"Cabin light · click", "rear_light":"Rear light · click", "station":"Tune · click","quieter":"Volume −","louder":"Volume +","preset0":"87.6 FM","preset1":"92.3 FM","preset2":"104.8 FM"}.get(hit,"")
	engine_sound.pitch_scale = 0.7+(engine_rpm-850.0)*0.00030
	engine_sound.volume_db = -80 if lost else (-14 if running else -23)

func request_radio(station: int, volume: float, power: bool) -> void:
	if local_seat!=1 or won or lost or not running: return
	_commit_radio(station,volume,power)

func _commit_radio(station: int, volume: float, power: bool) -> void:
	var epoch = elapsed if station!=radio.station else radio.epoch
	radio.apply_state(clampi(station,0,2),clampf(volume,0,1),power,epoch)

func _run_qa() -> void:
	var tests = load("res://scripts/qa.gd").new()
	add_child(tests)
	tests.run(self,qa_mode)

func _use_radio(hit: String) -> bool:
	if local_seat!=1 or tool_on or hit.is_empty(): return false
	var station: int = radio.station
	var volume: float = radio.volume
	var power: bool = radio.power
	match hit:
		"power": power=not power
		"station": station=(station+1)%3; power=true
		"quieter": volume=maxf(0,volume-0.1)
		"louder": volume=minf(1,volume+0.1)
		_: station=int(hit.trim_prefix("preset")); power=true
	request_radio(station,volume,power)
	return true

func _lose() -> void:
	if won or lost: return
	lost=true
	effects.stop()
	elapsed=900.0
	speed=0
	controls=Vector3.ZERO
	pointing=false
	gestures=[false,false,false]
	tool_on=false
	car.zooming=false
	radio.player.stop()
	forest.ghost.global_position=car.global_transform*Vector3(0.35,0,-3.1)
	forest.ghost.rotation.y=car.rotation.y
	ui.show_failure()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

