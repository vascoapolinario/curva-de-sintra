extends Node3D
## Host owns movement, seat allocation, the journey clock and outcome.
const Forest = preload("res://scripts/forest.gd")
const Cabin = preload("res://scripts/cabin.gd")
const Voice = preload("res://scripts/voice.gd")
const Preferences = preload("res://scripts/settings.gd")
const Interface = preload("res://scripts/interface.gd")
const Radio = preload("res://scripts/radio.gd")
const PORT = 28470
const SEATS = ["DRIVER", "NAVIGATOR", "CAMERA OPERATOR"]
@export var top_speed: float = 11.5
@export var acceleration: float = 3.7
@export var mouse_sensitivity: float = 0.0022

var prefs: Node
var ui: Control
var radio: Node
var forest: Node3D
var car: Node3D
var voice: Node
var mode = "solo"
var running = false
var won = false
var lost = false
var pointing = false
var gestures = [false,false,false]
var wildlife: AudioStreamPlayer3D
var effects: Node
var local_seat = 0
var chosen_seat = 0
var players: Dictionary = {}
var speed = 0.0
var steering = 0.0
var tool_on = false
var controls = Vector3.ZERO
var remote_input_time = 0
var target_position = Vector3.ZERO
var target_yaw = 0.0
var sync_time = 0.0
var elapsed = 0.0
var poses = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
var menu: Control
var menu_panel: VBoxContainer
var status: Label
var hud: Label
var room_label: Label
var toast_label: Label
var cam_hud: Control
var cam_time: Label
var analog: ShaderMaterial
var address: LineEdit
var seat_choice: OptionButton
var mic_toggle: CheckButton
var resume_button: Button
var action_buttons: Array[Control] = []
var outcome: Control
var engine_sound: AudioStreamPlayer
var forest_sound: AudioStreamPlayer
var toast_time = 0.0
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
	voice = Voice.new()
	voice.name = "Voice"
	voice.game = self
	add_child(voice)
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
	prefs.changed.connect(_apply_settings)
	_apply_settings()
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_left)
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--qa="): qa_mode = arg.trim_prefix("--qa=")
	if qa_mode != "": call_deferred("_run_qa")
	else: prefs.apply_display()

func _exit_tree() -> void:
	if engine_sound: engine_sound.stop()
	if forest_sound: forest_sound.stop()
	if voice: voice.reset()

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
	if voice.enabled != prefs.values.mic_enabled: voice.enable_microphone(prefs.values.mic_enabled)
	ui.controls_theme.default_font_size = int(16*prefs.values.ui_scale)
	for type in ["Label","Button","CheckButton","OptionButton"]:
		ui.controls_theme.set_color("font_color",type,Color("eee8d8") if prefs.values.contrast else Color("cecbbd"))

func input_blocked() -> bool:
	return menu.visible or won or lost

func _start_solo() -> void:
	_close_network()
	mode = "solo"
	players = {1:chosen_seat}
	_begin(chosen_seat)

func _host() -> void:
	_close_network()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT,2,3)
	if error != OK:
		status.text = "Could not host. Another car may be using port %s." % PORT
		return
	multiplayer.multiplayer_peer = peer
	mode = "host"
	players = {1:chosen_seat}
	_begin(chosen_seat)
	_toast("Waiting for your passengers.")

func _join() -> void:
	var ip = address.text.strip_edges()
	if ip.is_empty():
		status.text = "Enter the host's IP address first."
		return
	_close_network()
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip,PORT,3)
	if error != OK:
		status.text = "Could not connect. Check the host address."
		return
	mode = "client"
	multiplayer.multiplayer_peer = peer
	status.text = "Connecting to %s…" % ip

func _connected() -> void:
	_request_seat.rpc_id(1,chosen_seat)

@rpc("any_peer","call_remote","reliable")
func _request_seat(seat: int) -> void:
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	if players.has(id): return
	if seat < 0 or seat > 2 or seat in players.values():
		_seat_denied.rpc_id(id,"That seat is occupied. Choose another seat and join again.")
		return
	if players.size() >= 3:
		_seat_denied.rpc_id(id,"This car is full.")
		return
	players[id] = seat
	_accepted.rpc_id(id,seat,car.position,car.rotation.y,won,lost,elapsed)
	_update_roster.rpc(players)
	_radio_state.rpc_id(id,radio.station,radio.volume,radio.power,radio.epoch,elapsed)
	effects.sync_peer(id)

@rpc("authority","call_remote","reliable")
func _seat_denied(reason: String) -> void:
	_close_network()
	mode = "solo"
	status.text = reason

@rpc("authority","call_remote","reliable")
func _accepted(seat: int, pos: Vector3, yaw: float, complete: bool, failed: bool, clock: float) -> void:
	_begin(seat)
	car.position = pos
	car.rotation.y = yaw
	target_position = pos
	target_yaw = yaw
	elapsed = clock
	if complete: _finish()
	elif failed: _lose()

@rpc("authority","call_remote","reliable")
func _update_roster(roster: Dictionary) -> void:
	players = roster

func _begin(seat: int) -> void:
	forest.ghost.position=forest.roads[0][65]+Vector3(6,0,0)
	forest.ghost.rotation=Vector3.ZERO
	car.position = forest.roads[0][3]
	car.rotation = Vector3.ZERO
	speed = 0
	controls = Vector3.ZERO
	elapsed = 0
	won = false
	lost = false
	pointing = false
	gestures = [false,false,false]
	car.zooming = false
	running = true
	tool_on = false
	outcome.visible = false
	effects.reset()
	_set_seat(seat)
	menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _set_seat(seat: int) -> void:
	if effects and local_seat==0 and seat!=0: effects.release_driver()
	local_seat = seat
	tool_on = false
	car.select_seat(seat)

func _close_network() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	voice.reset()
	if prefs.values.mic_enabled: voice.enable_microphone(true)

func _leave() -> void:
	effects.reset()
	prefs.values.mic_enabled = false
	_close_network()
	mode = "solo"
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
	status.text = ""

func _peer_left(id: int) -> void:
	if players.has(id):
		var seat: int = players[id]
		poses[seat] = Vector3.ZERO
		gestures[seat] = false
		players.erase(id)
		voice.remove_peer(id)
		if seat == 0:
			effects.release_driver()
			controls = Vector3.ZERO
			speed = 0
		_toast("A passenger disconnected. Their seat is available again.")
		if multiplayer.is_server(): _update_roster.rpc(players)

func _connection_failed() -> void:
	_leave()
	status.text = "Connection failed. Check the IP and that the host is running."

func _server_left() -> void:
	_leave()
	status.text = "The host left the car. You can host or join another session."

func _resume() -> void:
	prefs.save()
	menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
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
	if not running or won or lost: return
	if input_blocked(): return
	if event.is_action_pressed("headlights"): effects.request_lights()
	if event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			if event.pressed and _use_radio(car.radio_hit()):
				pointing=false
			else: pointing=event.pressed and not tool_on
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and car.radio_hit() in ["power","quieter","louder"]:
			_use_radio("louder" if event.button_index==MOUSE_BUTTON_WHEEL_UP else "quieter")
	if event.is_action_pressed("radio_panel"): _use_radio(car.radio_hit())
	if event.is_action_pressed("map") and local_seat==1: tool_on = not tool_on
	if event.is_action_pressed("camera") and local_seat==2: tool_on = not tool_on
	if mode=="solo":
		for i in 3:
			if event.is_action_pressed(["seat_driver","seat_navigator","seat_camera"][i]):
				_set_seat(i)
				players[1]=i
	if event is InputEventMouseMotion:
		car.look.rotation.y -= event.relative.x*mouse_sensitivity*(-1 if prefs.values.invert_x else 1)
		car.look.rotation.x -= event.relative.y*mouse_sensitivity*(-1 if prefs.values.invert_y else 1)
	car.limit_look(tool_on)

func _physics_process(delta: float) -> void:
	if not running or won or lost: return
	if mode == "solo" and menu.visible: return
	var input_vector = Vector3.ZERO
	if not input_blocked() and local_seat == 0:
		input_vector.x = Input.get_action_strength("accelerate")-Input.get_action_strength("reverse")
		input_vector.y = Input.get_action_strength("left")-Input.get_action_strength("right")
		input_vector.z = Input.get_action_strength("brake")
	if qa_mode == "join0" and running: input_vector = Vector3(1,0,0)
	if qa_mode == "join2" and running: input_vector = Vector3(1,1,0)
	if mode != "client":
		if local_seat == 0: controls = input_vector
		elif mode == "solo" or Time.get_ticks_msec()-remote_input_time > 350: controls = Vector3.ZERO
		elapsed += delta
		if elapsed >= 900.0:
			elapsed = 900.0
			_lose()
			if mode=="host": _expired.rpc()
			return
		_simulate(delta)
	else:
		car.position = car.position.lerp(target_position,1.0-exp(-delta*14))
		car.rotation.y = lerp_angle(car.rotation.y,target_yaw,1.0-exp(-delta*14))
	sync_time += delta
	if sync_time >= 0.05 and mode != "solo":
		sync_time = 0
		var pose = Vector3(car.look.rotation.x,car.look.rotation.y,float(tool_on))
		if mode == "client":
			_input_packet.rpc_id(1,input_vector,pose,pointing and not tool_on)
		else:
			poses[local_seat] = pose
			gestures[local_seat] = pointing and not tool_on
			_snapshot.rpc(car.position,car.rotation.y,speed,steering,poses,elapsed,gestures)

func _simulate(delta: float) -> void:
	if won or lost: return
	steering = move_toward(steering,controls.y,delta*3.5)
	if controls.z > 0.5:
		speed = move_toward(speed,0,delta*12)
	elif absf(controls.x) > 0.1:
		var force = acceleration
		if speed*controls.x < 0: force = 7.5
		speed = clampf(speed+controls.x*force*delta,-3.4,top_speed)
	else:
		speed = move_toward(speed,0,delta*1.6)
	var old_position = car.position
	var old_yaw = car.rotation.y
	car.rotation.y += steering*speed/2.5*tan(0.45)*delta
	car.position += -car.basis.z*speed*delta
	if not forest.is_drivable(car.position) or forest.blocked_by_obstacle(car.position,car.rotation.y):
		car.position = old_position
		car.rotation.y = old_yaw
		speed *= -0.12
	for end in forest.dead_ends:
		if car.position.distance_to(end) < 2.5 and car.position.distance_to(end) < old_position.distance_to(end):
			car.position = old_position
			speed *= -0.12
	if car.position.distance_to(forest.destination) < 7.5:
		_finish()
		if mode == "host": _arrived.rpc()

@rpc("any_peer","call_remote","unreliable_ordered",1)
func _input_packet(input_vector: Vector3, pose: Vector3, gesture: bool = false) -> void:
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	if not players.has(id) or not input_vector.is_finite() or not pose.is_finite(): return
	if won or lost: return
	var seat: int = players[id]
	gestures[seat] = gesture and pose.z<0.5
	poses[seat] = Vector3(clampf(pose.x,-0.85,0.7),clampf(pose.y,-3.02,3.02),float(pose.z>0.5 and seat!=0))
	if poses[seat].z>0.5:
		poses[seat].x=clampf(poses[seat].x,-0.28 if seat==1 else -0.36,0.30 if seat==1 else 0.43)
		poses[seat].y=clampf(poses[seat].y,-0.22 if seat==1 else -1.02,0.88 if seat==1 else 1.02)
	if seat == 0:
		controls = input_vector.clamp(Vector3(-1,-1,0),Vector3.ONE)
		remote_input_time = Time.get_ticks_msec()

@rpc("authority","call_remote","unreliable_ordered",1)
func _snapshot(pos: Vector3, yaw: float, velocity: float, turn: float, head_poses: Array, clock: float, points: Array) -> void:
	if won or lost: return
	target_position = pos
	target_yaw = yaw
	speed = velocity
	steering = turn
	poses = head_poses
	gestures = points
	if not won and not lost: elapsed = clock

@rpc("authority","call_remote","reliable")
func _arrived() -> void:
	_finish()

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
	if running and not won and not lost and mode=="client": elapsed = minf(900.0,elapsed+delta)
	car.zooming = running and not input_blocked() and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if input_blocked() or tool_on: pointing = false
	if running and not input_blocked() and not Input.get_connected_joypads().is_empty():
		var pad = Input.get_connected_joypads()[0]
		var axis = Vector2(Input.get_joy_axis(pad,JOY_AXIS_RIGHT_X),Input.get_joy_axis(pad,JOY_AXIS_RIGHT_Y))
		if axis.length() > prefs.values.deadzone:
			car.look.rotation.y -= axis.x*prefs.values.controller_speed*delta*(-1 if prefs.values.invert_x else 1)
			car.look.rotation.x -= axis.y*prefs.values.controller_speed*delta*(-1 if prefs.values.invert_y else 1)
	car.animate(delta,speed,steering,tool_on,elapsed)
	var camera_active = running and local_seat==2 and tool_on and car.tool_blend>0.86 and not won and not lost
	analog.set_shader_parameter("camcorder",camera_active)
	forest.ghost.visible = camera_active or lost
	car.map_material.set_shader_parameter("car_uv",forest.map_uv(car.position))
	car.map_material.set_shader_parameter("heading",car.rotation.y)
	for seat in 3:
		car.update_remote(seat,poses[seat] if seat!=local_seat else Vector3(car.look.rotation.x,car.look.rotation.y,float(tool_on)),delta,gestures[seat] if seat!=local_seat else pointing)
	cam_hud.visible = camera_active and not input_blocked()
	cam_time.text = "%02d:%02d:%02d" % [int(elapsed)/3600,(int(elapsed)/60)%60,int(elapsed)%60]
	var hit = car.radio_hit() if running and not input_blocked() else ""
	ui.set_interaction(hit)
	hud.visible = not hit.is_empty() and prefs.values.prompts
	hud.text = {"power":"Power · click   /   Volume · scroll","station":"Tune · click","quieter":"Volume −","louder":"Volume +","preset0":"87.6 FM","preset1":"92.3 FM","preset2":"104.8 FM"}.get(hit,"")
	room_label.text = "● Talking" if voice.active else ""
	for id in voice.talking_until:
		if voice.talking_until[id]>Time.get_ticks_msec() and players.has(id): room_label.text = "%s is speaking" % SEATS[players[id]].capitalize()
	room_label.visible = running and not input_blocked() and not room_label.text.is_empty()
	toast_label.visible = running and not input_blocked()
	engine_sound.pitch_scale = 0.7+absf(speed)*0.07
	engine_sound.volume_db = -80 if lost else (-14 if running else -23)
	if toast_time>0: toast_time-=delta
	else: toast_label.text=""

func request_radio(station: int, volume: float, power: bool) -> void:
	if local_seat!=1 or won or lost or not running: return
	if mode=="client": _radio_request.rpc_id(1,station,volume,power)
	else: _commit_radio(station,volume,power)

@rpc("any_peer","call_remote","reliable")
func _radio_request(station: int, volume: float, power: bool) -> void:
	if not multiplayer.is_server() or not is_finite(volume) or won or lost: return
	var sender = multiplayer.get_remote_sender_id()
	if players.get(sender,-1)!=1: return
	_commit_radio(station,volume,power)

func _commit_radio(station: int, volume: float, power: bool) -> void:
	var epoch = elapsed if station!=radio.station else radio.epoch
	radio.apply_state(clampi(station,0,2),clampf(volume,0,1),power,epoch)
	if mode=="host": _radio_state.rpc(radio.station,radio.volume,radio.power,radio.epoch,elapsed)

@rpc("authority","call_remote","reliable")
func _radio_state(station: int, volume: float, power: bool, epoch: float, clock: float) -> void:
	if not won and not lost: elapsed = clock
	radio.apply_state(station,volume,power,epoch)

func _toast(text: String) -> void:
	toast_label.text = text
	toast_time = 6.0

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

@rpc("authority","call_remote","reliable")
func _expired() -> void:
	_lose()

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

