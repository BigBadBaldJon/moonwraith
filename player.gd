extends CharacterBody2D

const MOVE_SPEED_BASE: float = 250.0
const BODY_RADIUS: float = 20.0
const FACING_LINE_LENGTH: float = 30.0
const FACING_LINE_WIDTH: float = 3.0

const ATTACK_ARC_STEPS: int = 24
const ATTACK_ARC_COLOR_READY: Color = Color(1.0, 1.0, 1.0, 0.18)
const ATTACK_ARC_COLOR_COOLDOWN: Color = Color(1.0, 0.2, 0.2, 0.14)
const ATTACK_ARC_EDGE_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)

const NIGHT_LIGHT_ENERGY_ON: float = 2.0
const NIGHT_LIGHT_FADE_TIME: float = 1.5

const ATTACK_KNOCKBACK_FORCE: float = 400.0
const PLAYER_KNOCKBACK_DECAY: float = 950.0
const HURT_FLASH_TIME: float = 0.12
const HURT_FLASH_COLOR: Color = Color(1.0, 0.35, 0.35, 1.0)

const HEALTH_BAR_SCRIPT: GDScript = preload("res://health_bar.gd")

@export var WORLD_SIZE: Vector2 = Vector2(2400.0, 2400.0)

var facing_direction: Vector2 = Vector2.RIGHT
var health: float = 100.0
var max_health: float = 100.0
var is_dead: bool = false

var attack_range: float = 70.0
var attack_damage: float = 20.0
var attack_arc_dot: float = 0.35
var attack_cooldown: float = 0.35
var attack_cooldown_left: float = 0.0
var move_speed: float = MOVE_SPEED_BASE

var level: int = 1
var xp: int = 0
var xp_to_next_level: int = 5
var upgrade_points: int = 0

var hurt_flash_left: float = 0.0
var knockback_velocity: Vector2 = Vector2.ZERO

@onready var night_light: PointLight2D = $PointLight2D

var health_bar: HealthBar = null


func _ready() -> void:
	night_light.energy = 0.0
	night_light.enabled = false
	add_to_group("player")
	ensure_health_bar()
	update_health_bar()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var was_on_cooldown: bool = attack_cooldown_left > 0.0
	var was_hurt: bool = hurt_flash_left > 0.0

	if attack_cooldown_left > 0.0:
		attack_cooldown_left -= delta
		if attack_cooldown_left < 0.0:
			attack_cooldown_left = 0.0

	if hurt_flash_left > 0.0:
		hurt_flash_left -= delta
		if hurt_flash_left < 0.0:
			hurt_flash_left = 0.0

	var input_vector: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = (input_vector * move_speed) + knockback_velocity
	move_and_slide()

	global_position = clamp_to_world(global_position, BODY_RADIUS)

	if knockback_velocity.length() > 0.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, PLAYER_KNOCKBACK_DECAY * delta)

	var old_facing_direction: Vector2 = facing_direction
	update_facing_direction()

	var facing_changed: bool = old_facing_direction.distance_to(facing_direction) > 0.0001
	var cooldown_changed: bool = was_on_cooldown != (attack_cooldown_left > 0.0)
	var hurt_changed: bool = was_hurt != (hurt_flash_left > 0.0)

	if facing_changed or cooldown_changed or hurt_changed:
		queue_redraw()


func clamp_to_world(pos: Vector2, padding: float = 0.0) -> Vector2:
	return Vector2(
		clampf(pos.x, padding, WORLD_SIZE.x - padding),
		clampf(pos.y, padding, WORLD_SIZE.y - padding)
	)


func update_facing_direction() -> void:
	var mouse_position: Vector2 = get_global_mouse_position()
	var to_mouse: Vector2 = mouse_position - global_position

	if to_mouse.length() > 0.001:
		facing_direction = to_mouse.normalized()


func can_attack() -> bool:
	return (not is_dead) and attack_cooldown_left <= 0.0


func perform_attack() -> void:
	if not can_attack():
		return

	start_attack_cooldown()

	var monsters: Array[Node] = get_tree().get_nodes_in_group("monsters")

	for monster_node: Node in monsters:
		var monster: CharacterBody2D = monster_node as CharacterBody2D
		if monster == null:
			continue

		if monster.is_dead:
			continue

		var delta_to_monster: Vector2 = monster.global_position - global_position
		var distance: float = delta_to_monster.length()

		if distance > attack_range:
			continue

		if distance <= 0.001:
			monster.take_damage(attack_damage)
			monster.apply_knockback(facing_direction, ATTACK_KNOCKBACK_FORCE)
			continue

		var direction_to_monster: Vector2 = delta_to_monster.normalized()
		var facing_dot: float = facing_direction.dot(direction_to_monster)

		if facing_dot >= attack_arc_dot:
			monster.take_damage(attack_damage)
			monster.apply_knockback(direction_to_monster, ATTACK_KNOCKBACK_FORCE)


func start_attack_cooldown() -> void:
	attack_cooldown_left = attack_cooldown
	queue_redraw()


func get_attack_arc_half_angle() -> float:
	return acos(clamp(attack_arc_dot, -1.0, 1.0))


func draw_attack_arc() -> void:
	if is_dead:
		return

	var half_angle: float = get_attack_arc_half_angle()
	var center_angle: float = facing_direction.angle()
	var start_angle: float = center_angle - half_angle
	var end_angle: float = center_angle + half_angle

	var fill_color: Color = ATTACK_ARC_COLOR_READY
	if attack_cooldown_left > 0.0:
		fill_color = ATTACK_ARC_COLOR_COOLDOWN

	var points: PackedVector2Array = PackedVector2Array()
	points.append(Vector2.ZERO)

	for i: int in range(ATTACK_ARC_STEPS + 1):
		var t: float = float(i) / float(ATTACK_ARC_STEPS)
		var angle: float = lerp(start_angle, end_angle, t)
		var point: Vector2 = Vector2.RIGHT.rotated(angle) * attack_range
		points.append(point)

	draw_colored_polygon(points, fill_color)

	for i: int in range(1, points.size() - 1):
		draw_line(points[i], points[i + 1], ATTACK_ARC_EDGE_COLOR, 2.0)

	draw_line(Vector2.ZERO, points[1], ATTACK_ARC_EDGE_COLOR, 2.0)
	draw_line(Vector2.ZERO, points[points.size() - 1], ATTACK_ARC_EDGE_COLOR, 2.0)


func take_damage(amount: float) -> void:
	if is_dead:
		return

	health -= amount
	hurt_flash_left = HURT_FLASH_TIME

	if health <= 0.0:
		health = 0.0
		is_dead = true

	update_health_bar()
	queue_redraw()


func apply_knockback(direction: Vector2, force: float) -> void:
	if is_dead:
		return

	if direction.length() <= 0.001:
		return

	knockback_velocity += direction.normalized() * force


func respawn_at(position: Vector2) -> void:
	global_position = position
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	health = max_health
	is_dead = false
	attack_cooldown_left = 0.0
	hurt_flash_left = 0.0
	update_health_bar()
	queue_redraw()


func add_xp(amount: int) -> void:
	xp += amount

	while xp >= xp_to_next_level:
		xp -= xp_to_next_level
		level_up()


func level_up() -> void:
	level += 1
	xp_to_next_level += 3
	upgrade_points += 1
	print("LEVEL UP! Level: ", level, " Points: ", upgrade_points)


func spend_point_on_damage() -> void:
	if upgrade_points <= 0:
		return

	upgrade_points -= 1
	attack_damage += 4.0


func spend_point_on_attack_speed() -> void:
	if upgrade_points <= 0:
		return

	upgrade_points -= 1

	if attack_cooldown > 0.10:
		attack_cooldown -= 0.03


func spend_point_on_move_speed() -> void:
	if upgrade_points <= 0:
		return

	upgrade_points -= 1
	move_speed += 10.0


func spend_point_on_max_health() -> void:
	if upgrade_points <= 0:
		return

	upgrade_points -= 1
	max_health += 15.0
	health += 15.0

	if health > max_health:
		health = max_health

	update_health_bar()


func spend_point_on_range() -> void:
	if upgrade_points <= 0:
		return

	upgrade_points -= 1
	attack_range += 8.0
	queue_redraw()




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
		health_bar.y_offset = -36.0
		health_bar.always_visible = true


func update_health_bar() -> void:
	ensure_health_bar()
	if health_bar != null:
		health_bar.set_health(health, max_health)


func get_blocking_radius() -> float:
	return BODY_RADIUS


func _draw() -> void:
	draw_attack_arc()

	var body_color: Color = Color.BLUE

	if is_dead:
		body_color = Color(0.4, 0.4, 0.4, 1.0)
	elif hurt_flash_left > 0.0:
		body_color = HURT_FLASH_COLOR

	draw_circle(Vector2.ZERO, BODY_RADIUS, body_color)
	draw_line(
		Vector2.ZERO,
		facing_direction * FACING_LINE_LENGTH,
		Color.BLACK,
		FACING_LINE_WIDTH
	)


func set_night_light_enabled(enabled: bool) -> void:
	var tween: Tween = create_tween()

	if enabled:
		night_light.enabled = true
		tween.tween_property(
			night_light,
			"energy",
			NIGHT_LIGHT_ENERGY_ON,
			NIGHT_LIGHT_FADE_TIME
		)
	else:
		tween.tween_property(
			night_light,
			"energy",
			0.0,
			NIGHT_LIGHT_FADE_TIME
		)
		tween.finished.connect(_on_night_light_fade_out_finished)


func _on_night_light_fade_out_finished() -> void:
	night_light.enabled = false
