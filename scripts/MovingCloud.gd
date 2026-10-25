class_name MovingCloud
extends AnimatableBody2D
## A cloud platform you can stand on and jump from (one-way: jump up through it).
## mode "static", "h" (horizontal sweep) or "v" (vertical sweep).

var mode: String = "static"
var range_px: float = 0.0
var speed: float = 1.0
var _base: Vector2
var _t: float = 0.0


func setup(w_tiles: int, cloud_idx: int, p_mode: String, p_range: float, p_speed: float) -> void:
	mode = p_mode
	range_px = p_range
	speed = p_speed
	collision_layer = 1
	collision_mask = 0
	sync_to_physics = true
	z_index = 1
	var width := float(w_tiles * Game.TILE)

	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width, 6)
	shape.shape = r
	shape.position = Vector2(width * 0.5, 3)
	shape.one_way_collision = true
	add_child(shape)

	var t: Texture2D = Game.tex("res://assets/background_elements/cloud%d.png" % cloud_idx)
	var disp_w := width + 26.0
	var s := disp_w / float(t.get_width())
	var disp_h := float(t.get_height()) * s
	var spr := Sprite2D.new()
	spr.texture = t
	spr.scale = Vector2(s, s)
	spr.position = Vector2(width * 0.5, -disp_h * 0.30 + disp_h * 0.5)
	add_child(spr)


func finalize() -> void:
	_base = position
	_t = fmod(_base.x * 0.013, 6.28)


func _physics_process(delta: float) -> void:
	if mode == "static" or range_px <= 0.0:
		return
	_t += delta * speed
	if mode == "h":
		position.x = _base.x + sin(_t) * range_px
	else:
		position.y = _base.y + sin(_t) * range_px
