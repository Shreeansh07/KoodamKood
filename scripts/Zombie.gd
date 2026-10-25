class_name Zombie
extends Node2D
## The Hell zombie (Kenney Toon Characters). Once it spawns it flies/runs straight
## at the player faster than the player can move: the run is over when it catches you.

const SPEED := 235.0

var target: Player
var _sprite: Sprite2D
var _frames: Array = []
var _t: float = 0.0
var _caught: bool = false


func setup(p_target: Player) -> void:
	target = p_target
	z_index = 6
	for i in range(8):
		_frames.append(Game.toon("zombie", "walk%d" % i))
	_sprite = Sprite2D.new()
	_sprite.texture = _frames[0]
	_sprite.scale = Vector2(0.34, 0.34)
	_sprite.position = Vector2(0, -22)
	add_child(_sprite)


func rect() -> Rect2:
	return Rect2(global_position + Vector2(-9, -34), Vector2(18, 34))


func _physics_process(delta: float) -> void:
	if target == null or target.dead or _caught:
		return
	_t += delta
	_sprite.texture = _frames[int(_t * 14.0) % _frames.size()]
	var to := target.global_position - global_position
	var dist := to.length()
	if dist > 1.0:
		var step := minf(SPEED * delta, dist)
		global_position += to / dist * step
	_sprite.flip_h = to.x < 0.0
	if rect().intersects(target.rect().grow(2.0)):
		_caught = true
		target.invuln = 0.0
		target.die("zombie")
