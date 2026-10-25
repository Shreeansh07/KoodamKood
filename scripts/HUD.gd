class_name HUD
extends CanvasLayer
## All on-screen UI: counters, dimension banner, Hell timer, toasts, fades,
## pause / game over / victory panels. Built in code with the Kenney pixel font.

var world
var ui: Control
var coin_label: Label
var dim_label: Label
var info_label: Label
var toast_label: Label
var hell_box: VBoxContainer
var hell_label: Label
var hell_bar: ProgressBar
var red_overlay: ColorRect
var fade_rect: ColorRect
var over_panel: Control
var over_reason: Label
var win_panel: Control
var win_stats: Label
var pause_panel: Control
var _toast_tween: Tween
var _pulse: float = 0.0
var _zombie: bool = false
var _hell_frac: float = 1.0
var _info_t: float = 0.0


func setup(p_world) -> void:
	world = p_world
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS

	ui = Control.new()
	ui.theme = Game.make_theme()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)

	red_overlay = ColorRect.new()
	red_overlay.color = Color(0.8, 0.0, 0.0, 0.0)
	red_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	red_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(red_overlay)

	# ---- top bar
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 14
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(top)

	var left_box := HBoxContainer.new()
	left_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left_box)
	var icon := TextureRect.new()
	icon.texture = Game.coin_frame(0)
	icon.custom_minimum_size = Vector2(36, 36)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	left_box.add_child(icon)
	coin_label = _label("x 0", 32, Color(1, 0.9, 0.35))
	left_box.add_child(coin_label)

	dim_label = _label("EARTH", 40, Color.WHITE)
	dim_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dim_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(dim_label)

	info_label = _label("", 24, Color(0.95, 0.95, 0.95))
	info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	top.add_child(info_label)

	# ---- hell timer
	hell_box = VBoxContainer.new()
	hell_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hell_box.offset_top = 70
	hell_box.offset_left = -230
	hell_box.offset_right = 230
	hell_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hell_box.visible = false
	ui.add_child(hell_box)
	hell_label = _label("", 28, Color(1, 0.5, 0.3))
	hell_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hell_box.add_child(hell_label)
	hell_bar = ProgressBar.new()
	hell_bar.custom_minimum_size = Vector2(460, 20)
	hell_bar.show_percentage = false
	hell_bar.max_value = 100.0
	hell_bar.value = 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.1, 0.05, 0.05, 0.85)
	bg.set_border_width_all(3)
	bg.border_color = Color(0.9, 0.5, 0.3)
	hell_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(1.0, 0.45, 0.15)
	hell_bar.add_theme_stylebox_override("fill", fill)
	hell_box.add_child(hell_bar)

	# ---- toast
	toast_label = _label("", 32, Color.WHITE)
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 200
	toast_label.offset_left = -520
	toast_label.offset_right = 520
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0.0
	ui.add_child(toast_label)

	# ---- panels
	over_panel = _build_over()
	win_panel = _build_win()
	pause_panel = _build_pause()

	# ---- fade (topmost)
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_rect.modulate.a = 0.0
	ui.add_child(fade_rect)
	update_counters()


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	l.add_theme_constant_override("outline_size", 8)
	return l


# ---------------------------------------------------------------- panels
func _panel_shell(title: String, title_color: Color) -> Array:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var panel := PanelContainer.new()
	center.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.custom_minimum_size = Vector2(520, 0)
	panel.add_child(v)
	var t := _label(title, 56, title_color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	ui.add_child(root)
	return [root, v]


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(190, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _build_over() -> Control:
	var parts := _panel_shell("GAME OVER", Color(1, 0.3, 0.25))
	var v: VBoxContainer = parts[1]
	over_reason = _label("", 26, Color(1, 0.9, 0.8))
	over_reason.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(over_reason)
	var loser := _label("\"oo loser...\"", 40, Color(1, 0.85, 0.3))
	loser.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(loser)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_button("Retry (R)", _on_retry))
	row.add_child(_button("Menu", _on_menu))
	v.add_child(row)
	return parts[0]


func _build_win() -> Control:
	var parts := _panel_shell("YOU ASCENDED!", Color(1, 0.9, 0.35))
	var v: VBoxContainer = parts[1]
	win_stats = _label("", 26, Color(1, 1, 1))
	win_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(win_stats)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.add_child(_button("Play again", _on_retry))
	row.add_child(_button("Menu", _on_menu))
	v.add_child(row)
	return parts[0]


func _build_pause() -> Control:
	var parts := _panel_shell("PAUSED", Color(1, 1, 1))
	var v: VBoxContainer = parts[1]
	for entry in [["Music", Audio.MUSIC_BUS], ["Effects", Audio.SFX_BUS]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var l := _label(entry[0], 26, Color(1, 1, 1))
		l.custom_minimum_size = Vector2(130, 0)
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Audio.get_volume(entry[1])
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.custom_minimum_size = Vector2(260, 28)
		var bus: String = entry[1]
		s.value_changed.connect(func(val: float): Audio.set_volume(bus, val))
		row.add_child(s)
		v.add_child(row)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 14)
	row2.add_child(_button("Resume", toggle_pause))
	row2.add_child(_button("Menu", _on_menu))
	v.add_child(row2)
	return parts[0]


# --------------------------------------------------------------- actions
func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/Menu.tscn")


func toggle_pause() -> void:
	var p := not get_tree().paused
	get_tree().paused = p
	pause_panel.visible = p
	Audio.play_sfx("click")


func _unhandled_input(event: InputEvent) -> void:
	if over_panel.visible and event.is_action_pressed("retry"):
		_on_retry()


# ------------------------------------------------------------ public API
func update_counters() -> void:
	coin_label.text = "x %d" % Game.coins


func set_dimension(idx: int) -> void:
	dim_label.text = Game.DIM_NAMES[idx].to_upper()
	dim_label.add_theme_color_override("font_color", Game.DIM_COLORS[idx])


func toast(msg: String, seconds: float = 2.5) -> void:
	toast_label.text = msg
	if _toast_tween != null:
		_toast_tween.kill()
	toast_label.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(seconds)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.6)


func fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "modulate:a", a, dur)
	await tw.finished


func set_hell(left: float, total: float) -> void:
	hell_box.visible = true
	_hell_frac = left / total
	var secs := int(ceil(left))
	hell_label.text = "ZOMBIE AWAKENS IN %02d:%02d" % [secs / 60, secs % 60]
	hell_bar.value = _hell_frac * 100.0
	var col := Color(1.0, 0.45, 0.15)
	if left < 30.0:
		col = Color(1.0, 0.15, 0.1)
	(hell_bar.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = col
	hell_label.add_theme_color_override("font_color", col)


func zombie_mode() -> void:
	_zombie = true
	hell_box.visible = true
	hell_label.text = "THE ZOMBIE IS HERE - NO ESCAPE!"
	hell_label.add_theme_color_override("font_color", Color(1, 0.1, 0.1))
	hell_bar.value = 0.0


func hide_hell() -> void:
	if _zombie and world != null and not world.over:
		return
	hell_box.visible = false
	_hell_frac = 1.0
	red_overlay.color.a = 0.0


func show_game_over(reason: String) -> void:
	var texts := {
		"enemy": "A monster got you! (Jump ON them to win.)",
		"spikes": "Ouch! Those spikes were sharp.",
		"void": "You fell out of Hell into the endless void.",
		"zombie": "The zombie caught you. You stayed in Hell too long.",
	}
	over_reason.text = texts.get(reason, "You died.")
	over_panel.visible = true


func show_win() -> void:
	var t := int(Game.run_time)
	win_stats.text = "Coins: %d    Mobs squashed: %d    Time: %02d:%02d" % [Game.coins, Game.stomps, t / 60, t % 60]
	win_panel.visible = true


func _process(delta: float) -> void:
	_pulse += delta
	_info_t -= delta
	if _info_t <= 0.0:
		_info_t = 0.2
		var t := int(Game.run_time)
		info_label.text = "Mobs: %d   %02d:%02d" % [Game.stomps, t / 60, t % 60]
	if _zombie and world != null and not world.over:
		red_overlay.color.a = 0.22 + 0.1 * sin(_pulse * 6.0)
	elif hell_box.visible and _hell_frac < 0.27:
		red_overlay.color.a = (0.27 - _hell_frac) * 0.6 * (0.6 + 0.4 * sin(_pulse * 7.0))
