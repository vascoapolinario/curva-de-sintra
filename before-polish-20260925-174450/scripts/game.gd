extends Node3D
## Main prototype controller. Host owns movement, seat allocation and the win state.
const Forest = preload("res://scripts/forest.gd")
const Cabin = preload("res://scripts/cabin.gd")
const Voice = preload("res://scripts/voice.gd")
const PORT = 28470
const SEATS = ["DRIVER", "NAVIGATOR", "CAMERA OPERATOR"]
@export var top_speed: float = 11.5
@export var acceleration: float = 3.7
@export var mouse_sensitivity: float = 0.0022

var forest: Node3D
var car: Node3D
var voice: Node
var mode = "solo"
var running = false
var won = false
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
var notification: Label
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
	forest = Forest.new()
	forest.name = "ForestRoads"
	add_child(forest)
	car = Cabin.new()
	car.name = "Car"
	car.position = Vector3(0,0,18)
	add_child(car)
	voice = Voice.new()
	voice.name = "Voice"
	voice.game = self
	add_child(voice)
	_build_ui()
	_build_audio()
	multiplayer.peer_disconnected.connect(_peer_left)
	multiplayer.connected_to_server.connect(_connected)
	multiplayer.connection_failed.connect(_connection_failed)
	multiplayer.server_disconnected.connect(_server_left)
	var args = OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--qa="): qa_mode = arg.trim_prefix("--qa=")
	if qa_mode != "": call_deferred("_run_qa")

func _exit_tree() -> void:
	if engine_sound: engine_sound.stop()
	if forest_sound: forest_sound.stop()
	if voice: voice.reset()

func _build_audio() -> void:
	engine_sound = _loop_audio("res://assets/engine.wav",-14)
	forest_sound = _loop_audio("res://assets/forest.wav",-9)

func _loop_audio(path: String, volume: float) -> AudioStreamPlayer:
	var sound = AudioStreamPlayer.new()
	var stream: AudioStreamWAV = load(path)
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = int(stream.get_length()*stream.mix_rate)
	sound.stream = stream
	sound.volume_db = volume
	add_child(sound)
	sound.play()
	return sound

func _build_ui() -> void:
	var layer = CanvasLayer.new()
	add_child(layer)
	var filter = ColorRect.new()
	filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	analog = ShaderMaterial.new()
	analog.shader = load("res://shaders/analog.gdshader")
	filter.material = analog
	layer.add_child(filter)
	var root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var theme = Theme.new()
	theme.default_font_size = 16
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Consolas","Courier New"])
	theme.default_font = font
	theme.set_color("font_color","Label",Color("c1c2ae"))
	theme.set_color("font_color","Button",Color("d3ceb4"))
	for state in ["normal","hover","pressed","focus"]:
		var box = StyleBoxFlat.new()
		box.bg_color = Color("242b23") if state in ["hover","pressed"] else Color(0.06,0.08,0.065,0.85)
		box.border_color = Color("746e4c") if state == "focus" else Color("454a3b")
		box.set_border_width_all(1)
		box.content_margin_left = 16
		box.content_margin_right = 16
		box.content_margin_top = 12
		box.content_margin_bottom = 12
		theme.set_stylebox(state,"Button",box)
	root.theme = theme
	hud = _label(root,"",Vector2(35,640),17)
	room_label = _label(root,"",Vector2(35,27),14)
	notification = _label(root,"",Vector2(35,565),17)
	notification.add_theme_color_override("font_color",Color("d3b573"))
	cam_hud = Control.new()
	cam_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cam_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cam_hud)
	_label(cam_hud,"● REC",Vector2(105,82),23).add_theme_color_override("font_color",Color("ed9d82"))
	_label(cam_hud,"SP    ▰▰▰▱",Vector2(1020,82),20)
	_label(cam_hud,"25.09.1996",Vector2(105,595),18)
	cam_time = _label(cam_hud,"00:00:00",Vector2(1020,595),18)
	for p in [Vector2(80,62),Vector2(1198,62),Vector2(80,649),Vector2(1198,649)]:
		var horizontal = ColorRect.new()
		horizontal.color = Color("9baa94")
		horizontal.position = p+Vector2(-29 if p.x>600 else 0,0)
		horizontal.size = Vector2(30,2)
		horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cam_hud.add_child(horizontal)
		var vertical = ColorRect.new()
		vertical.color = Color("9baa94")
		vertical.position = p+Vector2(0,-29 if p.y>400 else 0)
		vertical.size = Vector2(2,30)
		vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cam_hud.add_child(vertical)
	cam_hud.visible = false
	menu = Control.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(menu)
	var dim = ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.012,0.020,0.018,0.63)
	menu.add_child(dim)
	menu_panel = VBoxContainer.new()
	menu_panel.position = Vector2(66,42)
	menu_panel.size = Vector2(470,632)
	menu_panel.add_theme_constant_override("separation",12)
	menu.add_child(menu_panel)
	var kicker = Label.new()
	kicker.text = "SERRA DE SINTRA    /    01:43 AM"
	kicker.add_theme_font_size_override("font_size",14)
	kicker.add_theme_color_override("font_color",Color("a2a487"))
	menu_panel.add_child(kicker)
	var title = Label.new()
	title.text = "Curva de Sintra"
	var serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia","Times New Roman"])
	title.add_theme_font_override("font",serif)
	title.add_theme_font_size_override("font_size",48)
	title.add_theme_color_override("font_color",Color("e1ddc4"))
	menu_panel.add_child(title)
	var premise = Label.new()
	premise.text = "Three seats. One way out.\nFind the shelter at São Pedro."
	premise.add_theme_font_size_override("font_size",17)
	menu_panel.add_child(premise)
	resume_button = _button(menu_panel,"RETURN TO THE CAR",_resume)
	resume_button.visible = false
	action_buttons.append(_button(menu_panel,"DRIVE ALONE  /  test all three seats",_start_solo))
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	menu_panel.add_child(row)
	var seat_label = Label.new()
	seat_label.text = "YOUR SEAT"
	row.add_child(seat_label)
	seat_choice = OptionButton.new()
	for label in SEATS: seat_choice.add_item(label)
	seat_choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seat_choice.item_selected.connect(func(index): chosen_seat = index)
	row.add_child(seat_choice)
	action_buttons.append(row)
	var online_row = HBoxContainer.new()
	online_row.add_theme_constant_override("separation",10)
	menu_panel.add_child(online_row)
	_button(online_row,"HOST A CAR",_host).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_button(online_row,"JOIN A CAR",_join).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_buttons.append(online_row)
	address = LineEdit.new()
	address.placeholder_text = "Host IP address  (e.g. 192.168.1.20)"
	address.custom_minimum_size.y = 38
	menu_panel.add_child(address)
	action_buttons.append(address)
	mic_toggle = CheckButton.new()
	mic_toggle.text = "Enable microphone · hold V to talk"
	mic_toggle.toggled.connect(func(on): voice.enable_microphone(on))
	menu_panel.add_child(mic_toggle)
	var sensitivity_row = HBoxContainer.new()
	menu_panel.add_child(sensitivity_row)
	var sl = Label.new()
	sl.text = "MOUSE SENSITIVITY  "
	sl.add_theme_font_size_override("font_size",14)
	sensitivity_row.add_child(sl)
	var slider = HSlider.new()
	slider.min_value = 0.0008
	slider.max_value = 0.004
	slider.step = 0.0001
	slider.value = mouse_sensitivity
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v): mouse_sensitivity = v)
	sensitivity_row.add_child(slider)
	var bright_row = HBoxContainer.new()
	menu_panel.add_child(bright_row)
	var bl = Label.new()
	bl.text = "EXPOSURE           "
	bl.add_theme_font_size_override("font_size",14)
	bright_row.add_child(bl)
	var bright = HSlider.new()
	bright.min_value = 0.8
	bright.max_value = 1.8
	bright.step = 0.05
	bright.value = 1.12
	bright.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bright.value_changed.connect(func(v): analog.set_shader_parameter("brightness",v))
	bright_row.add_child(bright)
	status = Label.new()
	status.text = "LAN / direct IP · 3 players · headphones recommended"
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(470,43)
	status.add_theme_font_size_override("font_size",14)
	menu_panel.add_child(status)
	var quit_row = HBoxContainer.new()
	quit_row.add_theme_constant_override("separation",10)
	menu_panel.add_child(quit_row)
	_button(quit_row,"LEAVE SESSION",_leave)
	_button(quit_row,"QUIT",func(): get_tree().quit())
	outcome = Control.new()
	outcome.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(outcome)
	var win_dim = ColorRect.new()
	win_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	win_dim.color = Color(0.02,0.03,0.025,0.87)
	outcome.add_child(win_dim)
	var win_box = VBoxContainer.new()
	win_box.position = Vector2(350,220)
	win_box.size = Vector2(580,240)
	win_box.add_theme_constant_override("separation",23)
	outcome.add_child(win_box)
	var win_title = Label.new()
	win_title.text = "You made it to São Pedro."
	win_title.add_theme_font_override("font",serif)
	win_title.add_theme_font_size_override("font_size",36)
	win_box.add_child(win_title)
	var win_text = Label.new()
	win_text.text = "The porch light is still on.\nFor tonight, the road is behind you."
	win_box.add_child(win_text)
	_button(win_box,"BACK TO THE START",_leave)
	outcome.visible = false

func _label(parent: Node, text: String, pos: Vector2, size: int) -> Label:
	var label = Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size",size)
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _start_solo() -> void:
	var mic_enabled = mic_toggle.button_pressed
	_close_network()
	mic_toggle.button_pressed = mic_enabled
	mode = "solo"
	players = {1:chosen_seat}
	_begin(chosen_seat)
	_toast("1 / 2 / 3  ·  switch seats while testing alone")

func _host() -> void:
	var mic_enabled = mic_toggle.button_pressed
	_close_network()
	mic_toggle.button_pressed = mic_enabled
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT,2,3)
	if error != OK:
		status.text = "Could not host. Another car may be using port %s." % PORT
		return
	multiplayer.multiplayer_peer = peer
	mode = "host"
	players = {1:chosen_seat}
	_begin(chosen_seat)
	_toast("Car hosted · share your local IP · UDP %s" % PORT)

func _join() -> void:
	var ip = address.text.strip_edges()
	if ip.is_empty():
		status.text = "Enter the host's IP address first."
		return
	var mic_enabled = mic_toggle.button_pressed
	_close_network()
	mic_toggle.button_pressed = mic_enabled
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
	_accepted.rpc_id(id,seat,car.position,car.rotation.y,won)
	_update_roster.rpc(players)

@rpc("authority","call_remote","reliable")
func _seat_denied(reason: String) -> void:
	_close_network()
	mode = "solo"
	status.text = reason

@rpc("authority","call_remote","reliable")
func _accepted(seat: int, pos: Vector3, yaw: float, complete: bool) -> void:
	_begin(seat)
	car.position = pos
	car.rotation.y = yaw
	target_position = pos
	target_yaw = yaw
	if complete: _finish()

@rpc("authority","call_remote","reliable")
func _update_roster(roster: Dictionary) -> void:
	players = roster

func _begin(seat: int) -> void:
	car.position = Vector3(0,0,18)
	car.rotation = Vector3.ZERO
	speed = 0
	controls = Vector3.ZERO
	elapsed = 0
	won = false
	running = true
	tool_on = false
	outcome.visible = false
	_set_seat(seat)
	menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _set_seat(seat: int) -> void:
	local_seat = seat
	tool_on = false
	car.select_seat(seat)

func _close_network() -> void:
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	voice.reset()
	mic_toggle.set_pressed_no_signal(false)

func _leave() -> void:
	_close_network()
	mode = "solo"
	running = false
	won = false
	speed = 0
	controls = Vector3.ZERO
	tool_on = false
	poses = [Vector3.ZERO,Vector3.ZERO,Vector3.ZERO]
	car.position = Vector3(0,0,18)
	car.rotation = Vector3.ZERO
	car.select_seat(0)
	local_seat = 0
	outcome.visible = false
	menu.visible = true
	resume_button.visible = false
	for c in action_buttons: c.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	status.text = "LAN / direct IP · 3 players · headphones recommended"

func _peer_left(id: int) -> void:
	if players.has(id):
		var seat: int = players[id]
		poses[seat] = Vector3.ZERO
		players.erase(id)
		voice.remove_peer(id)
		if seat == 0:
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
	menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F11:
			var fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)
		if event.keycode == KEY_ESCAPE and running and not won:
			menu.visible = not menu.visible
			resume_button.visible = true
			for c in action_buttons: c.visible = false
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if menu.visible else Input.MOUSE_MODE_CAPTURED
		if menu.visible or not running or won: return
		if event.keycode == KEY_M and local_seat == 1: tool_on = not tool_on
		if event.keycode == KEY_C and local_seat == 2: tool_on = not tool_on
		if mode == "solo" and event.keycode in [KEY_1,KEY_2,KEY_3]:
			_set_seat(event.keycode-KEY_1)
			players[1] = local_seat
	if event is InputEventMouseMotion and running and not menu.visible and not won:
		car.look.rotation.y = clampf(car.look.rotation.y-event.relative.x*mouse_sensitivity,-2.7,2.7)
		car.look.rotation.x = clampf(car.look.rotation.x-event.relative.y*mouse_sensitivity,-0.95,0.8)

func _physics_process(delta: float) -> void:
	if not running or won: return
	if mode == "solo" and menu.visible: return
	var input_vector = Vector3.ZERO
	if not menu.visible and local_seat == 0:
		input_vector.x = float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))-float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
		input_vector.y = float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))-float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT))
		input_vector.z = float(Input.is_physical_key_pressed(KEY_SPACE))
	if qa_mode == "join0" and running: input_vector = Vector3(1,0,0)
	if qa_mode == "join2" and running: input_vector = Vector3(1,1,0)
	if mode != "client":
		if local_seat == 0: controls = input_vector
		elif mode == "solo" or Time.get_ticks_msec()-remote_input_time > 350: controls = Vector3.ZERO
		_simulate(delta)
	else:
		car.position = car.position.lerp(target_position,1.0-exp(-delta*14))
		car.rotation.y = lerp_angle(car.rotation.y,target_yaw,1.0-exp(-delta*14))
	sync_time += delta
	if sync_time >= 0.05 and mode != "solo":
		sync_time = 0
		var pose = Vector3(car.look.rotation.x,car.look.rotation.y,float(tool_on))
		if mode == "client":
			_input_packet.rpc_id(1,input_vector,pose)
		else:
			poses[local_seat] = pose
			_snapshot.rpc(car.position,car.rotation.y,speed,steering,poses)

func _simulate(delta: float) -> void:
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
	if forest.distance_to_road(car.position) > 4.4:
		car.position = old_position
		car.rotation.y = old_yaw
		speed *= -0.12
	for end in [Vector3(-100,0,-344),Vector3(145,0,-460)]:
		if car.position.distance_to(end) < 2.5 and car.position.distance_to(end) < old_position.distance_to(end):
			car.position = old_position
			speed *= -0.12
	if car.position.distance_to(forest.destination) < 7.5:
		_finish()
		if mode == "host": _arrived.rpc()

@rpc("any_peer","call_remote","unreliable_ordered",1)
func _input_packet(input_vector: Vector3, pose: Vector3) -> void:
	if not multiplayer.is_server(): return
	var id = multiplayer.get_remote_sender_id()
	if not players.has(id) or not input_vector.is_finite() or not pose.is_finite(): return
	var seat: int = players[id]
	poses[seat] = Vector3(clampf(pose.x,-0.95,0.8),clampf(pose.y,-2.7,2.7),clampf(pose.z,0,1))
	if seat == 0:
		controls = input_vector.clamp(Vector3(-1,-1,0),Vector3.ONE)
		remote_input_time = Time.get_ticks_msec()

@rpc("authority","call_remote","unreliable_ordered",1)
func _snapshot(pos: Vector3, yaw: float, velocity: float, turn: float, head_poses: Array) -> void:
	target_position = pos
	target_yaw = yaw
	speed = velocity
	steering = turn
	poses = head_poses

@rpc("authority","call_remote","reliable")
func _arrived() -> void:
	_finish()

func _finish() -> void:
	won = true
	speed = 0
	controls = Vector3.ZERO
	tool_on = false
	outcome.visible = true
	menu.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _process(delta: float) -> void:
	elapsed += delta if running and not won else 0.0
	var camera_active = running and local_seat == 2 and tool_on and not won
	analog.set_shader_parameter("camcorder",camera_active)
	forest.ghost.visible = camera_active
	car.animate(delta,speed,steering,tool_on,elapsed)
	for seat in 3:
		if seat != local_seat:
			car.heads[seat].rotation = Vector3(poses[seat].x,poses[seat].y,0)
			car.remote_tools[seat].visible = poses[seat].z > 0.5
	cam_hud.visible = camera_active and not menu.visible
	cam_time.text = "%02d:%02d:%02d" % [int(elapsed)/3600,(int(elapsed)/60)%60,int(elapsed)%60]
	hud.visible = running and not menu.visible and not won
	room_label.visible = hud.visible
	notification.visible = hud.visible
	var hint = ["W / S  accelerate · reverse    A / D  steer    SPACE  brake", "M  unfold / lower map", "C  raise / lower camcorder"][local_seat]
	hud.text = "%s\n%s    MOUSE  look    ESC  menu" % [SEATS[local_seat],hint]
	var occupied = "SOLO TEST  ·  1 / 2 / 3 switch seats" if mode == "solo" else "%s  ·  %s/3 IN THE CAR" % ["HOST" if mode=="host" else "CONNECTED",players.size()]
	var mic_text = "MIC OFF" if not voice.enabled else ("● TRANSMITTING" if voice.active else "V · PUSH TO TALK")
	for id in voice.talking_until:
		if voice.talking_until[id] > Time.get_ticks_msec() and players.has(id): mic_text += "  /  %s SPEAKING" % SEATS[players[id]]
	room_label.text = occupied+"    |    "+mic_text
	engine_sound.pitch_scale = 0.7+absf(speed)*0.07
	engine_sound.volume_db = -14 if running else -23
	if toast_time > 0:
		toast_time -= delta
	else:
		notification.text = ""

func _toast(text: String) -> void:
	notification.text = text
	toast_time = 6.0

func _run_qa() -> void:
	# Explicit command-line QA only, never enabled in normal play.
	if qa_mode in ["host","host_remote"]:
		chosen_seat = 1 if qa_mode == "host_remote" else 0
		_host()
		await get_tree().create_timer(6).timeout
		var passed = players.size()==3
		passed = passed and (car.position.z < 16 if qa_mode=="host_remote" else is_equal_approx(car.position.z,18))
		passed = passed and voice.outputs.size() > 0
		print("QA_HOST players=",players.size()," seats=",players.values()," car_z=",car.position.z," voice_senders=",voice.outputs.size()," passed=",passed)
		if qa_mode == "host_remote":
			car.position = forest.destination
			_simulate(0.016)
		await get_tree().create_timer(5).timeout
		get_tree().quit(0 if passed else 1)
		return
	if qa_mode.begins_with("join"):
		chosen_seat = int(qa_mode.trim_prefix("join"))
		address.text = "127.0.0.1"
		_join()
		await get_tree().create_timer(2).timeout
		if chosen_seat == 2 and running:
			var packet = PackedByteArray()
			packet.resize(640)
			for i in 320: packet.encode_s16(i*2,int(sin(float(i)*0.17)*3000))
			for i in 10:
				voice._submit.rpc_id(1,packet)
				await get_tree().create_timer(0.02).timeout
		await get_tree().create_timer(5).timeout
		var passed = running and local_seat==chosen_seat and players.size()==3
		if chosen_seat == 1: passed = passed and voice.outputs.size()>0
		if chosen_seat == 0: passed = passed and won
		print("QA_CLIENT running=",running," seat=",local_seat," roster=",players.size()," received_voice=",voice.outputs.size()," won=",won," passed=",passed)
		await get_tree().create_timer(2).timeout
		get_tree().quit(0 if passed else 1)
		return
	_start_solo()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await get_tree().create_timer(1.0).timeout
	if qa_mode == "route":
		var route = PackedVector3Array()
		for index in [0,1,3]: route.append_array(forest.roads[index])
		var nearest = 0
		var best = 1000.0
		for i in range(0,100):
			var d = car.position.distance_to(route[i])
			if d < best:
				best = d
				nearest = i
		for step in 24000:
			while nearest < route.size()-1 and car.position.distance_to(route[nearest]) < 8:
				nearest += 1
			var direction = (route[nearest]-car.position).normalized()
			var angle = (-car.basis.z).signed_angle_to(direction,Vector3.UP)
			controls = Vector3(1 if speed<5 else 0,clampf(angle*1.6,-1,1),0)
			_simulate(1.0/60)
			if won: break
		print("QA_ROUTE won=",won," endpoint=",car.position," target_sample=",nearest,"/",route.size())
		get_tree().quit(0 if won else 1)
		return
	if qa_mode == "smoke":
		var initial = car.position
		controls = Vector3(1,0,0)
		for i in 120: _simulate(1.0/60)
		assert(car.position.z < initial.z-5,"Car must move forward")
		controls = Vector3(0,0,1)
		for i in 120: _simulate(1.0/60)
		assert(absf(speed)<0.01,"Brake must stop the car")
		car.position = Vector3(-100,0,-339)
		car.rotation.y = 0
		controls = Vector3(1,0,0)
		for i in 180: _simulate(1.0/60)
		assert(car.position.z > -342,"Dead-end barrier must stop forward travel")
		controls = Vector3(-1,0,0)
		for i in 180: _simulate(1.0/60)
		assert(car.position.z > -340,"Driver must be able to reverse away from a dead end")
		_set_seat(1)
		tool_on = true
		car.animate(1,0,0,true,0)
		assert(car.map_prop.visible,"Navigator map must rise")
		_set_seat(2)
		tool_on = true
		_process(0.1)
		assert(forest.ghost.visible,"Camcorder reveals apparition")
		car.position = forest.destination
		_simulate(0.016)
		assert(won,"Destination must finish the session")
		print("QA_SMOKE PASSED: movement, brakes, dead-end blocking/reverse, map, camcorder, destination")
		get_tree().quit()
		return
	var directory = OS.get_environment("SINTRA_QA_OUTPUT")
	if directory.is_empty(): directory = "user://"
	for seat in 3:
		_set_seat(seat)
		tool_on = seat != 0
		if seat == 2: car.look.rotation.y = -0.25
		await get_tree().create_timer(1).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(directory.path_join("seat_%s.png" % seat))
	_set_seat(0)
	car.position = forest.roads[0][130]
	var forward = (forest.roads[0][131]-car.position).normalized()
	car.rotation.y = atan2(-forward.x,-forward.z)
	toast_time = 0
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("curve.png"))
	menu.visible = true
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(directory.path_join("menu.png"))
	print("QA_SCREENSHOTS saved to ",directory," fps=",Engine.get_frames_per_second())
	get_tree().quit()
