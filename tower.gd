extends StaticBody2D

const BASE_RADIUS: float = 16.0
const COLLISION_RADIUS: float = 16.0
const BARREL_LENGTH: float = 22.0
const BARREL_WIDTH: float = 4.0
const RANGE_RING_STEPS: int = 40

const BASE_COLOR: Color = Color(0.35, 0.35, 0.35, 1.0)
const BARREL_COLOR: Color = Color(0.15, 0.15, 0.15, 1.0)
const RANGE_COLOR: Color = Color(0.2, 0.6, 1.0, 0.14)
const RANGE_EDGE_COLOR: Color = Color(0.2, 0.6, 1.0, 0.35)
const MUZZLE_FLASH_COLOR: Color = Color(1.0, 0.95, 0.7, 0.9)

const DESTROY_TWEEN_TIME: float = 0.18
const DESTROY_END_SCALE: Vector2 = Vector2(0.75, 0.75)
const DRAW_SAFE_MARGIN: float = 20.0

@export var WORLD_SIZE: Vector2 = Vector2(2400.0, 2400.0)

const HEALTH_BAR_SCRIPT: GDScript = preload("res://health_bar.gd")

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var fire_sound: AudioStreamPlayer2D = get_node_or_null("FireSound") as AudioStreamPlayer2D

var health_bar: HealthBar = null

var projectile_scene: PackedScene = preload("res://projectile.tscn")

var attack_range: float = 180.0
var damage: float = 10.0
var fire_cooldown: float = 0.8
var fire_cooldown_left: float = 0.0
var projectile_spawn_distance: float = 26.0
var projectile_knockback_force: float = 140.0

var muzzle_flash_duration: float = 0.06
var muzzle_flash_time_left: float = 0.0

var max_health: float = 60.0
var health: float = 60.0
var is_destroyed: bool = false

var facing_direction: Vector2 = Vector2.RIGHT
var current_target: CharacterBody2D = null
var show_range: bool = true


func _ready() -> void:
	add_to_group("towers")

	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = COLLISION_RADIUS
	collision_shape.shape = shape

	health = max_health
	ensure_health_bar()
	update_health_bar()
	global_position = clamp_to_world(global_position, COLLISION_RADIUS)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_destroyed:
		return

	global_position = clamp_to_world(global_position, COLLISION_RADIUS)

	var old_facing_direction: Vector2 = facing_direction
	var old_target: CharacterBody2D = current_target

	if fire_cooldown_left > 0.0:
		fire_cooldown_left -= delta
		if fire_cooldown_left < 0.0:
			fire_cooldown_left = 0.0

	if muzzle_flash_time_left > 0.0:
		muzzle_flash_time_left -= delta
		if muzzle_flash_time_left < 0.0:
			muzzle_flash_time_left = 0.0
		queue_redraw()

	current_target = find_target()

	if current_target != null:
		var to_target: Vector2 = current_target.global_position - global_position
		if to_target.length() > 0.001:
			facing_direction = to_target.normalized()

		if fire_cooldown_left <= 0.0:
			fire_at_target(current_target)
			fire_cooldown_left = fire_cooldown
	else:
		facing_direction = Vector2.RIGHT

	var facing_changed: bool = old_facing_direction.distance_to(facing_direction) > 0.0001
	var target_changed: bool = old_target != current_target

	if facing_changed or target_changed:
		queue_redraw()


func find_target() -> CharacterBody2D:
	var best_target: CharacterBody2D = null
	var best_distance: float = attack_range

	var monsters: Array[Node] = get_tree().get_nodes_in_group("monsters")

	for monster_node: Node in monsters:
		var monster: CharacterBody2D = monster_node as CharacterBody2D
		if monster == null:
			continue

		if not is_instance_valid(monster):
			continue

		if monster.is_dead:
			continue

		var distance: float = global_position.distance_to(monster.global_position)
		if distance > attack_range:
			continue

		if best_target == null or distance < best_distance:
			best_target = monster
			best_distance = distance

	return best_target


func fire_at_target(target: CharacterBody2D) -> void:
	if is_destroyed:
		return

	if target == null:
		return

	if not is_instance_valid(target):
		return

	if target.is_dead:
		return

	var projectile: Area2D = projectile_scene.instantiate() as Area2D
	if projectile == null:
		return

	var shot_direction: Vector2 = (target.global_position - global_position).normalized()
	if shot_direction == Vector2.ZERO:
		shot_direction = facing_direction

	var spawn_position: Vector2 = clamp_to_world(global_position + (shot_direction * projectile_spawn_distance), DRAW_SAFE_MARGIN)
	projectile.global_position = spawn_position

	get_tree().current_scene.add_child(projectile)

	projectile.damage = damage
	projectile.knockback_force = projectile_knockback_force
	projectile.setup(shot_direction, damage, &"tower")

	if fire_sound != null and fire_sound.stream != null:
		fire_sound.pitch_scale = randf_range(0.96, 1.04)
		fire_sound.play()

	facing_direction = shot_direction
	muzzle_flash_time_left = muzzle_flash_duration
	queue_redraw()


func take_damage(amount: float) -> void:
	if is_destroyed:
		return

	health -= amount
	health = clampf(health, 0.0, max_health)
	update_health_bar()

	if health <= 0.0:
		health = 0.0
		destroy_tower()


func destroy_tower() -> void:
	if is_destroyed:
		return

	is_destroyed = true
	current_target = null
	show_range = false
	muzzle_flash_time_left = 0.0
	fire_cooldown_left = 0.0

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	set_physics_process(false)
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
		health_bar.y_offset = -30.0
		health_bar.always_visible = true


func update_health_bar() -> void:
	ensure_health_bar()
	if health_bar != null:
		health_bar.set_health(health, max_health)


func clamp_to_world(pos: Vector2, padding: float = 0.0) -> Vector2:
	return Vector2(
		clampf(pos.x, padding, WORLD_SIZE.x - padding),
		clampf(pos.y, padding, WORLD_SIZE.y - padding)
	)


func get_blocking_radius() -> float:
	return COLLISION_RADIUS


func _draw() -> void:
	if is_destroyed:
		return

	if show_range:
		draw_range_ring()

	draw_circle(Vector2.ZERO, BASE_RADIUS, BASE_COLOR)
	draw_line(
		Vector2.ZERO,
		facing_direction * BARREL_LENGTH,
		BARREL_COLOR,
		BARREL_WIDTH
	)

	if muzzle_flash_time_left > 0.0:
		var flash_center: Vector2 = facing_direction * (BARREL_LENGTH + 4.0)
		draw_circle(flash_center, 6.0, MUZZLE_FLASH_COLOR)


func draw_range_ring() -> void:
	var points: PackedVector2Array = PackedVector2Array()

	for i: int in range(RANGE_RING_STEPS):
		var angle: float = (float(i) / float(RANGE_RING_STEPS)) * TAU
		points.append(Vector2.RIGHT.rotated(angle) * attack_range)

	draw_colored_polygon(points, RANGE_COLOR)

	for i: int in range(RANGE_RING_STEPS):
		var from_point: Vector2 = points[i]
		var to_point: Vector2 = points[(i + 1) % RANGE_RING_STEPS]
		draw_line(from_point, to_point, RANGE_EDGE_COLOR, 2.0)
