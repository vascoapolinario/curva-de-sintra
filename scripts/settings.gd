extends Node
signal changed
const FILE = "user://settings.cfg"
const DEFAULTS = {"window_mode":0,"resolution":0,"vsync":true,"fps_limit":120,"shadows":true,"view_distance":200.0,"fov":78.0,"exposure":1.12,"grain":0.027,"pixels":1.5,"scanlines":true,"master":0.85,"engine":0.8,"ambience":0.8,"radio":0.7,"output_device":"Default","mute_unfocused":false,"sensitivity":0.0022,"invert_y":false,"invert_x":false,"sway":0.65,"controller_speed":2.0,"deadzone":0.18,"ui_scale":1.0,"contrast":false,"prompts":true}
const ACTIONS = {"accelerate":KEY_W,"reverse":KEY_S,"left":KEY_A,"right":KEY_D,"seat_driver":KEY_1,"seat_navigator":KEY_2,"seat_camera":KEY_3}
const ACTION_NAMES = {"accelerate":"Accelerate","reverse":"Brake / reverse","left":"Steer left","right":"Steer right","seat_driver":"Driver seat","seat_navigator":"Navigator seat","seat_camera":"Rear seat"}
const RESOLUTIONS = [Vector2i(1280,720),Vector2i(1600,900),Vector2i(1920,1080),Vector2i(2560,1440)]
var values = DEFAULTS.duplicate()
var bindings = ACTIONS.duplicate()
var display_revision=0

func _ready() -> void:
	for name in ["Engine","Ambience","Radio"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,name)
	var cfg = ConfigFile.new()
	if cfg.load(FILE) == OK:
		for key in DEFAULTS: values[key] = cfg.get_value("settings",key,DEFAULTS[key])
		for action in ACTIONS: bindings[action] = cfg.get_value("keys",action,ACTIONS[action])
	_install_actions()
	apply()

func set_value(key: String, value: Variant) -> void:
	values[key] = value
	apply()
	changed.emit()

func save() -> void:
	var cfg = ConfigFile.new()
	for key in values: cfg.set_value("settings",key,values[key])
	for action in bindings: cfg.set_value("keys",action,bindings[action])
	cfg.save(FILE)

func reset_defaults() -> void:
	values = DEFAULTS.duplicate()
	bindings = ACTIONS.duplicate()
	_install_actions()
	apply()
	changed.emit()

func apply() -> void:
	for entry in [["Master","master"],["Engine","engine"],["Ambience","ambience"],["Radio","radio"]]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(entry[0]),linear_to_db(maxf(float(values[entry[1]]),0.0001)))
	AudioServer.output_device = values.output_device if values.output_device in AudioServer.get_output_device_list() else "Default"
	Engine.max_fps = int(values.fps_limit)
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
	for action in ACTIONS: InputMap.action_set_deadzone(action,float(values.deadzone))

func apply_display() -> void:
	if DisplayServer.get_name() == "headless": return
	display_revision+=1
	var revision=display_revision
	var window=get_tree().root
	var screen=window.current_screen
	var requested: Vector2i=RESOLUTIONS[clampi(values.resolution,0,RESOLUTIONS.size()-1)]
	# Use Window properties so its layout stays in step with the native window.
	# Let the OS finish leaving fullscreen before applying a new window size.
	if window.mode!=Window.MODE_WINDOWED:
		window.mode=Window.MODE_WINDOWED
		await get_tree().process_frame
		await get_tree().process_frame
	if revision!=display_revision: return
	window.borderless=values.window_mode==1
	if values.window_mode==2:
		window.mode=Window.MODE_FULLSCREEN
	elif values.window_mode==1:
		window.size=DisplayServer.screen_get_size(screen)
		window.position=DisplayServer.screen_get_position(screen)
	else:
		window.size=requested
		var usable=DisplayServer.screen_get_usable_rect(screen)
		window.position=usable.position+(usable.size-window.size)/2
	await get_tree().process_frame
	await get_tree().process_frame
	if revision!=display_revision: return
	# Fullscreen stays monitor-sized; resolution controls the scene's pixel count.
	# UI coordinates remain 1280 x 720, keeping every menu and button aligned.
	window.scaling_3d_scale=1.0 if values.window_mode==0 else clampf(float(requested.x)/maxi(1,window.size.x),0.25,2.0)

func bind_key(action: String, key: int) -> void:
	var previous: int = bindings[action]
	for other in bindings:
		if other != action and bindings[other] == key: bindings[other] = previous
	bindings[action] = key
	_install_actions()
	save()
	changed.emit()

func _install_actions() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event = InputEventKey.new()
		event.physical_keycode = bindings[action]
		InputMap.action_add_event(action,event)
	for pair in [["accelerate",KEY_UP],["reverse",KEY_DOWN],["left",KEY_LEFT],["right",KEY_RIGHT]]:
		var event = InputEventKey.new()
		event.physical_keycode = pair[1]
		InputMap.action_add_event(pair[0],event)
	for entry in [["accelerate",JOY_AXIS_TRIGGER_RIGHT,1.0],["reverse",JOY_AXIS_TRIGGER_LEFT,1.0],["left",JOY_AXIS_LEFT_X,-1.0],["right",JOY_AXIS_LEFT_X,1.0]]:
		var event = InputEventJoypadMotion.new()
		event.axis = entry[1]
		event.axis_value = entry[2]
		InputMap.action_add_event(entry[0],event)

func _process(_delta: float) -> void:
	if DisplayServer.get_name() != "headless":
		AudioServer.set_bus_mute(0,values.mute_unfocused and not DisplayServer.window_is_focused())
