extends Control
## Home screen: three stacked dimensions (Heaven / Earth / Hell) as the backdrop,
## character-selection panel, volume sliders and Play.

var _selected: int = 0
var _buttons: Array = []
var _name_label: Label
var _bands: Array = []         # [heaven, earth, hell] TextureRects
var _deco: Node2D
var _clouds: Array = []        # [{node, speed, base_y}]
var _n: Dictionary = {}
var _t: float = 0.0
var _hero: Sprite2D


func _ready() -> void:
	theme = Game.make_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for i in range(Game.CHARACTERS.size()):
		if Game.CHARACTERS[i]["id"] == Game.selected_char:
			_selected = i
	_build_backdrop()
	_build_ui()
	resized.connect(_layout)
	_layout()
	_refresh_selection()
	Audio.play_music("time_for_adventure", 1.0, false)


# ---------------------------------------------------------------- backdrop
func _gradient(c0: Color, c1: Color) -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, c0)
	g.set_color(1, c1)
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


func _tiled(path: String, sc: float) -> Sprite2D:
	var t: Texture2D = Game.tex(path)
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	s.scale = Vector2(sc, sc)
	_deco.add_child(s)
	return s


func _build_backdrop() -> void:
	_bands.append(_gradient(Color(0.42, 0.72, 1.0), Color(0.88, 0.97, 1.0)))
	_bands.append(_gradient(Color(0.38, 0.66, 0.94), Color(0.62, 0.9, 0.7)))
	_bands.append(_gradient(Color(0.1, 0.02, 0.04), Color(0.45, 0.1, 0.06)))
	_deco = Node2D.new()
	add_child(_deco)

	# Heaven: drifting clouds + castle
	for i in range(7):
		var s := Sprite2D.new()
		s.texture = Game.tex("res://assets/background_elements/cloud%d.png" % (1 + (i * 3) % 9))
		var sc := 0.5 + 0.1 * float(i % 3)
		s.scale = Vector2(sc, sc)
		s.modulate.a = 0.9
		_deco.add_child(s)
		_clouds.append({"node": s, "speed": 8.0 + 5.0 * float(i % 4), "frac_y": 0.02 + 0.045 * float(i % 5), "offset": float(i) * 210.0})
	var castle := Sprite2D.new()
	castle.texture = Game.tex("res://assets/background_elements/castle_beige.png")
	castle.scale = Vector2(0.9, 0.9)
	_deco.add_child(castle)
	var snow := _tiled("res://assets/pixel_platformer/bg/solid_0102.png", 3.0)

	# Earth: hills + trees + grass
	var hills := _tiled("res://assets/pixel_platformer/bg/tile_0014_a.png", 5.0)
	var grass := _tiled("res://assets/pixel_platformer/bg/solid_0022.png", 3.0)
	var pine1 := Sprite2D.new()
	pine1.texture = Game.pp_tile(126)
	pine1.scale = Vector2(3, 3)
	_deco.add_child(pine1)
	var pine2 := Sprite2D.new()
	pine2.texture = Game.pp_tile(127)
	pine2.scale = Vector2(3, 3)
	_deco.add_child(pine2)

	# Hell: sand cap + brick wall + gate + statue + a mob
	var sand := _tiled("res://assets/tiny_dungeon/bg/solid_0050.png", 3.0)
	var brick := _tiled("res://assets/tiny_dungeon/bg/tile_0040.png", 3.0)
	var gate_parts: Array = []
	var ids := [[9, 10, 11], [21, 22, 23], [33, 34, 35]]
	for ry in range(3):
		for cx in range(3):
			var gs := Sprite2D.new()
			gs.texture = Game.td_tile(ids[ry][cx])
			gs.centered = false
			gs.scale = Vector2(3.0, 3.0)
			gs.modulate = Color(0.85, 0.5, 0.5)
			_deco.add_child(gs)
			gate_parts.append(gs)
	var statue := Sprite2D.new()
	statue.texture = Game.td_tile(41)
	statue.scale = Vector2(4, 4)
	statue.modulate = Color(0.8, 0.55, 0.55)
	_deco.add_child(statue)
	var demon := Sprite2D.new()
	demon.texture = Game.td_tile(110)
	demon.scale = Vector2(4, 4)
	_deco.add_child(demon)

	_hero = Sprite2D.new()
	_hero.scale = Vector2(0.55, 0.55)
	_deco.add_child(_hero)

	_n = {"snow": snow, "castle": castle, "hills": hills, "grass": grass, "pine1": pine1, "pine2": pine2,
		"sand": sand, "brick": brick, "gate": gate_parts, "statue": statue, "demon": demon}


func _place_all(sz: Vector2) -> void:
	var h1 := sz.y * 0.34
	var h2 := sz.y * 0.66
	_place_strip(_n["snow"], 0.0, h1 - 54.0, sz.x, 54.0, 18.0)
	_n["castle"].position = Vector2(sz.x * 0.80, h1 - 54.0 - 90.0 * 0.9 + 4.0)
	_place_strip(_n["hills"], 0.0, h2 - 54.0 - 120.0, sz.x, 120.0, 24.0)
	_place_strip(_n["grass"], 0.0, h2 - 54.0, sz.x, 54.0, 18.0)
	_n["pine1"].position = Vector2(sz.x * 0.12, h2 - 54.0 - 27.0)
	_n["pine2"].position = Vector2(sz.x * 0.86, h2 - 54.0 - 27.0)
	_place_strip(_n["sand"], 0.0, h2, sz.x, 48.0, 16.0)
	_place_strip(_n["brick"], 0.0, h2 + 48.0, sz.x, sz.y - h2 - 48.0, 16.0)
	var parts: Array = _n["gate"]
	for i in range(parts.size()):
		parts[i].position = Vector2(sz.x * 0.08 + (i % 3) * 48.0, h2 - 96.0 + floorf(i / 3.0) * 48.0)
	_n["statue"].position = Vector2(sz.x * 0.90, h2 - 32.0)
	_n["demon"].position = Vector2(sz.x * 0.77, h2 - 32.0)


func _place_strip(s: Sprite2D, x: float, y: float, w: float, h: float, tile: float) -> void:
	s.position = Vector2(x, y)
	s.region_rect = Rect2(0, 0, w / s.scale.x, h / s.scale.y)


func _layout() -> void:
	var sz := size
	var h1 := sz.y * 0.34
	var h2 := sz.y * 0.66
	_bands[0].position = Vector2(0, 0)
	_bands[0].size = Vector2(sz.x, h1)
	_bands[1].position = Vector2(0, h1)
	_bands[1].size = Vector2(sz.x, h2 - h1)
	_bands[2].position = Vector2(0, h2)
	_bands[2].size = Vector2(sz.x, sz.y - h2)
	if not _n.is_empty():
		_place_all(sz)


# --------------------------------------------------------------------- UI
func _title_label(text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 104)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0.1))
	l.add_theme_constant_override("outline_size", 20)
	return l


func _small(text: String, size_px: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 8)
	return l


func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	center.add_child(v)

	var title := HBoxContainer.new()
	title.alignment = BoxContainer.ALIGNMENT_CENTER
	title.add_theme_constant_override("separation", 0)
	title.add_child(_title_label("Koodam", Color(0.55, 0.85, 1.0)))
	title.add_child(_title_label("Kood", Color(1.0, 0.82, 0.25)))
	v.add_child(title)

	var sub := _small("Heaven   *   Earth   *   Hell", 26, Color(1, 0.95, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	var panel := PanelContainer.new()
	v.add_child(panel)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 10)
	panel.add_child(pv)
	var head := _small("CHOOSE YOUR HERO", 28, Color(1, 0.85, 0.4))
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(head)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	pv.add_child(row)
	for i in range(Game.CHARACTERS.size()):
		var b := Button.new()
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(112, 150)
		var inner := VBoxContainer.new()
		inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.alignment = BoxContainer.ALIGNMENT_CENTER
		b.add_child(inner)
		var tr := TextureRect.new()
		tr.texture = Game.char_icon(Game.CHARACTERS[i]["id"])
		tr.custom_minimum_size = Vector2(96, 112)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(tr)
		var nl := Label.new()
		nl.text = Game.CHARACTERS[i]["name"]
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(nl)
		var idx := i
		b.pressed.connect(func(): _select(idx))
		row.add_child(b)
		_buttons.append(b)

	_name_label = _small("", 26, Color(1, 1, 1))
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pv.add_child(_name_label)

	# volume
	var vol := HBoxContainer.new()
	vol.alignment = BoxContainer.ALIGNMENT_CENTER
	vol.add_theme_constant_override("separation", 12)
	pv.add_child(vol)
	for entry in [["Music", Audio.MUSIC_BUS], ["FX", Audio.SFX_BUS]]:
		var l := Label.new()
		l.text = entry[0]
		l.add_theme_font_size_override("font_size", 20)
		vol.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = Audio.get_volume(entry[1])
		s.custom_minimum_size = Vector2(150, 24)
		s.focus_mode = Control.FOCUS_NONE
		var bus: String = entry[1]
		s.value_changed.connect(func(val: float): Audio.set_volume(bus, val))
		vol.add_child(s)

	var play := Button.new()
	play.text = "PLAY"
	play.focus_mode = Control.FOCUS_NONE
	play.custom_minimum_size = Vector2(0, 64)
	play.add_theme_font_size_override("font_size", 40)
	play.pressed.connect(_play)
	v.add_child(play)

	var hint := _small("Left / Right: choose     Enter: play     In game: A D / arrows, Space = jump, Esc = pause", 18, Color(1, 1, 1, 0.9))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)


func _select(i: int) -> void:
	_selected = i
	Audio.play_sfx("click")
	_refresh_selection()


func _refresh_selection() -> void:
	for i in range(_buttons.size()):
		_buttons[i].set_pressed_no_signal(i == _selected)
	var id: String = Game.CHARACTERS[_selected]["id"]
	Game.selected_char = id
	_name_label.text = "Playing as %s" % Game.CHARACTERS[_selected]["name"]
	_hero.texture = Game.char_icon(id)
	var hs := Game.char_icon_scale(id)
	_hero.scale = Vector2(hs, hs)


func _play() -> void:
	Audio.play_sfx("click")
	Game.selected_char = Game.CHARACTERS[_selected]["id"]
	get_tree().change_scene_to_file("res://scenes/Main.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("move_left"):
		_select((_selected + Game.CHARACTERS.size() - 1) % Game.CHARACTERS.size())
	elif event.is_action_pressed("move_right"):
		_select((_selected + 1) % Game.CHARACTERS.size())
	elif event.is_action_pressed("ui_accept"):
		_play()


func _process(delta: float) -> void:
	_t += delta
	var sz := size
	for c in _clouds:
		var s: Sprite2D = c["node"]
		var w := s.texture.get_width() * s.scale.x
		var x := fmod(float(c["offset"]) + _t * float(c["speed"]), sz.x + w * 2.0) - w
		s.position = Vector2(x, sz.y * float(c["frac_y"]) + 40.0)
	_hero.position = Vector2(sz.x * 0.17, sz.y * 0.66 - 54.0 - 38.0 + sin(_t * 3.0) * 3.0)
	_hero.flip_h = false
