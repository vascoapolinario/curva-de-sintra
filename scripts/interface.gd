extends Control
var game: Node
var prefs: Node
var panel: Control
var page: Control
var reticle: Control
var backdrop: ColorRect
var rebinding = ""
var bind_buttons: Dictionary = {}
var display_dialog: ConfirmationDialog
var old_display: Array = []
var display_remaining = 0.0
var display_busy=false
var controls_theme: Theme

func setup(owner_game: Node) -> void:
	game = owner_game
	prefs = game.prefs
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_theme()
	var filter = ColorRect.new()
	filter.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	filter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.analog = ShaderMaterial.new()
	game.analog.shader = load("res://shaders/analog.gdshader")
	filter.material = game.analog
	add_child(filter)
	game.hud = label(self,"",16)
	game.hud.position = Vector2(0,406)
	game.hud.size.x = 1280
	game.hud.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	game.cam_hud = Control.new()
	game.cam_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game.cam_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(game.cam_hud)
	var rec = label(game.cam_hud,"● REC",21)
	rec.position = Vector2(135,76)
	rec.modulate = Color("d98066")
	label(game.cam_hud,"SP   ▰▰▰▱",18).position = Vector2(1010,76)
	label(game.cam_hud,"25.09.1996",16).position = Vector2(135,611)
	game.cam_time = label(game.cam_hud,"",18)
	game.cam_time.position = Vector2(1010,611)
	# An optical viewfinder matte; the camcorder body disappears from the operator's view.
	for rect in [Rect2(0,0,1280,46),Rect2(0,674,1280,46),Rect2(0,46,90,628),Rect2(1190,46,90,628)]:
		var matte = ColorRect.new()
		matte.position = rect.position
		matte.size = rect.size
		matte.color = Color(0.008,0.013,0.011,0.94)
		matte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		game.cam_hud.add_child(matte)
	game.cam_hud.visible = false
	reticle=Control.new()
	reticle.mouse_filter=Control.MOUSE_FILTER_IGNORE
	reticle.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	add_child(reticle)
	var dot=ColorRect.new()
	dot.position=Vector2(-2,-2)
	dot.size=Vector2(4,4)
	dot.color=Color("d9c19a")
	dot.mouse_filter=Control.MOUSE_FILTER_IGNORE
	reticle.add_child(dot)
	reticle.visible=false
	panel = Control.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(panel)
	game.menu = panel
	var shade = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color.WHITE
	var atmosphere=ShaderMaterial.new()
	atmosphere.shader=load("res://shaders/menu.gdshader")
	shade.material=atmosphere
	backdrop=shade
	panel.add_child(shade)
	page = Control.new()
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(page)
	game.outcome = Control.new()
	game.outcome.visible = false
	add_child(game.outcome)
	display_dialog = ConfirmationDialog.new()
	display_dialog.title = "Display settings"
	display_dialog.ok_button_text = "Keep changes"
	display_dialog.cancel_button_text = "Revert"
	display_dialog.confirmed.connect(_keep_display)
	display_dialog.canceled.connect(_revert_display)
	add_child(display_dialog)
	show_title()

func _build_theme() -> void:
	controls_theme=Theme.new()
	var font=SystemFont.new()
	font.font_names=PackedStringArray(["Tahoma","Arial"])
	controls_theme.default_font=font
	controls_theme.default_font_size=int(16*prefs.values.ui_scale)
	var ink=Color("c6c9c5")
	var gold=Color("f0f0e9")
	for type in ["Label","Button","CheckButton","OptionButton","TabContainer","LineEdit","PopupMenu"]:
		controls_theme.set_color("font_color",type,ink)
		controls_theme.set_color("font_hover_color",type,Color("ffffff"))
		controls_theme.set_color("font_focus_color",type,gold)
		controls_theme.set_color("font_pressed_color",type,gold)
	for type in ["Button","OptionButton","LineEdit","TabContainer","PanelContainer","CheckButton","PopupMenu"]:
		for state in ["normal","hover","pressed","focus","panel","tab_selected","tab_unselected","tab_hovered"]:
			var box=StyleBoxFlat.new()
			box.bg_color=Color(0.08,0.10,0.09,0.9) if state in ["hover","pressed","tab_selected","tab_hovered"] else Color(0.02,0.03,0.028,0.4)
			box.border_color=Color(0.55,0.49,0.36,0.45)
			box.border_width_bottom=1
			if state=="focus":
				box.bg_color=Color(0,0,0,0)
				box.border_color=gold
				box.border_width_left=2
			box.content_margin_left=18
			box.content_margin_right=18
			box.content_margin_top=12
			box.content_margin_bottom=12
			if type=="Button":
				box.bg_color=Color.TRANSPARENT
				box.set_border_width_all(0)
				box.content_margin_left=0
				box.content_margin_right=12
			controls_theme.set_stylebox(state,type,box)
	for state in ["slider","grabber_area","grabber_area_highlight"]:
		var line=StyleBoxFlat.new()
		line.bg_color=Color("968363") if state!="slider" else Color("303b35")
		line.content_margin_top=2
		line.content_margin_bottom=2
		controls_theme.set_stylebox(state,"HSlider",line)
	for state in ["grabber","grabber_highlight","grabber_disabled"]:
		controls_theme.set_icon(state,"HSlider",load("res://assets/ui/slider.svg"))
	for state in ["checked","checked_disabled","checked_mirrored","checked_disabled_mirrored"]: controls_theme.set_icon(state,"CheckButton",load("res://assets/ui/on.svg"))
	for state in ["unchecked","unchecked_disabled","unchecked_mirrored","unchecked_disabled_mirrored"]: controls_theme.set_icon(state,"CheckButton",load("res://assets/ui/off.svg"))
	for state in ["scroll","scroll_focus","grabber","grabber_highlight","grabber_pressed"]:
		var rail=StyleBoxFlat.new()
		rail.bg_color=Color("756b55") if state.begins_with("grabber") else Color("111a16")
		rail.content_margin_left=4
		rail.content_margin_right=4
		controls_theme.set_stylebox(state,"VScrollBar",rail)
	controls_theme.set_color("font_selected_color","TabContainer",gold)
	controls_theme.set_color("font_unselected_color","TabContainer",Color("878d81"))
	controls_theme.set_constant("h_separation","TabContainer",24)
	theme=controls_theme

func label(parent: Node, text: String, font_size: int = 16) -> Label:
	var n = Label.new()
	n.text = text
	n.add_theme_font_size_override("font_size",int(font_size*prefs.values.ui_scale))
	parent.add_child(n)
	return n

func button(parent: Node, text: String, callback: Callable) -> Button:
	var n = Button.new()
	n.text = text
	n.alignment = HORIZONTAL_ALIGNMENT_LEFT
	n.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	n.custom_minimum_size.y=40
	n.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN
	n.add_theme_color_override("font_color",Color("a9ada7"))
	n.add_theme_color_override("font_hover_color",Color("ffffff"))
	n.add_theme_color_override("font_focus_color",Color("ffffff"))
	n.add_theme_color_override("font_pressed_color",Color("8b9288"))
	n.add_theme_color_override("font_shadow_color",Color(0,0,0,0.9))
	n.add_theme_constant_override("shadow_offset_x",1)
	n.add_theme_constant_override("shadow_offset_y",2)
	n.pressed.connect(callback)
	parent.add_child(n)
	return n

func _clear() -> void:
	for child in page.get_children():
		page.remove_child(child)
		child.queue_free()
	rebinding = ""
	bind_buttons.clear()
	panel.visible = true
	if backdrop: backdrop.material.set_shader_parameter("settings_page",false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _column(title: String, subtitle: String = "") -> VBoxContainer:
	_clear()
	var col = VBoxContainer.new()
	col.position = Vector2(100,100)
	col.size = Vector2(460,520)
	col.add_theme_constant_override("separation",12)
	page.add_child(col)
	var heading = label(col,title,30)
	heading.add_theme_color_override("font_color",Color("d4d7d0"))
	if not subtitle.is_empty(): label(col,subtitle,15).modulate = Color("a6ad99")
	var spacer = Control.new()
	spacer.custom_minimum_size.y = 15
	col.add_child(spacer)
	return col

func show_title() -> void:
	_clear()
	var title=label(page,"Curva de Sintra",34)
	title.position=Vector2(76,68)
	title.add_theme_color_override("font_color",Color("d4d7d0"))
	title.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	title.add_theme_constant_override("shadow_offset_y",2)
	var col=VBoxContainer.new()
	col.position=Vector2(80,408)
	col.size=Vector2(380,230)
	col.add_theme_constant_override("separation",5)
	page.add_child(col)
	button(col,"Play",func(): game.chosen_seat=0; game._start_game())
	button(col,"Settings",show_settings)
	button(col,"Quit",func(): game.get_tree().quit())
	game.status=label(col,"",15)
	game.status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART

func show_pause() -> void:
	var col = _column("Paused")
	button(col,"Resume",game._resume)
	button(col,"Change seat",show_seats)
	button(col,"Settings",show_settings)
	button(col,"Return to title",game._leave)
	button(col,"Quit",func(): game.get_tree().quit())
	game.status = label(col,"",15)

func show_seats() -> void:
	var col = _column("Choose a seat")
	for i in 3:
		button(col,["Driver","Navigator","Camera operator"][i],func(): game._set_seat(i); game._resume())
	button(col,"Back",show_pause)

func show_settings() -> void:
	_clear()
	_build_theme()
	backdrop.material.set_shader_parameter("settings_page",true)
	var heading = label(page,"Settings",34)
	heading.position = Vector2(110,40)
	var tabs = TabContainer.new()
	tabs.position = Vector2(100,112)
	tabs.size = Vector2(1080,504)
	page.add_child(tabs)
	var display = _tab(tabs,"Display")
	_choice(display,"Display mode","window_mode",["Windowed","Borderless","Fullscreen"])
	_choice(display,"Resolution","resolution",["1280 × 720","1600 × 900","1920 × 1080","2560 × 1440"])
	label(display,"Changes preview immediately. In fullscreen, resolution adjusts image detail.",14)
	_toggle(display,"Vertical sync","vsync")
	_choice(display,"Frame limit","fps_limit",["30 fps","60 fps","120 fps","144 fps","Unlimited"],[30,60,120,144,0])
	var graphics = _tab(tabs,"Graphics")
	_toggle(graphics,"Headlight shadows","shadows")
	_slider(graphics,"View distance","view_distance",100,260,20," m")
	_slider(graphics,"Field of view","fov",60,95,1,"°")
	_slider(graphics,"Exposure","exposure",0.7,1.8,0.05)
	_slider(graphics,"Film grain","grain",0,0.07,0.005)
	_slider(graphics,"Pixel size","pixels",1,3,0.25)
	_toggle(graphics,"Scanlines","scanlines")
	var audio = _tab(tabs,"Audio")
	for pair in [["Master volume","master"],["Engine","engine"],["Ambience","ambience"],["Radio","radio"]]: _slider(audio,pair[0],pair[1],0,1,0.05,"",true)
	_device(audio,"Output device","output_device",AudioServer.get_output_device_list())
	_toggle(audio,"Mute when unfocused","mute_unfocused")
	var controls = _tab(tabs,"Controls")
	_slider(controls,"Mouse sensitivity","sensitivity",0.0008,0.006,0.0002)
	_toggle(controls,"Invert vertical look","invert_y")
	_toggle(controls,"Invert horizontal look","invert_x")
	label(controls,"Select a binding, then press a key. Escape cancels. Conflicts swap bindings.",14)
	for action in prefs.ACTIONS:
		var row = _row(controls,prefs.ACTION_NAMES[action])
		var b = button(row,OS.get_keycode_string(prefs.bindings[action]),func(): rebinding=action; bind_buttons[action].text="Press a key…")
		b.custom_minimum_size.x = 280
		bind_buttons[action] = b
	label(controls,"Hold right mouse to focus · hold left mouse to point.\nAim at a radio control or cabin lamp and click. Drag VOL right or scroll up to increase volume.",14)
	var access = _tab(tabs,"Accessibility")
	_slider(access,"Camera movement","sway",0,1,0.05,"",true)
	_choice(access,"Interface text size","ui_scale",["Standard","Large","Larger"],[1.0,1.15,1.3])
	_toggle(access,"High contrast menus","contrast")
	_toggle(access,"Interaction prompts","prompts")
	label(access,"Film grain, scanlines and exposure can be adjusted in Graphics.\nThere are no spoken story lines requiring subtitles.",15)
	var footer = HBoxContainer.new()
	footer.position = Vector2(110,640)
	footer.add_theme_constant_override("separation",18)
	page.add_child(footer)
	button(footer,"Save & return",_save_return)
	button(footer,"Restore defaults",_restore_defaults)

func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.name = title
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(scroll)
	var box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation",16)
	scroll.add_child(box)
	return box

func _row(parent: Node, title: String) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.custom_minimum_size.y = 39
	parent.add_child(row)
	var l = label(row,title)
	l.custom_minimum_size.x = 390
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return row

func _slider(parent: Node, title: String, key: String, low: float, high: float, step: float, suffix: String = "", percent: bool = false) -> void:
	var row = _row(parent,title)
	var slider = HSlider.new()
	slider.custom_minimum_size.x = 290
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = float(prefs.values[key])
	row.add_child(slider)
	var value = label(row,"",14)
	value.custom_minimum_size.x = 88
	var format = func(v): return (str(roundi(v*100))+"%") if percent else (str(snappedf(v,step))+suffix)
	value.text = format.call(slider.value)
	slider.value_changed.connect(func(v): prefs.set_value(key,v); value.text=format.call(v))

func _toggle(parent: Node, title: String, key: String) -> void:
	var row = _row(parent,title)
	var toggle = CheckButton.new()
	toggle.button_pressed = prefs.values[key]
	toggle.custom_minimum_size.x = 130
	toggle.toggled.connect(func(v): prefs.set_value(key,v))
	row.add_child(toggle)

func _choice(parent: Node, title: String, key: String, options: Array, values: Array = []) -> void:
	var row = _row(parent,title)
	var select = OptionButton.new()
	select.set_meta("setting",key)
	select.custom_minimum_size.x = 340
	for item in options: select.add_item(item)
	select.select(int(prefs.values[key]) if values.is_empty() else maxi(0,values.find(prefs.values[key])))
	select.item_selected.connect(func(i):
		if key in ["window_mode","resolution"]:
			_preview_display(key,i)
		else: prefs.set_value(key,i if values.is_empty() else values[i]))
	row.add_child(select)

func _device(parent: Node, title: String, key: String, devices: PackedStringArray) -> void:
	var list: Array = []
	for item in devices: list.append(item)
	if list.is_empty(): list.append("Default")
	_choice(parent,title,key,list,list)

func _preview_display(key: String, value: int) -> void:
	if display_busy or display_remaining>0: return
	if prefs.values[key]==value: return
	old_display=[prefs.values.window_mode,prefs.values.resolution]
	prefs.values[key]=value
	_try_display()

func _try_display() -> void:
	display_busy=true
	await prefs.apply_display()
	display_busy=false
	display_remaining=12
	display_dialog.dialog_text="Keep these display settings?\nReverting in 12 seconds."
	display_dialog.popup_centered(Vector2i(460,160))

func _keep_display() -> void:
	display_remaining=0
	display_dialog.hide()
	old_display.clear()
	prefs.save()

func _revert_display() -> void:
	if display_busy: return
	display_remaining=0
	display_dialog.hide()
	if old_display.size()==2:
		prefs.values.window_mode=old_display[0]
		prefs.values.resolution=old_display[1]
		old_display.clear()
		display_busy=true
		await prefs.apply_display()
		display_busy=false
		prefs.save()
	show_settings()

func _restore_defaults() -> void:
	if display_busy or display_remaining>0: return
	old_display=[prefs.values.window_mode,prefs.values.resolution]
	prefs.reset_defaults()
	show_settings()
	if old_display!=[prefs.values.window_mode,prefs.values.resolution]:
		_try_display()
	else:
		old_display.clear()
		prefs.save()

func _save_return() -> void:
	if display_busy or display_remaining>0: return
	prefs.save()
	if game.running: show_pause()
	else: show_title()

func _input(event: InputEvent) -> void:
	if rebinding.is_empty() or not event is InputEventKey or not event.pressed: return
	get_viewport().set_input_as_handled()
	if event.keycode not in [KEY_ESCAPE,KEY_F11]: prefs.bind_key(rebinding,event.physical_keycode)
	rebinding = ""
	for action in bind_buttons: bind_buttons[action].text = OS.get_keycode_string(prefs.bindings[action])

func set_interaction(hit: String) -> void:
	reticle.visible=game.running and not game.input_blocked() and not game.tool_on
	reticle.modulate.a=0.9 if not hit.is_empty() else (0.3 if game.car.zooming else 0.0)

func show_failure() -> void:
	var col=_column("Time expired")
	label(col,"You did not reach the refuge in time.",19)
	button(col,"Return to title",game._leave)

func show_ending() -> void:
	var col = _column("You reached São Pedro")
	label(col,"Journey complete.",18)
	button(col,"Return to title",game._leave)

func _process(delta: float) -> void:
	if display_remaining > 0:
		display_remaining-=delta
		display_dialog.dialog_text="Keep these display settings?\nReverting in %s seconds." % ceili(display_remaining)
		if display_remaining<=0: _revert_display()
