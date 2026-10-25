class_name Lift
extends AnimatableBody2D
## A levitating lift: waits at the bottom, rises, and - if the player is riding
## it when it reaches the top - carries them up to the dimension above.
## Position is in the parent's (level's) local space; y = platform surface.

const WIDTH := 54.0
const UP_SPEED := 55.0
const DOWN_SPEED := 80.0

var level: LevelBuilder
var dest: String = "earth"
var y_bottom: float = 0.0
var y_top: float = 0.0
var locked: bool = false
var _state: int = 0     # 0 wait bottom, 1 rising, 2 wait top, 3 descending
var _timer: float = 1.0
var _rider: bool = false
var _glow: float = 0.0


func setup(p_level: LevelBuilder, p_dest: String, p_y_bottom: float, rise_px: float) -> void:
	level = p_level
	dest = p_dest
	y_bottom = p_y_bottom
	y_top = p_y_bottom - rise_px
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	z_index = 2
	position.y = y_bottom

	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(WIDTH, 6)
	shape.shape = r
	shape.position = Vector2(0, 3)
	shape.one_way_collision = true
	add_child(shape)

	if level != null and level.theme == "earth":
		# Brackeys platform piece (48x16, yellow variant) stretched to the lift width
		var bs := Sprite2D.new()
		bs.texture = Game.atlas("res://assets/brackeys/platforms.png", 4, 16, 8)
		bs.region_enabled = false
		var at := AtlasTexture.new()
		at.atlas = Game.tex("res://assets/brackeys/platforms.png")
		at.region = Rect2(0, 32, 48, 16)
		bs.texture = at
		bs.scale = Vector2(WIDTH / 48.0, WIDTH / 48.0)
		bs.position = Vector2(0, 9.0)
		add_child(bs)
	else:
		for i in range(3):
			var s := Sprite2D.new()
			s.texture = Game.pp_tile(147)
			s.position = Vector2((i - 1) * 18.0, 9.0)
			add_child(s)


func _draw() -> void:
	# gold chevrons above the platform so it reads as "goes up"
	var a := 0.55 + 0.4 * sin(_glow * 5.0)
	var col := Color(1.0, 0.85, 0.3, a)
	for k in range(2):
		var y := -8.0 - k * 7.0 - fmod(_glow * 6.0, 7.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-6, y), Vector2(0, y - 6), Vector2(6, y)]), Color(col.r, col.g, col.b, col.a * (1.0 - k * 0.35)))


func _physics_process(delta: float) -> void:
	_glow += delta
	queue_redraw()
	if locked:
		return
	match _state:
		0:
			_timer -= delta
			if _timer <= 0.0:
				_state = 1
		1:
			position.y = maxf(position.y - UP_SPEED * delta, y_top)
			if position.y <= y_top + 0.01:
				_state = 2
				_timer = 0.6
				if _is_rider() and level != null and level.world != null:
					level.world.travel_up(dest, global_position.x)
		2:
			_timer -= delta
			if _timer <= 0.0:
				_state = 3
		3:
			position.y = minf(position.y + DOWN_SPEED * delta, y_bottom)
			if position.y >= y_bottom - 0.01:
				_state = 0
				_timer = 1.2

	var now := _is_rider()
	if now and not _rider and level != null and level.world != null:
		Audio.play_sfx("lift", -6.0)
		level.world.toast("Riding the lift up to %s..." % dest.capitalize())
	_rider = now


func _is_rider() -> bool:
	if level == null or level.player == null:
		return false
	var p := level.player
	if p.dead:
		return false
	var d := p.global_position - global_position
	return absf(d.x) < WIDTH * 0.5 + 2.0 and d.y > -8.0 and d.y < 6.0
