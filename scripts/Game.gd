extends Node
## Autoload "Game": shared run state, asset helpers and the UI theme.

const TILE := 18
const DIM_NAMES := ["Heaven", "Earth", "Hell"]
const DIM_COLORS := [Color(0.72, 0.92, 1.0), Color(0.55, 0.95, 0.45), Color(1.0, 0.38, 0.22)]

## id = folder name under assets/toon, name = label shown on the menu
const CHARACTERS := [
	{"id": "knight", "name": "Knight"},
	{"id": "maleAdventurer", "name": "Ace"},
	{"id": "femaleAdventurer", "name": "Zoe"},
	{"id": "malePerson", "name": "Max"},
	{"id": "femalePerson", "name": "Mia"},
	{"id": "robot", "name": "Bolt"},
]

var selected_char: String = "knight"
var coins: int = 0
var stomps: int = 0
var run_time: float = 0.0

var _tex_cache: Dictionary = {}
var _font: FontFile = null
var _theme: Theme = null


func _ready() -> void:
	_setup_input()


func reset_run() -> void:
	coins = 0
	stomps = 0
	run_time = 0.0


# ------------------------------------------------------------------ input
func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP, KEY_Z])
	_add_action("pause", [KEY_ESCAPE, KEY_P])
	_add_action("retry", [KEY_R])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


# ----------------------------------------------------------------- textures
func tex(path: String) -> Texture2D:
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]


func atlas(sheet_path: String, cols: int, size: int, idx: int) -> AtlasTexture:
	var key := "%s#%d" % [sheet_path, idx]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var at := AtlasTexture.new()
	at.atlas = tex(sheet_path)
	at.region = Rect2((idx % cols) * size, floori(idx / float(cols)) * size, size, size)
	_tex_cache[key] = at
	return at


## Kenney Pixel Platformer tile (18px, 20 columns)
func pp_tile(idx: int) -> AtlasTexture:
	return atlas("res://assets/pixel_platformer/tiles.png", 20, 18, idx)


## Kenney Pixel Platformer character tile (24px, 9 columns)
func pp_char(idx: int) -> AtlasTexture:
	return atlas("res://assets/pixel_platformer/characters.png", 9, 24, idx)


## Kenney Tiny Dungeon tile (16px, 12 columns)
func td_tile(idx: int) -> AtlasTexture:
	return atlas("res://assets/tiny_dungeon/tiles.png", 12, 16, idx)


## Brackeys world tileset (16px, 16 columns)
func bk_tile(idx: int) -> AtlasTexture:
	return atlas("res://assets/brackeys/world_tileset.png", 16, 16, idx)


## Brackeys knight frame (32px cells, 8 columns)
func knight(idx: int) -> AtlasTexture:
	return atlas("res://assets/brackeys/knight.png", 8, 32, idx)


func slime(purple: bool, idx: int) -> AtlasTexture:
	return atlas("res://assets/brackeys/slime_%s.png" % ("purple" if purple else "green"), 4, 24, idx)


func coin_frame(idx: int) -> AtlasTexture:
	return atlas("res://assets/brackeys/coin.png", 12, 16, idx)


## portrait used by the menu, and its display scale for a ~56px tall hero
func char_icon(char_id: String) -> Texture2D:
	if char_id == "knight":
		return knight(0)
	return toon(char_id, "idle")


func char_icon_scale(char_id: String) -> float:
	return 1.9 if char_id == "knight" else 0.55


func toon(char_id: String, pose: String) -> Texture2D:
	return tex("res://assets/toon/%s/%s.png" % [char_id, pose])


func char_name(char_id: String) -> String:
	for c in CHARACTERS:
		if c["id"] == char_id:
			return c["name"]
	return char_id


# --------------------------------------------------------------------- font
func font() -> FontFile:
	if _font == null:
		_font = load("res://assets/fonts/KenneyPixel.ttf")
		if _font != null:
			_font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return _font


func _box(bg: Color, border: Color, bw: int = 4, margin: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(0)
	sb.set_content_margin_all(margin)
	return sb


func make_theme() -> Theme:
	if _theme != null:
		return _theme
	var th := Theme.new()
	if font() != null:
		th.default_font = font()
	th.default_font_size = 24
	th.set_stylebox("normal", "Button", _box(Color(0.22, 0.14, 0.12), Color(0.85, 0.62, 0.3)))
	th.set_stylebox("hover", "Button", _box(Color(0.34, 0.2, 0.14), Color(1.0, 0.82, 0.35)))
	th.set_stylebox("pressed", "Button", _box(Color(0.55, 0.3, 0.12), Color(1.0, 0.92, 0.5), 5))
	th.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), Color(1, 1, 1, 0.9), 2, 10))
	th.set_stylebox("disabled", "Button", _box(Color(0.2, 0.2, 0.2), Color(0.4, 0.4, 0.4)))
	th.set_color("font_color", "Button", Color(1, 0.95, 0.85))
	th.set_color("font_hover_color", "Button", Color(1, 1, 0.8))
	th.set_color("font_pressed_color", "Button", Color(1, 1, 1))
	th.set_stylebox("panel", "PanelContainer", _box(Color(0.1, 0.07, 0.1, 0.88), Color(0.85, 0.62, 0.3), 4, 16))
	th.set_color("font_color", "Label", Color(1, 0.97, 0.9))
	th.set_stylebox("slider", "HSlider", _box(Color(0.25, 0.18, 0.15), Color(0.5, 0.35, 0.2), 2, 4))
	th.set_stylebox("grabber_area", "HSlider", _box(Color(0.9, 0.65, 0.25), Color(0.9, 0.65, 0.25), 0, 4))
	th.set_stylebox("grabber_area_highlight", "HSlider", _box(Color(1.0, 0.85, 0.4), Color(1.0, 0.85, 0.4), 0, 4))
	_theme = th
	return th
