extends Node
## Driver controls and positional environmental sounds.
const CUES = ["owl.wav","fox.wav","branches.wav","forest_steps.wav","tree_creak.wav"]
var game: Node
var headlights = true
var honking = false
var last_sent_horn = false
var impact: AudioStreamPlayer3D
var impact_cooldown=0.0
var impact_count=0
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
	impact=AudioStreamPlayer3D.new()
	impact.stream=load("res://assets/barrier_impact.wav")
	impact.position=Vector3(0,0.7,-1.1)
	impact.bus="Engine"
	impact.unit_size=3
	impact.max_distance=35
	game.car.add_child(impact)
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
	impact_cooldown=0
	impact.stop()
	last_sent_horn=false
	next_cue=rng.randf_range(14,24)
	hush=0
	previous_cue=-1
	_apply(true,false,false)
	game.wildlife.stop()
	dread.stop()
	game.forest_sound.volume_db=-9

func request_lights() -> void:
	if not _can_drive(): return
	_commit(not headlights,honking)

func request_horn(held: bool) -> void:
	if held and not _can_drive(): return
	if game.local_seat!=0: return
	_commit(headlights,held)

func _can_drive() -> bool:
	return game.running and game.local_seat==0 and not game.input_blocked()

func _commit(on: bool, sounding: bool) -> void:
	if on==headlights and sounding==honking: return
	_apply(on,sounding)

func _apply(on: bool, sounding: bool, click: bool = true) -> void:
	if headlights!=on and click and DisplayServer.get_name()!="headless": switch_sound.play()
	headlights=on
	honking=sounding
	for light in lights: light.visible=on
	if sounding:
		if not horn.playing and DisplayServer.get_name()!="headless": horn.play()
	else: horn.stop()

func release_driver() -> void:
	_commit(headlights,false)

func stop() -> void:
	last_sent_horn=false
	_commit(headlights,false)
	dread.stop()
	game.wildlife.stop()

func _process(delta: float) -> void:
	impact_cooldown=maxf(0,impact_cooldown-delta)
	if not game: return
	var active: bool = game.running and not game.won and not game.lost
	var focused = DisplayServer.get_name()=="headless" or DisplayServer.window_is_focused()
	if not focused or game.input_blocked(): game.horn_pressed=false
	var held: bool = active and _can_drive() and focused and game.horn_pressed
	if held!=last_sent_horn:
		request_horn(held)
		last_sent_horn=held
	if not active:
		if honking: stop()
		dread.stop()
		return
	var paused: bool = game.menu.visible
	dread.stream_paused=paused
	game.wildlife.stream_paused=paused
	if paused: return
	if not dread.playing and DisplayServer.get_name()!="headless": dread.play()
	var tension: float = clampf(game.elapsed/900.0,0,1)
	var darkness=0.0 if headlights else 3.0
	var area: float=game.forest.woodland.tension
	dread.volume_db=lerpf(dread.volume_db,-37+tension*4+darkness+area*8,1-exp(-delta*0.4))
	hush=maxf(0,hush-delta)
	game.forest_sound.volume_db=lerpf(game.forest_sound.volume_db,-19.0 if hush>0 else -9.0-area*4,1-exp(-delta*0.6))
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

func barrier_hit(speed: float) -> void:
	if impact_cooldown>0 or absf(speed)<0.45 or game.input_blocked(): return
	impact_cooldown=0.65
	impact_count+=1
	impact.volume_db=lerpf(-23,-13,clampf(absf(speed)/11.5,0,1))
	impact.pitch_scale=rng.randf_range(0.92,1.05)
	if DisplayServer.get_name()!="headless": impact.play()
