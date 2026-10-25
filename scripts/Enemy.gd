class_name Enemy
extends Node2D
## Walkers patrol a ledge (turning at walls and edges); flyers sweep back and forth.
## Touching an enemy from above (falling, feet in its upper half) squashes it;
## touching it from the side or below kills the player. Feet at node origin.

var kind: String = "walker"
var level: LevelBuilder
var frames: Array = []
var pixel_size: float = 18.0   # displayed sprite size in px
var half_w: float = 6.0
var height: float = 12.0
var speed: float = 28.0
var range_px: float = 40.0
var dead: bool = false

var _sprite: Sprite2D
var _dir: float = -1.0
var _t: float = 0.0
var _anim: float = 0.0
var _base: Vector2
var _fade: float = 0.0


func setup(p_level: LevelBuilder, p_kind: String, p_frames: Array, p_px: float, p_hw: float, p_h: float, p_speed: float) -> void:
	level = p_level
	kind = p_kind
	frames = p_frames
	pixel_size = p_px
	half_w = p_hw
	height = p_h
	speed = p_speed
	z_index = 3
	_sprite = Sprite2D.new()
	_sprite.texture = frames[0]
	var s := pixel_size / float(frames[0].get_width())
	_sprite.scale = Vector2(s, s)
	_sprite.position = Vector2(0, -pixel_size * 0.5 + 1.0)
	add_child(_sprite)
	_t = fmod(position.x * 0.37, 6.28)


func finalize() -> void:
	_base = position


func rect() -> Rect2:
	return Rect2(global_position + Vector2(-half_w, -height), Vector2(half_w * 2.0, height))


func _physics_process(delta: float) -> void:
	if dead:
		_fade += delta
		_sprite.modulate.a = clampf(1.0 - _fade / 0.45, 0.0, 1.0)
		if _fade > 0.45:
			queue_free()
		return

	_anim += delta * 5.0
	_sprite.texture = frames[int(_anim) % frames.size()]
	if frames.size() == 1:
		_sprite.position.y = -pixel_size * 0.5 + 1.0 + sin(_anim * 2.0)

	if kind == "walker":
		_walk(delta)
	elif kind == "hopper":
		_hop(delta)
	else:
		_fly(delta)

	if level != null and level.player != null:
		_check_player(delta)


func _walk(delta: float) -> void:
	var nx := position.x + _dir * speed * delta
	var front := nx + _dir * half_w
	var col := floori(front / float(Game.TILE))
	var feet_row := floori(position.y / float(Game.TILE) + 0.01)
	var wall := level.is_solid(col, feet_row - 1)
	var no_floor := not level.is_solid(col, feet_row)
	if wall or no_floor:
		_dir = -_dir
	else:
		position.x = nx
	_sprite.flip_h = _dir > 0.0


func _hop(delta: float) -> void:
	# slime that bounces in place (range_px = hop height)
	_t += delta * 3.2
	position.y = _base.y - absf(sin(_t)) * range_px
	_sprite.flip_h = false


func _fly(delta: float) -> void:
	_t += delta * (speed / maxf(range_px, 1.0)) * 1.6
	position.x = _base.x + sin(_t) * range_px
	position.y = _base.y + sin(_t * 2.3) * 5.0
	_sprite.flip_h = cos(_t) > 0.0


func _check_player(delta: float) -> void:
	var p := level.player
	if p.dead or p.locked:
		return
	var pr := p.rect()
	var er := rect()
	if not pr.intersects(er):
		return
	var feet := pr.position.y + pr.size.y
	var from_above := p.velocity.y > 20.0 and feet <= er.position.y + er.size.y * 0.6
	if from_above:
		squash()
		p.stomp_bounce()
	else:
		p.die("enemy")


func squash() -> void:
	if dead:
		return
	dead = true
	_sprite.scale.y *= 0.3
	_sprite.position.y += pixel_size * 0.3
	Audio.play_sfx("stomp")
	Game.stomps += 1
	if level != null and level.world != null:
		level.world.popup_at(global_position + Vector2(0, -pixel_size), "SQUISH!", Color(1, 0.9, 0.3))
