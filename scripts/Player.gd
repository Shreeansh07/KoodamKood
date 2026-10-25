class_name Player
extends CharacterBody2D
## The player: platformer controller with coyote time, jump buffering and
## variable jump height. Feet are at the node origin.

signal died(reason: String)

const SPEED := 125.0
const ACCEL := 900.0
const AIR_ACCEL := 650.0
const FRICTION := 1200.0
const JUMP_V := -330.0
const GRAVITY := 950.0
const FALL_MULT := 1.3
const MAX_FALL := 430.0
const COYOTE := 0.10
const BUFFER := 0.12
const HALF_W := 5.5
const HEIGHT := 25.0

var char_id: String = "maleAdventurer"
var dead: bool = false
var locked: bool = false
var invuln: float = 0.0
var _coyote: float = 0.0
var _buffer: float = 0.0
var _anim_t: float = 0.0
var _sprite: Sprite2D
var _walk: Array = []
var _tex_idle: Texture2D
var _tex_jump: Texture2D
var _tex_fall: Texture2D
var _tex_hurt: Texture2D
var _idle_frames: Array = []
var camera: Camera2D


func setup(id: String) -> void:
	char_id = id
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 6.0
	z_index = 5

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(HALF_W * 2.0, HEIGHT)
	shape.shape = rect
	shape.position = Vector2(0, -HEIGHT / 2.0)
	add_child(shape)

	var sprite_scale := 0.215
	var sprite_y := -13.5
	if id == "knight":
		# Brackeys knight: 32px cells, feet at y=28 of the cell
		_tex_idle = Game.knight(0)
		_idle_frames = [Game.knight(0), Game.knight(1), Game.knight(2), Game.knight(3)]
		_tex_jump = Game.knight(42)
		_tex_fall = Game.knight(41)
		_tex_hurt = Game.knight(50)
		for i in range(16, 24):
			_walk.append(Game.knight(i))
		sprite_scale = 1.35
		sprite_y = -12.0 * sprite_scale
	else:
		_tex_idle = Game.toon(id, "idle")
		_tex_jump = Game.toon(id, "jump")
		_tex_fall = Game.toon(id, "fall")
		_tex_hurt = Game.toon(id, "hurt")
		for i in range(8):
			_walk.append(Game.toon(id, "walk%d" % i))

	_sprite = Sprite2D.new()
	_sprite.texture = _tex_idle
	_sprite.scale = Vector2(sprite_scale, sprite_scale)
	_sprite.position = Vector2(0, sprite_y)
	add_child(_sprite)

	camera = Camera2D.new()
	camera.zoom = Vector2(3, 3)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	camera.position = Vector2(0, -22)
	add_child(camera)
	camera.make_current()


func rect() -> Rect2:
	return Rect2(global_position + Vector2(-HALF_W, -HEIGHT), Vector2(HALF_W * 2.0, HEIGHT))


func _physics_process(delta: float) -> void:
	if invuln > 0.0:
		invuln -= delta
		_sprite.modulate.a = 0.55 if int(invuln * 14.0) % 2 == 0 else 1.0
	else:
		_sprite.modulate.a = 1.0

	if dead:
		velocity.y += GRAVITY * delta
		global_position += velocity * delta
		return
	if locked:
		return

	var dir := Input.get_axis("move_left", "move_right")
	var on_floor := is_on_floor()

	# horizontal
	var accel := ACCEL if on_floor else AIR_ACCEL
	if dir != 0.0:
		velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)
		_sprite.flip_h = dir < 0.0
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	# jump timers
	if on_floor:
		_coyote = COYOTE
	else:
		_coyote -= delta
	if Input.is_action_just_pressed("jump"):
		_buffer = BUFFER
	else:
		_buffer -= delta

	# gravity
	var g := GRAVITY
	if velocity.y > 0.0:
		g *= FALL_MULT
	velocity.y = minf(velocity.y + g * delta, MAX_FALL)

	if _buffer > 0.0 and _coyote > 0.0:
		velocity.y = JUMP_V
		_buffer = 0.0
		_coyote = 0.0
		Audio.play_sfx("jump", -4.0)
	if Input.is_action_just_released("jump") and velocity.y < -80.0:
		velocity.y *= 0.45

	move_and_slide()
	_animate(delta, dir, is_on_floor())


func _animate(delta: float, dir: float, on_floor: bool) -> void:
	if not on_floor:
		_sprite.texture = _tex_jump if velocity.y < 0.0 else _tex_fall
		return
	if absf(velocity.x) > 10.0:
		_anim_t += delta * (6.0 + absf(velocity.x) / SPEED * 8.0)
		_sprite.texture = _walk[int(_anim_t) % _walk.size()]
	elif _idle_frames.size() > 0:
		_anim_t += delta * 5.0
		_sprite.texture = _idle_frames[int(_anim_t) % _idle_frames.size()]
	else:
		_anim_t = 0.0
		_sprite.texture = _tex_idle


func stomp_bounce() -> void:
	velocity.y = -250.0
	_coyote = 0.0


func die(reason: String) -> void:
	if dead or invuln > 0.0:
		return
	dead = true
	_sprite.texture = _tex_hurt
	_sprite.modulate.a = 1.0
	velocity = Vector2(0, -260)
	for c in get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	died.emit(reason)


func teleport(pos: Vector2, protect: float = 1.5) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	invuln = protect
	_coyote = 0.0
	_buffer = 0.0
	if camera != null:
		camera.reset_smoothing()
