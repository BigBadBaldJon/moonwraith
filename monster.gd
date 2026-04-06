extends CharacterBody2D

const BASE_BODY_RADIUS: float = 18.0
const KNOCKBACK_DECAY: float = 900.0

const SEPARATION_RADIUS: float = 34.0
const SEPARATION_STRENGTH: float = 220.0

const OBSTACLE_AVOIDANCE_PADDING: float = 22.0
const OBSTACLE_AVOIDANCE_STRENGTH: float = 340.0
const OBSTACLE_SLIDE_BIAS_STRENGTH: float = 0.55

const DEATH_LINGER_TIME: float = 0.22
const DEATH_END_SCALE: Vector2 = Vector2(0.65, 0.65)

const ROAM_REACHED_DISTANCE: float = 16.0
const ROAM_POINT_MIN_DISTANCE: float = 40.0
const ROAM_POINT_MAX_DISTANCE: float = 140.0
const TARGET_REFRESH_INTERVAL: float = 0.25

const STUCK_CHECK_INTERVAL: float = 0.45
const STUCK_DISTANCE_THRESHOLD: float = 18.0
const FORCED_SLIDE_TIME: float = 0.55

const TARGET_RADIUS_INFLUENCE: float = 0.35
const STRUCTURE_TARGET_RADIUS_INFLUENCE: float = 0.60
const STRUCTURE_ATTACK_RANGE_BONUS: float = 10.0

const HEALTH_BAR_SCRIPT: GDScript = preload("res://health_bar.gd")

@export var WORLD_SIZE: Vector2 = Vector2(2400.0, 2400.0)

enum MonsterType {RUNNER, BASIC, BRUTE}
enum AiState {ROAM, CHASE, WINDUP, RECOVERY}

@onready var collision_shape: CollisionShape2D = get_node_or_null("CollisionShape2D") as CollisionShape2D
@onready var death_sound: AudioStreamPlayer2D = get_node_or_null("DeathSound") as AudioStreamPlayer2D

var target: Variant = null
var priority_target: Variant = null

var move_speed: float = 120.0
var health: float = 30.0
var max_health: float = 30.0
var is_dead: bool = false
var xp_drop_value: int = 1
var monster_type: MonsterType = MonsterType.BASIC

var attack_range: float = 40.0
var attack_damage: float = 12.0
var attack_windup_duration: float = 0.35
var attack_recovery_duration: float = 0.75
var attack_knockback_force: float = 220.0

var knockback_velocity: Vector2 = Vector2.ZERO
var body_scale: float = 1.0

var sight_range: float = 180.0
var ai_state: AiState = AiState.ROAM
var roam_target_position: Vector2 = Vector2.ZERO
var target_refresh_time_left: float = 0.0
var last_slide_sign: float = 1.0

var stuck_check_time_left: float = STUCK_CHECK_INTERVAL
var last_stuck_check_position: Vector2 = Vector2.ZERO
var forced_slide_time_left: float = 0.0

var attack_windup_left: float = 0.0
var attack_recovery_left: float = 0.0
var windup_target_snapshot: Variant = null

var xp_orb_scene: PackedScene = preload("res://xp_orb.tscn")

var death_tween_done: bool = false
var death_sound_done: bool = false

var health_bar: HealthBar = null


func _ready() -> void:
	add_to_group("monsters")
	last_stuck_check_position = global_position
	pick_new_roam_target()
	ensure_health_bar()
	update_health_bar()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		global_position = clamp_to_world(global_position, get_blocking_radius())
		return

	target_refresh_time_left -= delta
	if target_refresh_time_left <= 0.0:
		target_refresh_time_left = TARGET_REFRESH_INTERVAL
		refresh_target()

	update_attack_timers(delta)
	update_ai_state()

	var movement_velocity: Vector2 = get_state_movement_velocity(delta)
	var obstacle_velocity: Vector2 = get_obstacle_avoidance_velocity(movement_velocity)
	var separation_velocity: Vector2 = get_separation_velocity()

	velocity = movement_velocity + obstacle_velocity + separation_velocity + knockback_velocity
	move_and_slide()
	global_position = clamp_to_world(global_position, get_blocking_radius())
	roam_target_position = clamp_to_world(roam_target_position, get_blocking_radius())

	if knockback_velocity.length() > 0.0:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_DECAY * delta)

	update_stuck_resolution(delta, movement_velocity)
	queue_redraw()


func configure_for_night(night_number: int, type: MonsterType) -> void:
	monster_type = type

	match monster_type:
		MonsterType.RUNNER:
			move_speed = randf_range(130.0, 155.0) + (night_number * 1.4)
			max_health = randf_range(12.0, 18.0) + (night_number * 1.2)
			xp_drop_value = 1 + int(night_number / 4.0)
			body_scale = randf_range(0.70, 0.85)
			sight_range = 220.0
			attack_range = 24.0
			attack_damage = randf_range(5.0, 8.0) + (night_number * 0.45)
			attack_windup_duration = 0.28
			attack_recovery_duration = 0.80
			attack_knockback_force = 110.0

		MonsterType.BASIC:
			move_speed = randf_range(90.0, 108.0) + (night_number * 1.6)
			max_health = randf_range(25.0, 35.0) + (night_number * 2.6)
			xp_drop_value = 1 + int(night_number / 3.0)
			body_scale = randf_range(0.95, 1.10)
			sight_range = 190.0
			attack_range = 28.0
			attack_damage = randf_range(9.0, 13.0) + (night_number * 0.7)
			attack_windup_duration = 0.40
			attack_recovery_duration = 0.95
			attack_knockback_force = 190.0

		MonsterType.BRUTE:
			move_speed = randf_range(62.0, 78.0) + (night_number * 1.0)
			max_health = randf_range(45.0, 65.0) + (night_number * 4.0)
			xp_drop_value = 2 + int(night_number / 3.0)
			body_scale = randf_range(1.20, 1.50)
			sight_range = 170.0
			attack_range = 34.0
			attack_damage = randf_range(16.0, 22.0) + (night_number * 1.0)
			attack_windup_duration = 0.65
			attack_recovery_duration = 1.25
			attack_knockback_force = 300.0

	health = max_health
	update_health_bar()
	queue_redraw()


func set_priority_target(node: Variant) -> void:
	priority_target = node
	if is_target_valid(priority_target):
		target = priority_target


func refresh_target() -> void:
	if is_target_valid(priority_target):
		target = priority_target
		return

	priority_target = get_global_priority_target()

	if is_target_valid(priority_target):
		target = priority_target
		return

	target = find_best_target()


func update_attack_timers(delta: float) -> void:
	if attack_windup_left > 0.0:
		attack_windup_left -= delta
		if attack_windup_left <= 0.0:
			attack_windup_left = 0.0
			perform_attack_impact()

	if attack_recovery_left > 0.0:
		attack_recovery_left -= delta
		if attack_recovery_left < 0.0:
			attack_recovery_left = 0.0


func update_ai_state() -> void:
	if attack_windup_left > 0.0:
		ai_state = AiState.WINDUP
		return

	if attack_recovery_left > 0.0:
		ai_state = AiState.RECOVERY
		return

	if not is_target_valid(target):
		refresh_target()

	if not is_target_valid(target):
		target = null
		ai_state = AiState.ROAM
		return

	var target_node: Node2D = target as Node2D
	if target_node == null:
		target = null
		ai_state = AiState.ROAM
		return

	if is_target_in_attack_range(target_node):
		start_attack_windup(target_node)
		ai_state = AiState.WINDUP
	else:
		ai_state = AiState.CHASE


func get_state_movement_velocity(_delta: float) -> Vector2:
	match ai_state:
		AiState.ROAM:
			return get_roam_velocity()
		AiState.CHASE:
			return get_chase_velocity()
		AiState.WINDUP:
			return Vector2.ZERO
		AiState.RECOVERY:
			return Vector2.ZERO

	return Vector2.ZERO


func get_roam_velocity() -> Vector2:
	var to_roam_target: Vector2 = roam_target_position - global_position
	var distance: float = to_roam_target.length()

	if distance <= ROAM_REACHED_DISTANCE:
		pick_new_roam_target()
		to_roam_target = roam_target_position - global_position
		distance = to_roam_target.length()

	if distance <= 0.001:
		return Vector2.ZERO

	return to_roam_target.normalized() * (move_speed * 0.55)


func get_chase_velocity() -> Vector2:
	if not is_target_valid(target):
		refresh_target()
		if not is_target_valid(target):
			target = null
			return Vector2.ZERO

	var target_node: Node2D = target as Node2D
	if target_node == null:
		target = null
		return Vector2.ZERO

	var to_target: Vector2 = target_node.global_position - global_position
	if to_target.length() <= 0.001:
		return Vector2.ZERO

	return to_target.normalized() * move_speed


func start_attack_windup(target_node: Node2D) -> void:
	if attack_windup_left > 0.0:
		return
	if attack_recovery_left > 0.0:
		return

	windup_target_snapshot = target_node
	attack_windup_left = attack_windup_duration


func perform_attack_impact() -> void:
	if not is_target_valid(windup_target_snapshot):
		windup_target_snapshot = null
		attack_recovery_left = attack_recovery_duration
		return

	var target_node: Node2D = windup_target_snapshot as Node2D
	windup_target_snapshot = null

	if target_node == null:
		attack_recovery_left = attack_recovery_duration
		return

	if not is_target_in_attack_range(target_node):
		if is_structure_target(target_node):
			print("Monster missed structure impact on: ", target_node.name, "  distance: ", global_position.distance_to(target_node.global_position))
		attack_recovery_left = attack_recovery_duration
		return

	if target_node.has_method("take_damage"):
		if is_structure_target(target_node):
			print("Monster hit structure: ", target_node.name, "  damage: ", attack_damage)
		target_node.call("take_damage", attack_damage)

	if target_node.has_method("apply_knockback"):
		var knockback_direction: Vector2 = target_node.global_position - global_position
		if knockback_direction.length() <= 0.001:
			knockback_direction = Vector2.RIGHT
		target_node.call("apply_knockback", knockback_direction.normalized(), attack_knockback_force)

	attack_recovery_left = attack_recovery_duration


func is_target_in_attack_range(target_node: Node2D) -> bool:
	var target_radius: float = 0.0

	if target_node.has_method("get_blocking_radius"):
		var radius_value: Variant = target_node.call("get_blocking_radius")
		if radius_value is float:
			target_radius = float(radius_value)
		elif radius_value is int:
			target_radius = float(radius_value)

	var influence: float = TARGET_RADIUS_INFLUENCE
	var extra_range: float = 0.0

	if is_structure_target(target_node):
		influence = STRUCTURE_TARGET_RADIUS_INFLUENCE
		extra_range = STRUCTURE_ATTACK_RANGE_BONUS

	var combined_range: float = attack_range + extra_range + (get_blocking_radius() * influence) + (target_radius * influence)
	return global_position.distance_to(target_node.global_position) <= combined_range


func is_structure_target(target_node: Node2D) -> bool:
	return target_node.is_in_group("towers") or target_node.is_in_group("spawn_points")


func get_obstacle_avoidance_velocity(base_velocity: Vector2) -> Vector2:
	var push: Vector2 = Vector2.ZERO
	var blockers: Array[Node2D] = get_blocking_nodes()

	for blocker: Node2D in blockers:
		if blocker == self:
			continue

		var offset_from_blocker: Vector2 = global_position - blocker.global_position
		var distance: float = offset_from_blocker.length()
		if distance <= 0.001:
			continue

		var blocker_radius: float = get_blocking_radius_for_node(blocker)
		var avoid_radius: float = blocker_radius + get_blocking_radius() + OBSTACLE_AVOIDANCE_PADDING
		if distance >= avoid_radius:
			continue

		var strength: float = (avoid_radius - distance) / avoid_radius
		push += offset_from_blocker.normalized() * strength

	if push.length() <= 0.001:
		return Vector2.ZERO

	var avoidance_direction: Vector2 = push.normalized()
	var avoidance_velocity: Vector2 = avoidance_direction * OBSTACLE_AVOIDANCE_STRENGTH

	if base_velocity.length() > 0.001:
		var base_direction: Vector2 = base_velocity.normalized()

		if forced_slide_time_left > 0.0:
			var forced_slide_direction: Vector2 = Vector2(-base_direction.y, base_direction.x) * last_slide_sign
			avoidance_velocity += forced_slide_direction * (move_speed * 0.95)
		elif avoidance_direction.dot(base_direction) < -0.20:
			var slide_direction: Vector2 = Vector2(-base_direction.y, base_direction.x) * last_slide_sign
			avoidance_velocity += slide_direction * (move_speed * OBSTACLE_SLIDE_BIAS_STRENGTH)

	return avoidance_velocity


func update_stuck_resolution(delta: float, movement_velocity: Vector2) -> void:
	if forced_slide_time_left > 0.0:
		forced_slide_time_left -= delta

	stuck_check_time_left -= delta
	if stuck_check_time_left > 0.0:
		return

	stuck_check_time_left = STUCK_CHECK_INTERVAL

	if ai_state != AiState.CHASE:
		last_stuck_check_position = global_position
		return

	if movement_velocity.length() <= 0.001:
		last_stuck_check_position = global_position
		return

	var moved_distance: float = global_position.distance_to(last_stuck_check_position)
	last_stuck_check_position = global_position

	if moved_distance <= STUCK_DISTANCE_THRESHOLD:
		last_slide_sign *= -1.0
		forced_slide_time_left = FORCED_SLIDE_TIME


func get_blocking_nodes() -> Array[Node2D]:
	var unique_nodes: Dictionary = {}
	var group_names: Array[StringName] = [
		&"blocking_objects",
		&"resource_nodes",
		&"towers",
		&"spawn_points"
	]

	for group_name: StringName in group_names:
		var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)
		for node: Node in nodes:
			if node == null:
				continue
			if not is_instance_valid(node):
				continue
			if not (node is Node2D):
				continue
			if node == self:
				continue
			unique_nodes[node.get_instance_id()] = node

	var result: Array[Node2D] = []
	for stored_node: Variant in unique_nodes.values():
		var node_2d: Node2D = stored_node as Node2D
		if node_2d != null:
			result.append(node_2d)

	return result


func get_blocking_radius_for_node(node: Node2D) -> float:
	if node.has_method("get_blocking_radius"):
		var value: Variant = node.call("get_blocking_radius")
		if value is float:
			return value
		if value is int:
			return float(value)

	if node.is_in_group("resource_nodes"):
		return 20.0

	if node.is_in_group("towers"):
		return 26.0

	if node.is_in_group("spawn_points"):
		return 24.0

	return 20.0


func pick_new_roam_target() -> void:
	var target_direction: Vector2 = get_preferred_roam_direction()
	var random_angle_offset: float = randf_range(-0.9, 0.9)
	var roam_direction: Vector2 = target_direction.rotated(random_angle_offset).normalized()
	var distance: float = randf_range(ROAM_POINT_MIN_DISTANCE, ROAM_POINT_MAX_DISTANCE)

	roam_target_position = clamp_to_world(global_position + (roam_direction * distance), get_blocking_radius())


func get_preferred_roam_direction() -> Vector2:
	var preferred_target: Variant = priority_target

	if not is_target_valid(preferred_target):
		preferred_target = get_global_priority_target()

	if is_target_valid(preferred_target):
		var node: Node2D = preferred_target as Node2D
		if node != null:
			var to_target: Vector2 = node.global_position - global_position
			if to_target.length() > 0.001:
				return to_target.normalized()

	return Vector2.RIGHT.rotated(randf_range(0.0, TAU))


func find_best_target() -> Variant:
	var spawn_point: Variant = get_nearest_visible_target_in_group(&"spawn_points")
	if spawn_point != null:
		return spawn_point

	var player_target: Variant = get_nearest_visible_target_in_group(&"player")
	if player_target != null:
		return player_target

	return null


func get_global_priority_target() -> Variant:
	var spawn_point: Variant = get_nearest_target_in_group(&"spawn_points")
	if spawn_point != null:
		return spawn_point

	var player_target: Variant = get_nearest_target_in_group(&"player")
	if player_target != null:
		return player_target

	return null


func get_nearest_visible_target_in_group(group_name: StringName) -> Variant:
	var best: Variant = null
	var best_distance: float = INF
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)

	for node: Node in nodes:
		if not is_target_valid(node):
			continue

		var node_2d: Node2D = node as Node2D
		if node_2d == null:
			continue

		var distance: float = global_position.distance_to(node_2d.global_position)
		if distance > sight_range:
			continue

		if distance < best_distance:
			best_distance = distance
			best = node_2d

	return best


func get_nearest_target_in_group(group_name: StringName) -> Variant:
	var best: Variant = null
	var best_distance: float = INF
	var nodes: Array[Node] = get_tree().get_nodes_in_group(group_name)

	for node: Node in nodes:
		if not is_target_valid(node):
			continue

		var node_2d: Node2D = node as Node2D
		if node_2d == null:
			continue

		var distance: float = global_position.distance_to(node_2d.global_position)

		if distance < best_distance:
			best_distance = distance
			best = node_2d

	return best


func is_target_valid(node: Variant) -> bool:
	if node == null:
		return false

	if not is_instance_valid(node):
		return false

	if not (node is Node2D):
		return false

	var node_2d: Node2D = node as Node2D
	if node_2d == self:
		return false

	if node_2d.is_in_group("player"):
		var player_dead_value: Variant = node_2d.get("is_dead")
		if player_dead_value is bool and player_dead_value:
			return false

	if not node_2d.has_method("take_damage"):
		return false

	return true


func get_separation_velocity() -> Vector2:
	var push: Vector2 = Vector2.ZERO
	var monsters: Array[Node] = get_tree().get_nodes_in_group("monsters")

	for node: Node in monsters:
		if node == self:
			continue

		var other: CharacterBody2D = node as CharacterBody2D
		if other == null:
			continue

		if other.is_dead:
			continue

		var offset: Vector2 = global_position - other.global_position
		var distance: float = offset.length()

		if distance <= 0.001:
			continue

		if distance < SEPARATION_RADIUS:
			var strength: float = (SEPARATION_RADIUS - distance) / SEPARATION_RADIUS
			push += offset.normalized() * strength

	if push.length() <= 0.001:
		return Vector2.ZERO

	return push.normalized() * SEPARATION_STRENGTH



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
		health_bar.always_visible = true


func update_health_bar() -> void:
	ensure_health_bar()
	if health_bar != null:
		health_bar.y_offset = -30.0 * body_scale
		health_bar.set_health(health, max_health)


func take_damage(amount: float) -> void:
	if is_dead:
		return

	health -= amount
	update_health_bar()

	if health <= 0.0:
		health = 0.0
		die()


func die() -> void:
	if is_dead:
		return

	is_dead = true
	velocity = Vector2.ZERO
	knockback_velocity = Vector2.ZERO
	death_tween_done = false
	death_sound_done = false

	call_deferred("drop_xp_orb")

	if collision_shape != null:
		collision_shape.set_deferred("disabled", true)

	target = null
	priority_target = null
	windup_target_snapshot = null
	queue_redraw()

	_start_death_tween()
	_start_death_sound()

	if death_sound == null or death_sound.stream == null:
		death_sound_done = true
		_try_finish_death()


func _start_death_tween() -> void:
	self_modulate = Color(1.0, 1.0, 1.0, 1.0)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", DEATH_END_SCALE, DEATH_LINGER_TIME)
	tween.tween_property(self, "self_modulate", Color(1.0, 1.0, 1.0, 0.0), DEATH_LINGER_TIME)
	tween.finished.connect(_on_death_tween_finished, CONNECT_ONE_SHOT)


func _start_death_sound() -> void:
	if death_sound == null:
		return

	if death_sound.stream == null:
		return

	death_sound.pitch_scale = randf_range(0.94, 1.06)
	death_sound.finished.connect(_on_death_sound_finished, CONNECT_ONE_SHOT)
	death_sound.play()


func _on_death_tween_finished() -> void:
	death_tween_done = true
	_try_finish_death()


func _on_death_sound_finished() -> void:
	death_sound_done = true
	_try_finish_death()


func _try_finish_death() -> void:
	if not death_tween_done:
		return

	if not death_sound_done:
		return

	queue_free()


func drop_xp_orb() -> void:
	var orb: Area2D = xp_orb_scene.instantiate() as Area2D
	if orb == null:
		return

	if get_parent() == null:
		return

	get_parent().add_child(orb)
	orb.global_position = clamp_to_world(global_position, 10.0)
	orb.xp_value = xp_drop_value


func apply_knockback(direction: Vector2, force: float) -> void:
	if is_dead:
		return

	if direction.length() <= 0.001:
		return

	knockback_velocity += direction.normalized() * force


func clamp_to_world(pos: Vector2, padding: float = 0.0) -> Vector2:
	return Vector2(
		clampf(pos.x, padding, WORLD_SIZE.x - padding),
		clampf(pos.y, padding, WORLD_SIZE.y - padding)
	)


func get_blocking_radius() -> float:
	return BASE_BODY_RADIUS * body_scale


func _draw() -> void:
	var radius: float = BASE_BODY_RADIUS * body_scale
	var color: Color = Color.RED

	match monster_type:
		MonsterType.RUNNER:
			color = Color(1.0, 0.35, 0.35)
		MonsterType.BASIC:
			color = Color(0.9, 0.1, 0.1)
		MonsterType.BRUTE:
			color = Color(0.65, 0.0, 0.0)

	if ai_state == AiState.WINDUP:
		color = color.lerp(Color.WHITE, 0.35)
	elif ai_state == AiState.RECOVERY:
		color = color.darkened(0.20)

	draw_circle(Vector2.ZERO, radius, color)
