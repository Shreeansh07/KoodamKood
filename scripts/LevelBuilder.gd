class_name LevelBuilder
extends Node2D
## Builds one dimension (Heaven / Earth / Hell) from levels/<theme>.json:
## terrain sprites + merged collision, collectibles, hazards, enemies, lifts,
## cloud platforms, goal and the parallax background.
## Local coordinates: 1 tile = 18px, row 0 = top of the section.

const TILE := 18
const HELL_BRICKS := [14, 40, 57]

var theme: String = "earth"
var W: int = 0
var H: int = 0
var ground_row: int = 26
var rows: Array = []
var objects: Array = []
var world            # World.gd instance
var player: Player
var start_cell: Vector2i = Vector2i(3, 25)

var coins: Array = []
var hazards: Array = []
var enemies: Array = []
var lifts: Array = []
var goal_rect: Rect2 = Rect2()
var has_goal: bool = false
var danger_cells: Array = []   # [col, row, radius_cols, kind]
var sky: CanvasLayer
var _layers: Array = []        # [{holder, f}]
var _time: float = 0.0


# ================================================================== build
func build(p_theme: String, data: Dictionary, p_world) -> void:
	theme = p_theme
	world = p_world
	W = int(data["width"])
	H = int(data["height"])
	ground_row = int(data["ground_row"])
	rows = data["rows"]
	objects = data["objects"]
	_build_sky()
	_build_background_layers()
	_build_terrain()
	_build_walls()
	_build_objects()


func is_solid(c: int, r: int) -> bool:
	if c < 0 or c >= W:
		return true
	if r < 0:
		return false
	if r >= H:
		return true
	return rows[r][c] == "#"


func _depth(c: int, r: int) -> int:
	var d := 0
	while r - d - 1 >= 0 and rows[r - d - 1][c] == "#":
		d += 1
	return d


func section_size() -> Vector2:
	return Vector2(W * TILE, H * TILE)


func set_active(on: bool) -> void:
	visible = on
	process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED
	if sky != null:
		sky.visible = on


func apply_camera_limits(cam: Camera2D) -> void:
	cam.limit_left = int(global_position.x)
	cam.limit_right = int(global_position.x + W * TILE)
	cam.limit_top = int(global_position.y - 140)
	cam.limit_bottom = int(global_position.y + H * TILE + 40)


# ================================================================ terrain
func _pick_tile(c: int, r: int) -> Array:
	var l := is_solid(c - 1, r)
	var rt := is_solid(c + 1, r)
	var up := is_solid(c, r - 1)
	var dn := is_solid(c, r + 1)
	var k := 0
	if l and rt:
		k = 2
	elif (not l) and rt:
		k = 1
	elif l and (not rt):
		k = 3
	if theme == "hell":
		var d := _depth(c, r)
		var idx := 0
		if d == 0 and not dn:
			idx = HELL_BRICKS[(c * 7 + r) % 3]
		elif d == 0:
			idx = 50 if c % 2 == 0 else 51
		elif d == 1:
			idx = 48 if c % 3 != 0 else 49
		else:
			idx = HELL_BRICKS[(c * 7 + r) % 3]
		return [Game.td_tile(idx), TILE / 16.0]
	if theme == "earth":
		# Brackeys world tileset: grass-topped dirt (0) over dirt (16) with rocky dirt (17) mixed in
		var bidx := 0
		if up:
			bidx = 17 if (c * 13 + r * 7) % 5 == 0 else 16
		return [Game.bk_tile(bidx), TILE / 16.0]
	var top_b := 80
	var top_o := 100
	var idx2 := 0
	if not up:
		idx2 = (top_o if dn else top_b) + k
	else:
		idx2 = (120 if dn else 140) + k
	return [Game.pp_tile(idx2), 1.0]


func _build_terrain() -> void:
	var terrain := Node2D.new()
	terrain.name = "Terrain"
	add_child(terrain)
	for r in range(H):
		for c in range(W):
			if rows[r][c] != "#":
				continue
			var pick := _pick_tile(c, r)
			var s := Sprite2D.new()
			s.texture = pick[0]
			s.centered = false
			s.position = Vector2(c * TILE, r * TILE)
			if pick[1] != 1.0:
				s.scale = Vector2(pick[1], pick[1])
			terrain.add_child(s)

	# merged collision rectangles (greedy: row runs extended downwards)
	var body := StaticBody2D.new()
	body.name = "TerrainBody"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var open: Dictionary = {}
	for r in range(H + 1):
		var new_open: Dictionary = {}
		if r < H:
			var c := 0
			while c < W:
				if rows[r][c] == "#":
					var c0 := c
					while c + 1 < W and rows[r][c + 1] == "#":
						c += 1
					var key := "%d:%d" % [c0, c]
					new_open[key] = open[key] if open.has(key) else r
				c += 1
		for key in open.keys():
			if not new_open.has(key):
				var parts: PackedStringArray = String(key).split(":")
				_add_rect(body, int(parts[0]), int(parts[1]), int(open[key]), r - 1)
		open = new_open


func _add_rect(body: StaticBody2D, c0: int, c1: int, r0: int, r1: int) -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2((c1 - c0 + 1) * TILE, (r1 - r0 + 1) * TILE)
	shape.shape = rect
	shape.position = Vector2(c0 * TILE + rect.size.x * 0.5, r0 * TILE + rect.size.y * 0.5)
	body.add_child(shape)


func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for x in [-10.0, W * TILE + 10.0]:
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(20, 4000)
		shape.shape = rect
		shape.position = Vector2(x, 0)
		body.add_child(shape)


# ============================================================== backgrounds
func _build_sky() -> void:
	sky = CanvasLayer.new()
	sky.layer = -20
	add_child(sky)
	var g := Gradient.new()
	match theme:
		"heaven":
			g.set_color(0, Color(0.42, 0.72, 1.0))
			g.set_color(1, Color(0.88, 0.97, 1.0))
		"earth":
			g.set_color(0, Color(0.38, 0.66, 0.94))
			g.set_color(1, Color(0.80, 0.94, 0.9))
		_:
			g.set_color(0, Color(0.05, 0.0, 0.03))
			g.set_color(1, Color(0.38, 0.08, 0.05))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 256
	var tr := TextureRect.new()
	tr.texture = gt
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.set_anchors_preset(Control.PRESET_FULL_RECT)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(tr)


func _add_layer(f: float, z: int) -> Node2D:
	var holder := Node2D.new()
	holder.z_index = z
	add_child(holder)
	_layers.append({"holder": holder, "f": f})
	return holder


func _strip(holder: Node2D, path: String, scale_v: float, bottom_y: float, f: float, modulate_c: Color = Color(1, 1, 1, 1)) -> void:
	var t: Texture2D = Game.tex(path)
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.region_enabled = true
	var span := (W * TILE * f + 1600.0) / scale_v
	s.region_rect = Rect2(0, 0, span, t.get_height())
	s.scale = Vector2(scale_v, scale_v)
	s.position = Vector2(-800.0, bottom_y - t.get_height() * scale_v)
	s.modulate = modulate_c
	holder.add_child(s)


func _build_background_layers() -> void:
	match theme:
		"heaven":
			var far := _add_layer(0.30, -20)
			_strip(far, "res://assets/pixel_platformer/bg/tile_0011_a.png", 3.0, 31.0 * TILE, 0.30, Color(1, 1, 1, 0.9))
			var mid := _add_layer(0.55, -18)
			_scatter_clouds(mid, 0.55)
			var near := _add_layer(0.75, -16)
			_strip(near, "res://assets/pixel_platformer/bg/tile_0009_a.png", 3.0, 33.0 * TILE, 0.75, Color(1, 1, 1, 0.95))
		"earth":
			var far2 := _add_layer(0.25, -20)
			_scatter_clouds(far2, 0.25, 0.6)
			var hills := _add_layer(0.45, -18)
			_strip(hills, "res://assets/pixel_platformer/bg/tile_0014_a.png", 4.0, 28.0 * TILE, 0.45)
			var trees := _add_layer(0.7, -16)
			_strip(trees, "res://assets/pixel_platformer/bg/tile_0015_a.png", 4.0, 28.0 * TILE, 0.7)
		_:
			var wall := _add_layer(0.6, -20)
			var t: Texture2D = Game.tex("res://assets/tiny_dungeon/bg/tile_0040.png")
			var s := Sprite2D.new()
			s.texture = t
			s.centered = false
			s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			s.region_enabled = true
			s.region_rect = Rect2(0, 0, (W * TILE * 0.6 + 1600.0) / 2.0, 360)
			s.scale = Vector2(2, 2)
			s.position = Vector2(-800, -60)
			s.modulate = Color(0.26, 0.14, 0.18, 1.0)
			wall.add_child(s)


func _scatter_clouds(holder: Node2D, f: float, alpha: float = 0.85) -> void:
	var span := W * TILE * f + 1400.0
	var x := -500.0
	var i := 0
	while x < span:
		var idx := 1 + (i * 4 + 2) % 9
		var t: Texture2D = Game.tex("res://assets/background_elements/cloud%d.png" % idx)
		var s := Sprite2D.new()
		s.texture = t
		var sc := 0.45 + 0.12 * float((i * 7) % 4)
		s.scale = Vector2(sc, sc)
		s.modulate = Color(1, 1, 1, alpha)
		s.position = Vector2(x, 40.0 + float((i * 53) % 170))
		holder.add_child(s)
		x += 150.0 + float((i * 37) % 120)
		i += 1


func _process(_delta: float) -> void:
	if player == null or player.camera == null:
		return
	var cx := player.camera.get_screen_center_position().x - global_position.x
	for l in _layers:
		l["holder"].position.x = cx * (1.0 - float(l["f"]))


# ================================================================= objects
func _build_objects() -> void:
	for o in objects:
		var t: String = o["type"]
		var c := int(o["c"])
		var r := int(o["r"])
		match t:
			"start":
				start_cell = Vector2i(c, r)
			"coin":
				_add_coin(c, r)
			"spikes":
				_add_spikes(c, r)
			"walker":
				_add_walker(c, r, int(o.get("v", 0)))
			"flyer":
				_add_flyer(c, r, int(o.get("v", 0)), float(o.get("range", 40)))
			"hopper":
				_add_hopper(c, r, int(o.get("v", 0)), float(o.get("hop", 24)))
			"lift":
				_add_lift(c, r, int(o["rise"]), String(o["dest"]))
			"cloud":
				_add_cloud(c, r, int(o["w"]), "static", 0.0, 0.0)
			"cloud_move":
				_add_cloud(c, r, int(o["w"]), "h", float(o["range"]), float(o["speed"]))
			"cloud_vmove":
				_add_cloud(c, r, int(o["w"]), "v", float(o["range"]), float(o["speed"]))
			"goal":
				_add_goal(c, r)
			"deco":
				if o.has("tiles"):
					# Brackeys tiles stacked bottom-up from row r (bottom tile first)
					var stack: Array = o["tiles"]
					for k in range(stack.size()):
						_add_sprite(Game.bk_tile(int(stack[k])), Vector2(c * TILE, (r - k) * TILE), -2, TILE / 16.0)
				else:
					_add_sprite(Game.pp_tile(int(o["tile"])), Vector2(c * TILE, r * TILE), -2, 1.0)
			"waterfall":
				_add_waterfall(c, r, int(o["h"]))
			"bg_castle":
				_add_bg_image("res://assets/background_elements/%s.png" % ("castle_beige" if int(o.get("v", 0)) == 0 else "castle_grey"),
					Vector2(c * TILE, r * TILE + 6.0), 0.85, -9, Color(1, 1, 1, 0.92))
			"bg_tree":
				var tree_name := "tree02" if int(o.get("v", 0)) == 0 else "tree04"
				_add_bg_image("res://assets/background_elements/%s.png" % tree_name, Vector2(c * TILE, r * TILE + 2.0), 0.42, -7, Color(0.92, 0.97, 1.0, 0.95))
			"bg_gate":
				_add_gate(c, r)
			"bg_statue":
				_add_sprite(Game.td_tile(41), Vector2(c * TILE - 9, (r - 1) * TILE), -6, 2.25, Color(0.55, 0.38, 0.38))
			"bg_banner":
				_add_sprite(Game.td_tile(29), Vector2(c * TILE, r * TILE), -6, 1.125 * 1.5, Color(0.7, 0.45, 0.45))


func _add_sprite(t: Texture2D, pos: Vector2, z: int, sc: float, mod: Color = Color(1, 1, 1, 1)) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = t
	s.centered = false
	s.position = pos
	s.z_index = z
	if sc != 1.0:
		s.scale = Vector2(sc, sc)
	s.modulate = mod
	add_child(s)
	return s


func _add_bg_image(path: String, bottom_center: Vector2, sc: float, z: int, mod: Color) -> void:
	var t: Texture2D = Game.tex(path)
	var s := Sprite2D.new()
	s.texture = t
	s.scale = Vector2(sc, sc)
	s.position = bottom_center + Vector2(0, -t.get_height() * sc * 0.5)
	s.z_index = z
	s.modulate = mod
	add_child(s)


func _add_gate(c: int, r: int) -> void:
	# 3x3 arched dungeon gate (Tiny Dungeon tiles 9-11 / 21-23 / 33-35), behind everything
	var ids := [[9, 10, 11], [21, 22, 23], [33, 34, 35]]
	for ry in range(3):
		for cx in range(3):
			_add_sprite(Game.td_tile(ids[ry][cx]), Vector2((c - 1 + cx) * TILE * 1.0, (r - 2 + ry) * TILE), -6, TILE / 16.0, Color(0.7, 0.42, 0.42))


func _add_coin(c: int, r: int) -> void:
	var n := Node2D.new()
	n.position = Vector2(c * TILE + TILE * 0.5, r * TILE + TILE * 0.5)
	n.z_index = 2
	var s := Sprite2D.new()
	if theme == "hell":
		s.texture = Game.pp_tile(67)      # Kenney diamond
	else:
		s.texture = Game.tex("res://assets/brackeys/coin.png")   # Brackeys spinning coin
		s.hframes = 12
		s.frame = 0
	n.add_child(s)
	add_child(n)
	coins.append(n)


func _add_spikes(c: int, r: int) -> void:
	var s := _add_sprite(Game.pp_tile(68), Vector2(c * TILE, r * TILE), 1, 1.0, Color(1.0, 0.55, 0.5) if theme == "hell" else Color(1, 1, 1))
	s.name = "Spikes"
	hazards.append(Rect2(c * TILE + 3, r * TILE + 9, 12, 9))
	danger_cells.append([c, r, 1, "spikes"])


func _walker_frames(v: int) -> Array:
	match theme:
		"heaven":
			return [Game.pp_char(18), Game.pp_char(19)] if v == 0 else [Game.pp_char(15), Game.pp_char(16)]
		"earth":
			# Brackeys slimes (green / purple), bounce cycle 0-1-2-3-2-1
			var pur := v == 1
			return [Game.slime(pur, 0), Game.slime(pur, 1), Game.slime(pur, 2), Game.slime(pur, 3), Game.slime(pur, 2), Game.slime(pur, 1)]
		_:
			var ids := [109, 110, 122]
			var tid: int = ids[v % 3]
			return [Game.td_tile(tid)]


func _flyer_frames(v: int) -> Array:
	match theme:
		"heaven":
			return [Game.pp_char(24), Game.pp_char(25)]
		"earth":
			return [Game.pp_char(8)] if v == 0 else [Game.pp_char(24), Game.pp_char(25)]
		_:
			return [Game.td_tile(120)] if v == 0 else [Game.td_tile(121)]


func _add_walker(c: int, r: int, v: int) -> void:
	var e := Enemy.new()
	e.position = Vector2(c * TILE + TILE * 0.5, (r + 1) * TILE)
	if theme == "earth":
		e.setup(self, "walker", _walker_frames(v), 26.0, 7.0, 13.0, 24.0 + 6.0 * float(v))
	else:
		e.setup(self, "walker", _walker_frames(v), 20.0, 6.0, 13.0, 26.0 + 4.0 * float(v))
	add_child(e)
	e.finalize()
	enemies.append(e)
	danger_cells.append([c, r, 3, "walker"])


func _add_flyer(c: int, r: int, v: int, rng: float) -> void:
	var e := Enemy.new()
	e.position = Vector2(c * TILE + TILE * 0.5, r * TILE + 14.0)
	e.range_px = rng
	e.setup(self, "flyer", _flyer_frames(v), 20.0, 7.0, 12.0, 38.0)
	add_child(e)
	e.finalize()
	enemies.append(e)
	danger_cells.append([c, r, int(rng / TILE) + 2, "flyer"])


func _add_hopper(c: int, r: int, v: int, hop: float) -> void:
	var e := Enemy.new()
	e.position = Vector2(c * TILE + TILE * 0.5, (r + 1) * TILE)
	e.range_px = hop
	e.setup(self, "hopper", _walker_frames(v), 26.0, 7.0, 13.0, 1.0)
	add_child(e)
	e.finalize()
	enemies.append(e)
	danger_cells.append([c, r, 2, "walker"])


func _add_lift(c: int, r: int, rise: int, dest: String) -> void:
	var lift := Lift.new()
	lift.position = Vector2(c * TILE + TILE * 0.5, r * TILE)
	add_child(lift)
	lift.setup(self, dest, r * TILE, rise * TILE)
	lifts.append(lift)
	# shaft pole behind the platform
	var x := c * TILE
	var rr := r - rise - 1
	while rr < r:
		_add_sprite(Game.pp_tile(89), Vector2(x, rr * TILE), -3, 1.0, Color(1, 1, 1, 0.7))
		rr += 1
	# sign + glowing marker at the top of the shaft
	var col: Color = Game.DIM_COLORS[0] if dest == "heaven" else Game.DIM_COLORS[1]
	var lab := _make_label("UP: %s" % dest.to_upper(), col)
	lab.position = Vector2(c * TILE + TILE * 0.5 - 30.0, (r - rise - 3) * TILE)
	add_child(lab)
	var marker := _add_sprite(Game.pp_tile(67), Vector2(x, (r - rise - 1) * TILE - 4), -2, 1.0, Color(1, 0.9, 0.4))
	marker.name = "LiftMarker"


func _make_label(text: String, col: Color) -> Label:
	var lab := Label.new()
	lab.text = text
	lab.z_index = 4
	if Game.font() != null:
		lab.add_theme_font_override("font", Game.font())
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("outline_size", 6)
	lab.scale = Vector2(0.5, 0.5)
	lab.custom_minimum_size = Vector2(120, 0)
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lab


func _add_cloud(c: int, r: int, w: int, mode: String, rng: float, spd: float) -> void:
	var cl := MovingCloud.new()
	cl.position = Vector2(c * TILE, r * TILE)
	add_child(cl)
	cl.setup(w, 1 + (c * 5 + r) % 9, mode, rng, spd)
	cl.finalize()


func _add_goal(c: int, r: int) -> void:
	_add_sprite(Game.pp_tile(131), Vector2(c * TILE, r * TILE), -1, 1.0)
	_add_sprite(Game.pp_tile(111), Vector2(c * TILE, (r - 1) * TILE), -1, 1.0)
	goal_rect = Rect2(c * TILE - 2, (r - 1) * TILE, TILE + 4, TILE * 2)
	has_goal = true


func _add_waterfall(c: int, r: int, h: int) -> void:
	# Kenney Pixel Platformer waterfall tiles: foam top 34/35, falling 54/55, foam bottom 74/75
	for i in range(h):
		var left := 34 if i == 0 else (74 if i == h - 1 else 54)
		var right := left + 1
		_add_sprite(Game.pp_tile(left), Vector2(c * TILE, (r + i) * TILE), -8, 1.0, Color(1, 1, 1, 0.95))
		_add_sprite(Game.pp_tile(right), Vector2((c + 1) * TILE, (r + i) * TILE), -8, 1.0, Color(1, 1, 1, 0.95))
	# cloud banks it falls from
	for k in range(3):
		var t: Texture2D = Game.tex("res://assets/background_elements/cloud%d.png" % (2 + k))
		var s := Sprite2D.new()
		s.texture = t
		s.scale = Vector2(0.5, 0.5)
		s.position = Vector2(c * TILE + TILE + (k - 1) * 46.0, r * TILE - 4 + (k % 2) * 6)
		s.z_index = -7
		add_child(s)


# ================================================================ gameplay
func _physics_process(delta: float) -> void:
	if player == null or player.dead:
		return
	_time += delta
	for coin in coins:
		var cs: Sprite2D = coin.get_child(0)
		cs.position.y = sin(_time * 4.0 + coin.position.x * 0.1) * 1.6
		if cs.hframes == 12:
			cs.frame = (int(_time * 10.0) + int(coin.position.x / 7.0)) % 6
	var pr := player.rect()
	pr.position -= global_position
	var pc := pr.get_center()
	for i in range(coins.size() - 1, -1, -1):
		var coin: Node2D = coins[i]
		if coin.position.distance_to(pc) < 12.0:
			coins.remove_at(i)
			coin.queue_free()
			Game.coins += 1
			Audio.play_sfx("coin", -3.0)
			if world != null:
				world.on_coin(global_position + coin.position)
	for h in hazards:
		if h.intersects(pr):
			player.die("spikes")
			break
	if has_goal and goal_rect.intersects(pr):
		has_goal = false
		if world != null:
			world.win()


# ============================================================== safe spots
func _top_row(c: int) -> int:
	for r in range(H):
		if rows[r][c] == "#":
			return r
	return -1


func _danger_near(c: int, top: int) -> bool:
	for d in danger_cells:
		var dc: int = d[0]
		var dr: int = d[1]
		var rad: int = d[2]
		if absi(dc - c) <= rad and absi(dr - (top - 1)) <= (5 if d[3] == "flyer" else 1):
			return true
	return false


## Nearest standable ledge (3 wide, headroom, no hazard/enemy start nearby).
## Returns the local feet position.
func find_safe_spot(target_col: int) -> Vector2:
	var best := Vector2(-1, -1)
	var best_cost := 1e9
	for c in range(2, W - 2):
		var top := _top_row(c)
		if top < 0 or top > 29:
			continue
		if _top_row(c - 1) != top or _top_row(c + 1) != top:
			continue
		var free := true
		for k in range(1, 5):
			if is_solid(c, top - k):
				free = false
		if not free or _danger_near(c, top):
			continue
		var cost := absf(c - target_col) + absf(top - ground_row) * 1.5
		if cost < best_cost:
			best_cost = cost
			best = Vector2(c * TILE + TILE * 0.5, top * TILE)
	if best.x < 0.0:
		best = Vector2(start_cell.x * TILE + TILE * 0.5, (start_cell.y + 1) * TILE)
	return best


func start_position() -> Vector2:
	return Vector2(start_cell.x * TILE + TILE * 0.5, (start_cell.y + 1) * TILE)


func set_lifts_locked(v: bool) -> void:
	for l in lifts:
		l.locked = v
