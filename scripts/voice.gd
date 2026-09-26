extends Node
## Opt-in push-to-talk. 16 kHz mono PCM, server-relayed over ENet channel 2.
## The muted capture bus prevents local microphone feedback.
const RATE = 16000
const PACKET_FRAMES = 320
var enabled = false
var capture: AudioEffectCapture
var microphone: AudioStreamPlayer
var outputs: Dictionary = {}
var queues: Dictionary = {}
var talking_until: Dictionary = {}
var last_packet: Dictionary = {}
var game: Node
var active = false
var input_level = 0.0

func enable_microphone(value: bool) -> void:
	enabled = value
	if not value:
		if microphone: microphone.stop()
		if capture: capture.clear_buffer()
		return
	if not microphone:
		var bus = AudioServer.get_bus_index("VoiceCapture")
		if bus < 0:
			AudioServer.add_bus()
			bus = AudioServer.bus_count-1
			AudioServer.set_bus_name(bus,"VoiceCapture")
			capture = AudioEffectCapture.new()
			capture.buffer_length = 0.2
			AudioServer.add_bus_effect(bus,capture)
			AudioServer.set_bus_mute(bus,true)
		else:
			capture = AudioServer.get_bus_effect(bus,0)
		microphone = AudioStreamPlayer.new()
		microphone.stream = AudioStreamMicrophone.new()
		microphone.bus = "VoiceCapture"
		add_child(microphone)
	microphone.play()

func _process(_delta: float) -> void:
	active = enabled and game.running and not game.input_blocked() and (Input.is_action_pressed("talk") or game.prefs.values.voice_mode==1)
	input_level = move_toward(input_level,0,_delta*1.5)
	if enabled and capture:
		var input_frames = int(AudioServer.get_mix_rate()*0.02)
		var batches = 0
		while capture.can_get_buffer(input_frames) and batches < 5:
			batches += 1
			var samples = capture.get_buffer(input_frames)
			var peak = 0.0
			for frame in samples: peak = maxf(peak,absf(frame.x)*game.prefs.values.mic_gain)
			input_level = maxf(input_level,peak)
			if not active or game.mode == "solo" or peak < game.prefs.values.noise_gate: continue
			var packet = PackedByteArray()
			packet.resize(PACKET_FRAMES*2)
			for i in PACKET_FRAMES:
				# Box-filter downsampling, avoiding a raw sample-rate mismatch.
				var from = int(float(i)*input_frames/PACKET_FRAMES)
				var to = maxi(from+1,int(float(i+1)*input_frames/PACKET_FRAMES))
				var sample = 0.0
				for j in range(from,to): sample += (samples[j].x+samples[j].y)*0.5
				sample *= game.prefs.values.mic_gain/float(to-from)
				packet.encode_s16(i*2,int(clampf(sample,-1,1)*32767))
			if multiplayer.is_server():
				_deliver.rpc(multiplayer.get_unique_id(),packet)
			else:
				_submit.rpc_id(1,packet)
	for id in queues.keys():
		var playback: AudioStreamGeneratorPlayback = outputs[id].get_stream_playback()
		var queue: PackedVector2Array = queues[id]
		if queue.size() < PACKET_FRAMES: continue
		var count = mini(playback.get_frames_available(),queue.size())
		if count > 0:
			playback.push_buffer(queue.slice(0,count))
			queues[id] = queue.slice(count)

@rpc("any_peer","call_remote","unreliable_ordered",2)
func _submit(packet: PackedByteArray) -> void:
	if not multiplayer.is_server(): return
	var sender = multiplayer.get_remote_sender_id()
	if not game.players.has(sender) or packet.size() != PACKET_FRAMES*2: return
	var now = Time.get_ticks_msec()
	if now-int(last_packet.get(sender,0)) < 10: return
	last_packet[sender] = now
	_receive(sender,packet)
	_deliver.rpc(sender,packet)

@rpc("authority","call_remote","unreliable_ordered",2)
func _deliver(sender: int, packet: PackedByteArray) -> void:
	if sender == multiplayer.get_unique_id(): return
	if packet.size() != PACKET_FRAMES*2 or not game.players.has(sender): return
	_receive(sender,packet)

func _receive(sender: int, packet: PackedByteArray) -> void:
	if not outputs.has(sender):
		var output = AudioStreamPlayer.new()
		var stream = AudioStreamGenerator.new()
		stream.mix_rate = RATE
		stream.buffer_length = 0.16
		output.stream = stream
		output.bus = "Voice"
		add_child(output)
		output.play()
		outputs[sender] = output
		queues[sender] = PackedVector2Array()
	var frames = PackedVector2Array()
	frames.resize(PACKET_FRAMES)
	for i in PACKET_FRAMES: frames[i] = Vector2.ONE*float(packet.decode_s16(i*2))/32767.0
	var queue: PackedVector2Array = queues[sender]
	if queue.size() > RATE/5: queue = PackedVector2Array()
	queue.append_array(frames)
	queues[sender] = queue
	talking_until[sender] = Time.get_ticks_msec()+200

func remove_peer(id: int) -> void:
	if outputs.has(id):
		outputs[id].stop()
		outputs[id].queue_free()
		outputs.erase(id)
	queues.erase(id)
	talking_until.erase(id)
	last_packet.erase(id)

func reset() -> void:
	for id in outputs.keys(): remove_peer(id)
	enable_microphone(false)
