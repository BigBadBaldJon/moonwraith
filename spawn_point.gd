extends StaticBody2D

const BASE_RADIUS: float = 18.0
const COLLISION_RADIUS: float = 18.0
const OUTER_RING_RADIUS: float = 26.0

const BASE_COLOR: Color = Color(0.35, 0.85, 0.95, 1.0)
const OUTER_RING_COLOR: Color = Color(0.35, 0.85, 0.95, 0.30)
const CORE_COLOR: Color = Color(0.85, 1.0, 1.0, 1.0)
const DAMAGE_RING_COLOR: Color = Color(1.0, 0.35, 0.35, 0.30)

const DESTROY_TWEEN_TIME: float = 0.22
const DESTROY_END_SCALE: Vector2 = Vector2(0.70, 0.70)
const HIT_FLASH_TIME: float = 0.12
const HIT_FLASH_COLOR: Color = Color(1.0, 0.6, 0.6, 1.0)
const NORMAL_MODULATE: Color = Color(1.0, 1.0, 1.0, 1.0)

@export var MAP_SIZE: Vector2 = Vector2(2400.0, 2400.0)
@export var EDGE_PADDING: float = 24.0

const HEALTH_BAR_SCRIPT: GDScript = preload("res://health_bar.gd")

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var health_bar: HealthBar = null

var max_health: float = 120.0
var health: float = 120.0
var is_destroyed: bool = false


func _ready() -> void:
	add_to_group("spawn_points")
	add_to_group("blocking_objects")

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = COLLISION_RADIUS
	collision_shape.shape = shape

	health = max_health
	ensure_health_bar()
	update_health_bar()
	global_position = clamp_to_map(global_position)
	queue_redraw()


func take_damage(amount: float) -> void:
	if is_destroyed:
		return

	health -= amount
	health = clampf(health, 0.0, max_health)

	print("Spawn point took damage: ", amount, "  health now: ", health)

	self_modulate = HIT_FLASH_COLOR
	var tween: Tween = create_tween()
	tween.tween_property(self, "self_modulate", NORMAL_MODULATE, HIT_FLASH_TIME)

	update_health_bar()
	queue_redraw()

	if health <= 0.0:
		destroy_spawn_point()


func destroy_spawn_point() -> void:
	if is_destroyed:
		return

	is_destroyed = true

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	queue_redraw()

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", DESTROY_END_SCALE, DESTROY_TWEEN_TIME)
	tween.tween_property(self, "self_modulate", Color(1.0, 1.0, 1.0, 0.0), DESTROY_TWEEN_TIME)
	tween.finished.connect(queue_free, CONNECT_ONE_SHOT)


func ensure_health_bar() -> void:
	if health_bar != null and is_instance_valid(health_bar):
		return

	if has_node("HealthBar"):
		health_bar = get_node("HealthBar") as HealthBar
	else:
		var new_health_bar: Node2D = Node2D.new()
		new_health_bar.name = "HealthBar"
		new_health_bar.set_script(HEALTH_BAR_SCRIPT)
		add_child(new_health_bar)
		health_bar = new_health_bar as HealthBar

	if health_bar != null:
		health_bar.y_offset = -38.0
		health_bar.always_visible = true


func update_health_bar() -> void:
	ensure_health_bar()
	if health_bar != null:
		health_bar.set_health(health, max_health)


func get_health_ratio() -> float:
	if max_health <= 0.0:
		return 0.0

	return clamp(health / max_health, 0.0, 1.0)


func get_blocking_radius() -> float:
	return COLLISION_RADIUS


func clamp_to_map(pos: Vector2) -> Vector2:
	return Vector2(
		clamp(pos.x, EDGE_PADDING, MAP_SIZE.x - EDGE_PADDING),
		clamp(pos.y, EDGE_PADDING, MAP_SIZE.y - EDGE_PADDING)
	)


func _draw() -> void:
	if is_destroyed:
		return

	var health_ratio: float = get_health_ratio()
	var damage_alpha: float = 1.0 - health_ratio

	draw_circle(Vector2.ZERO, OUTER_RING_RADIUS, OUTER_RING_COLOR)
	draw_circle(Vector2.ZERO, BASE_RADIUS, BASE_COLOR)
	draw_circle(Vector2.ZERO, 8.0, CORE_COLOR)

	if damage_alpha > 0.0:
		draw_arc(Vector2.ZERO, OUTER_RING_RADIUS + 3.0, 0.0, TAU * damage_alpha, 32, DAMAGE_RING_COLOR, 3.0)
