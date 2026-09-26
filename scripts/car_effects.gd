extends Node
## Shared driver controls and host-directed environmental sounds.
const CUES = ["owl.wav","fox.wav","branches.wav","forest_steps.wav","tree_creak.wav"]
var game: Node
var headlights = true
var honking = false
var last_sent_horn = false
var heartbeat = 0.0
var horn_received_at = 0
var horn: AudioStreamPlayer3D
var switch_sound: AudioStreamPlayer3D
var dread: AudioStreamPlayer
var lights: Array[SpotLight3D] = []
var next_cue = 17.0
var hush = 0.0
var rng = RandomNumberGenerator.new()
var cue_count = 0
var previous_cue = -1

func setup(owner_game: Node) -> void:
	game=owner_game
	rng.randomize()
	for node in game.car.get_children():
		if node is SpotLight3D: lights.append(node)
	horn=AudioStreamPlayer3D.new()
	horn.stream=_loop("res://assets/car_horn.wav")
	horn.position=Vector3(0,0.8,-1.8)
	horn.bus="Engine"
	horn.unit_size=5
	horn.max_distance=90
	horn.volume_db=-9
	game.car.add_child(horn)
	switch_sound=AudioStreamPlayer3D.new()
	switch_sound.stream=load("res://assets/light_switch.wav")
	switch_sound.position=Vector3(-0.5,1,-0.4)
	switch_sound.volume_db=-14
	switch_sound.bus="Engine"
	game.car.add_child(switch_sound)
	dread=AudioStreamPlayer.new()
	dread.stream=_loop("res://assets/forest_dread.wav")
	dread.bus="Ambience"
	dread.volume_db=-34
	add_child(dread)

func _loop(path: String) -> AudioStreamWAV:
	var stream=load(path) as AudioStreamWAV
	stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	stream.loop_end=int(stream.get_length()*stream.mix_rate)
	return stream

func reset() -> void:
	last_sent_horn=false
	heartbeat=0
	next_cue=rng.randf_range(14,24)
	hush=0
	previous_cue=-1
	_apply(true,false,false)
	game.wildlife.stop()
	dread.stop()
	game.forest_sound.volume_db=-9

func request_lights() -> void:
	if not _can_drive(): return
	if game.mode=="client": _driver_request.rpc_id(1,"lights",not headlights)
	else: _commit(not headlights,honking)

func request_horn(held: bool) -> void:
	if held and not _can_drive(): return
	if game.local_seat!=0: return
	if game.mode=="client": _driver_request.rpc_id(1,"horn",held)
	else: _commit(headlights,held)

func _can_drive() -> bool:
	return game.running and game.local_seat==0 and not game.input_blocked()

@rpc("any_peer","call_remote","reliable")
func _driver_request(control: String, active: bool) -> void:
	if not multiplayer.is_server() or not game.running or game.won or game.lost: return
	if game.players.get(multiplayer.get_remote_sender_id(),-1)!=0: return
	if control=="lights": _commit(active,honking)
	elif control=="horn":
		horn_received_at=Time.get_ticks_msec()
		_commit(headlights,active)

func _commit(on: bool, sounding: bool) -> void:
	if on==headlights and sounding==honking: return
	_apply(on,sounding)
	if game.mode=="host": _state.rpc(on,sounding)

@rpc("authority","call_remote","reliable")
func _state(on: bool, sounding: bool) -> void:
	_apply(on,sounding and not game.won and not game.lost)

func _apply(on: bool, sounding: bool, click: bool = true) -> void:
	if headlights!=on and click and DisplayServer.get_name()!="headless": switch_sound.play()
	headlights=on
	honking=sounding
	for light in lights: light.visible=on
	if sounding:
		if not horn.playing and DisplayServer.get_name()!="headless": horn.play()
	else: horn.stop()

func sync_peer(id: int) -> void:
	_state.rpc_id(id,headlights,honking)

func release_driver() -> void:
	if game.mode!="client": _commit(headlights,false)

func stop() -> void:
	last_sent_horn=false
	if game.mode!="client": _commit(headlights,false)
	else: _apply(headlights,false,false)
	dread.stop()
	game.wildlife.stop()

func _process(delta: float) -> void:
	if not game: return
	var active: bool = game.running and not game.won and not game.lost
	var focused = DisplayServer.get_name()=="headless" or DisplayServer.window_is_focused()
	var held: bool = active and _can_drive() and focused and Input.is_action_pressed("horn")
	heartbeat+=delta
	if held!=last_sent_horn or (held and heartbeat>=0.2):
		request_horn(held)
		last_sent_horn=held
		heartbeat=0
	if game.mode=="host" and game.local_seat!=0 and honking and Time.get_ticks_msec()-horn_received_at>900:
		_commit(headlights,false)
	if not active:
		if honking: stop()
		dread.stop()
		return
	var paused: bool = game.mode=="solo" and game.menu.visible
	dread.stream_paused=paused
	game.wildlife.stream_paused=paused
	if paused: return
	if not dread.playing and DisplayServer.get_name()!="headless": dread.play()
	var tension: float = clampf(game.elapsed/900.0,0,1)
	var darkness=0.0 if headlights else 3.0
	dread.volume_db=lerpf(dread.volume_db,-34+tension*7+darkness,1-exp(-delta*0.4))
	hush=maxf(0,hush-delta)
	game.forest_sound.volume_db=lerpf(game.forest_sound.volume_db,-19.0 if hush>0 else -9.0,1-exp(-delta*0.6))
	if game.mode=="client": return
	next_cue-=delta
	if next_cue>0: return
	next_cue=rng.randf_range(27,49)-tension*6
	var which=rng.randi_range(0,CUES.size()-1)
	if which==previous_cue: which=(which+1)%CUES.size()
	previous_cue=which
	var angle=rng.randf()*TAU
	var distance=rng.randf_range(19,42) if which<3 else rng.randf_range(11,20)
	var pos: Vector3 = game.car.global_position+Vector3(cos(angle)*distance,1.5,sin(angle)*distance)
	var pitch=rng.randf_range(0.87,1.03)
	_cue(which,pos,pitch)
	if game.mode=="host": _cue.rpc(which,pos,pitch)

@rpc("authority","call_remote","reliable")
func _cue(which: int, pos: Vector3, pitch: float) -> void:
	if not game.running or game.won or game.lost: return
	if which<0 or which>=CUES.size() or not pos.is_finite(): return
	game.wildlife.global_position=pos
	game.wildlife.stream=load("res://assets/"+CUES[which])
	game.wildlife.pitch_scale=clampf(pitch,0.8,1.1)
	game.wildlife.volume_db=-12 if which<3 else -16
	game.wildlife.stream_paused=false
	hush=7.0
	cue_count+=1
	if DisplayServer.get_name()!="headless": game.wildlife.play()
