extends Node2D
## Main game scene: builds the three dimensions, spawns the player, handles
## dimension travel, the Hell timer / zombie, death and victory.

const DIMS := ["heaven", "earth", "hell"]
const ORIGINS := [Vector2(0, 0), Vector2(0, 1000), Vector2(0, 2000)]
const MUSIC := "time_for_adventure"   # Brackeys track, pitched per dimension
const MUSIC_PITCH := [1.08, 1.0, 0.72]
const HELL_TIME := 75.0
const ZOMBIE_LEAD := 480.0

var levels: Array = []
var player: Player
var hud: HUD
var fx: Node2D
var active: int = 1
var over: bool = false
var transitioning: bool = false
var hell_on: bool = false
var hell_left: float = HELL_TIME
var zombie: Zombie = null
var _warned_30: bool = false
var _last_beep: int = 99


func _ready() -> void:
	Game.reset_run()
	for i in range(DIMS.size()):
		var lvl := LevelBuilder.new()
		lvl.name = DIMS[i].capitalize()
		lvl.position = ORIGINS[i]
		add_child(lvl)
		lvl.build(DIMS[i], _load_level(DIMS[i]), self)
		levels.append(lvl)

	fx = Node2D.new()
	fx.z_index = 20
	add_child(fx)

	player = Player.new()
	add_child(player)
	player.setup(Game.selected_char)
	player.died.connect(_on_player_died)
	for lvl in levels:
		lvl.player = player

	hud = HUD.new()
	add_child(hud)
	hud.setup(self)

	_enter(1, levels[1].start_position())
	hud.toast("Reach the castle flag in HEAVEN. Ride the lifts up!", 4.0)


func _load_level(theme: String) -> Dictionary:
	var path := "res://levels/%s.json" % theme
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Could not load level: " + path)
		return {"width": 10, "height": 10, "ground_row": 8, "rows": [], "objects": []}
	return parsed


# ============================================================ dimensions
func _enter(idx: int, local_pos: Vector2) -> void:
	active = idx
	for i in range(levels.size()):
		levels[i].set_active(i == idx)
	levels[idx].apply_camera_limits(player.camera)
	player.teleport(levels[idx].global_position + local_pos)
	Audio.play_music(MUSIC, MUSIC_PITCH[idx], idx == 2)
	hud.set_dimension(idx)
	if idx == 2:
		hell_on = true
		_warned_30 = false
		_last_beep = 99
		if zombie != null:
			# the zombie is already awake: it is on you again immediately
			zombie.global_position = player.global_position + Vector2(-ZOMBIE_LEAD, -20)
			hell_left = 0.0
			hud.zombie_mode()
		else:
			hell_left = HELL_TIME
			hud.toast("HELL! Find a lift up before the zombie awakens!", 3.5)
	else:
		hell_on = false
		hud.hide_hell()


func _travel(idx: int, col: int, msg: String, sfx: String) -> void:
	if transitioning or over or player.dead:
		return
	transitioning = true
	player.locked = true
	Audio.play_sfx(sfx)
	await hud.fade_to(1.0, 0.25)
	if over or player.dead:
		transitioning = false
		return
	var spot: Vector2 = levels[idx].find_safe_spot(col)
	_enter(idx, spot)
	hud.toast(msg, 2.5)
	await hud.fade_to(0.0, 0.3)
	player.locked = false
	transitioning = false


## Called by a Lift that reached the top with the player aboard.
func travel_up(dest: String, from_global_x: float) -> void:
	if zombie != null or over:
		return
	var idx := DIMS.find(dest)
	if idx < 0:
		return
	var col := int((from_global_x - levels[active].global_position.x) / float(Game.TILE))
	_travel(idx, col, "You ascended to %s!" % dest.to_upper(), "transition")


func _fell() -> void:
	if active == 2:
		player.invuln = 0.0
		player.die("void")
		return
	var lvl: LevelBuilder = levels[active]
	var col := int((player.global_position.x - lvl.global_position.x) / float(Game.TILE))
	var next := active + 1
	_travel(next, col, "You fell into %s!" % DIMS[next].to_upper(), "fall")


# =============================================================== process
func _physics_process(delta: float) -> void:
	if over or player == null:
		return
	if not player.dead:
		Game.run_time += delta
		var lvl: LevelBuilder = levels[active]
		var limit := lvl.global_position.y + lvl.section_size().y + 30.0
		if player.global_position.y > limit and not transitioning:
			_fell()


func _process(delta: float) -> void:
	if over or not hell_on or zombie != null or player.dead or transitioning:
		return
	hell_left -= delta
	hud.set_hell(maxf(hell_left, 0.0), HELL_TIME)
	if hell_left <= 30.0 and not _warned_30:
		_warned_30 = true
		Audio.play_sfx("warning")
		hud.toast("Something stirs in the dark... GET OUT OF HELL!", 3.0)
	if hell_left <= 10.0:
		var s := int(ceil(hell_left))
		if s != _last_beep and s > 0:
			_last_beep = s
			Audio.play_sfx("warning", -4.0)
	if hell_left <= 0.0:
		_spawn_zombie()


func _spawn_zombie() -> void:
	zombie = Zombie.new()
	levels[2].add_child(zombie)
	zombie.global_position = player.global_position + Vector2(-ZOMBIE_LEAD, -20)
	zombie.setup(player)
	levels[2].set_lifts_locked(true)
	Audio.play_sfx("zombie")
	hud.zombie_mode()
	hud.toast("THE ZOMBIE HAS AWAKENED. THERE IS NO ESCAPE.", 4.0)


# ================================================================ events
func on_coin(world_pos: Vector2) -> void:
	hud.update_counters()
	popup_at(world_pos + Vector2(0, -8), "+1", Color(1, 0.9, 0.3))


func toast(msg: String) -> void:
	hud.toast(msg, 2.0)


func popup_at(world_pos: Vector2, text: String, col: Color) -> void:
	var lab := Label.new()
	lab.text = text
	if Game.font() != null:
		lab.add_theme_font_override("font", Game.font())
	lab.add_theme_font_size_override("font_size", 16)
	lab.add_theme_color_override("font_color", col)
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lab.add_theme_constant_override("outline_size", 6)
	lab.scale = Vector2(0.5, 0.5)
	lab.position = world_pos - Vector2(20, 10)
	fx.add_child(lab)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lab, "position:y", lab.position.y - 18.0, 0.7)
	tw.tween_property(lab, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(lab.queue_free)
	hud.update_counters()


func _on_player_died(reason: String) -> void:
	if over:
		return
	over = true
	Audio.stop_music()
	Audio.play_sfx("death")
	hud.hide_hell()
	await get_tree().create_timer(0.9).timeout
	Audio.play_voice("loser")
	hud.show_game_over(reason)


func win() -> void:
	if over:
		return
	over = true
	player.locked = true
	Audio.stop_music()
	Audio.play_sfx("win")
	hud.hide_hell()
	hud.show_win()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not over:
		hud.toggle_pause()
