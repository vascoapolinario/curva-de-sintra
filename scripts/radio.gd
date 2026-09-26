extends Node
const STATIONS = ["87.6 FM · Estrada","92.3 FM · Nocturno","104.8 FM · Frequência"]
const FREQUENCIES = ["87.6","92.3","104.8"]
const FOLDERS = ["01_estrada","02_nocturno","03_frequencia"]
const DEFAULT_FILES = ["midnight_orchard.wav","last_tram.wav","DoYouRememberTheDays-Game.wav"]
var game: Node
var station = 0
var volume = 0.4
var power = true
var epoch = 0.0
var player: AudioStreamPlayer3D
var tuner: AudioStreamPlayer3D
var playlists: Array = []
var current_track = -1
var current_station = -1
var sync_timer = 0.0
var knob_angles = Vector2.ZERO

func setup(owner_game: Node) -> void:
	game = owner_game
	for i in 3:
		var files: Array = []
		var directory = "res://assets/radio/"+FOLDERS[i]
		for file in DirAccess.get_files_at(directory):
			var clean = file.trim_suffix(".remap")
			if clean.get_extension().to_lower() in ["wav","mp3","ogg"] and not directory.path_join(clean) in files:
				files.append(directory.path_join(clean))
		files.sort()
		if files.is_empty(): files.append("res://assets/radio/"+DEFAULT_FILES[i])
		var tracks: Array = []
		for file in files:
			var stream = load(file) as AudioStream
			if stream and stream.get_length()>0: tracks.append({"stream":stream,"title":file.get_file().get_basename().replace("_"," ").capitalize()})
		playlists.append(tracks)
	player = AudioStreamPlayer3D.new()
	player.position = Vector3(0.1,0.85,-0.43)
	player.bus = "Radio"
	player.max_distance = 8
	player.unit_size = 2
	player.panning_strength = 0.3
	game.car.add_child(player)
	tuner = AudioStreamPlayer3D.new()
	tuner.position = player.position
	tuner.bus = "Radio"
	tuner.stream = load("res://assets/radio/tuning.wav")
	tuner.volume_db = -12
	game.car.add_child(tuner)
	var bus = AudioServer.get_bus_index("Radio")
	if AudioServer.get_bus_effect_count(bus)==0:
		var low = AudioEffectLowPassFilter.new()
		low.cutoff_hz = 4200
		AudioServer.add_bus_effect(bus,low)
		var high = AudioEffectHighPassFilter.new()
		high.cutoff_hz = 220
		AudioServer.add_bus_effect(bus,high)

func station_name() -> String:
	return STATIONS[station]

func track_name() -> String:
	if not power: return "Radio off"
	if current_track < 0: return "Tuning…"
	return playlists[station][current_track].title

func apply_state(new_station: int, new_volume: float, on: bool, start_time: float) -> void:
	if station != new_station and game.running and DisplayServer.get_name() != "headless": tuner.play()
	station = clampi(new_station,0,2)
	volume = clampf(new_volume,0,1)
	power = on
	epoch = start_time
	update_playback(true)
	pass

func _process(delta: float) -> void:
	if not player: return
	player.volume_db = linear_to_db(maxf(volume,0.0001))-4
	knob_angles=knob_angles.lerp(Vector2(volume*4.2-2.1,station*1.4-1.4),1.0-exp(-delta*16.0))
	# Tilt the shaft into the dashboard, then spin around its local axis.
	for i in 2:
		game.car.radio_knobs[i].basis=Basis(Vector3.RIGHT,PI/2)*Basis(Vector3.UP,knob_angles[i])
	game.car.radio_display.text = "FM  "+FREQUENCIES[station] if power else "— — —"
	if not game.running or not power or game.won or game.lost:
		player.stop()
		return
	sync_timer += delta
	if sync_timer > 0.5:
		sync_timer = 0
		update_playback(false)

func update_playback(force: bool) -> void:
	if not game.running or game.won or game.lost or not power or playlists[station].is_empty(): return
	var tracks: Array = playlists[station]
	var total = 0.0
	for track in tracks: total += track.stream.get_length()
	var offset = fposmod(maxf(0,game.elapsed-epoch),total)
	var index = 0
	while offset >= tracks[index].stream.get_length() and index < tracks.size()-1:
		offset -= tracks[index].stream.get_length()
		index += 1
	var changed = station != current_station or index != current_track
	current_station = station
	current_track = index
	if DisplayServer.get_name()=="headless": return
	if changed or not player.playing:
		player.stream = tracks[index].stream
		player.play(offset)
	elif force and absf(player.get_playback_position()-offset)>1.0:
		player.seek(offset)
	pass
