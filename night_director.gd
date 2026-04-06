extends Node

const SPAWN_RADIUS_MIN: float = 380.0
const SPAWN_RADIUS_MAX: float = 560.0
const SPAWN_TICK_INTERVAL: float = 1.0
const WORLD_SIZE: Vector2 = Vector2(2400.0, 2400.0)
const WORLD_EDGE_PADDING: float = 48.0
const MAX_SPAWN_ATTEMPTS: int = 20

const PLAYER_NEAR_RADIUS: float = 180.0
const SPAWN_POINT_NEAR_RADIUS: float = 180.0

var monster_spawn_scene: PackedScene = preload("res://monster_spawn.tscn")

var is_active: bool = false
var current_night: int = 0

var total_spawn_budget: int = 0
var spawned_count: int = 0
var alive_cap: int = 0

var spawn_tick_time_left: float = 0.0
var spawn_interval_dynamic: float = SPAWN_TICK_INTERVAL
var spawn_center: Vector2 = Vector2.ZERO

var player: CharacterBody2D = null
var world_root: Node = null
var active_spawn_point: Variant = null

var pressure_score: float = 0.0
var night_elapsed: float = 0.0
var night_duration: float = 60.0


func setup(p_player: CharacterBody2D, p_world_root: Node) -> void:
	player = p_player
	world_root = p_world_root


func start_night(
	night_number: int,
	p_spawn_center: Vector2,
	p_duration: float,
	p_spawn_point: Variant
) -> void:
	current_night = night_number
	spawn_center = clamp_to_world(p_spawn_center)
	set_active_spawn_point(p_spawn_point)

	night_duration = p_duration
	night_elapsed = 0.0
	pressure_score = 0.0

	total_spawn_budget = get_total_spawn_budget_for_night(night_number)
	alive_cap = get_alive_cap_for_night(night_number)
	spawned_count = 0

	spawn_interval_dynamic = SPAWN_TICK_INTERVAL
	spawn_tick_time_left = 1.0
	is_active = true


func end_night() -> void:
	is_active = false
	pressure_score = 0.0
	night_elapsed = 0.0
	active_spawn_point = null


func set_active_spawn_point(p_spawn_point: Variant) -> void:
	if p_spawn_point == null:
		active_spawn_point = null
		if player != null and is_instance_valid(player):
			spawn_center = clamp_to_world(player.global_position)
		return

	if not is_instance_valid(p_spawn_point):
		active_spawn_point = null
		if player != null and is_instance_valid(player):
			spawn_center = clamp_to_world(player.global_position)
		return

	if not (p_spawn_point is Node2D):
		active_spawn_point = null
		if player != null and is_instance_valid(player):
			spawn_center = clamp_to_world(player.global_position)
		return

	active_spawn_point = p_spawn_point

	var spawn_point_node: Node2D = active_spawn_point as Node2D
	if spawn_point_node != null:
		spawn_center = clamp_to_world(spawn_point_node.global_position)
	elif player != null and is_instance_valid(player):
		spawn_center = clamp_to_world(player.global_position)


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	if player == null:
		return

	if not is_instance_valid(player):
		return

	if player.is_dead:
		return

	night_elapsed += delta
	pressure_score = calculate_pressure()

	spawn_tick_time_left -= delta
	if spawn_tick_time_left > 0.0:
		return

	process_spawn_tick()
	spawn_interval_dynamic = get_spawn_interval_from_pressure(pressure_score)
	spawn_tick_time_left = spawn_interval_dynamic


func process_spawn_tick() -> void:
	if world_root == null:
		return

	if player == null:
		return

	if not is_instance_valid(player):
		return

	if player.is_dead:
		return

	if spawned_count >= total_spawn_budget:
		return

	var alive_count: int = get_alive_monster_count()
	if alive_count >= alive_cap:
		return

	var progress: float = get_night_progress()
	var reserved_budget: int = 0

	if progress < 0.70:
		reserved_budget = maxi(2, int(total_spawn_budget * 0.20))

	var available_budget: int = total_spawn_budget - spawned_count - reserved_budget

	if progress >= 0.70:
		available_budget = total_spawn_budget - spawned_count

	if available_budget <= 0:
		return

	var spawn_strength: int = get_spawn_strength()
	var spawn_count_this_tick: int = min(
		spawn_strength,
		alive_cap - alive_count,
		available_budget
	)

	if spawn_count_this_tick <= 0:
		return

	for _i: int in range(spawn_count_this_tick):
		spawn_single_monster()


func spawn_single_monster() -> void:
	if world_root == null:
		return

	if player == null:
		return

	if not is_instance_valid(player):
		return

	if player.is_dead:
		return

	var spawn_marker: Node2D = monster_spawn_scene.instantiate() as Node2D
	if spawn_marker == null:
		return

	var target_center: Vector2 = spawn_center
	var assigned_target: Variant = player

	if is_instance_valid(active_spawn_point):
		var spawn_point_node: Node2D = active_spawn_point as Node2D
		if spawn_point_node != null and randf() < 0.75:
			target_center = spawn_point_node.global_position
			assigned_target = spawn_point_node
		else:
			target_center = player.global_position
			assigned_target = player
	elif player != null:
		target_center = player.global_position
		assigned_target = player

	var spawn_position: Vector2 = get_spawn_position_around(target_center)

	world_root.add_child(spawn_marker)
	spawn_marker.global_position = spawn_position

	var chosen_type: int = roll_monster_type(current_night)

	if spawn_marker.has_method("configure_spawn"):
		spawn_marker.configure_spawn(current_night, chosen_type, assigned_target)

	spawned_count += 1


func get_spawn_position_around(center: Vector2) -> Vector2:
	for _attempt: int in range(MAX_SPAWN_ATTEMPTS):
		var angle: float = randf_range(0.0, TAU)
		var radius: float = randf_range(SPAWN_RADIUS_MIN, SPAWN_RADIUS_MAX)
		var candidate: Vector2 = center + (Vector2.RIGHT.rotated(angle) * radius)

		if not is_inside_spawn_bounds(candidate):
			continue

		if player != null and is_instance_valid(player) and candidate.distance_to(player.global_position) < 260.0:
			continue

		if is_instance_valid(active_spawn_point):
			var spawn_point_node: Node2D = active_spawn_point as Node2D
			if spawn_point_node != null and candidate.distance_to(spawn_point_node.global_position) < 220.0:
				continue

		return candidate

	return clamp_to_world(center + Vector2(SPAWN_RADIUS_MIN, 0.0))


func is_inside_spawn_bounds(pos: Vector2) -> bool:
	return (
		pos.x >= WORLD_EDGE_PADDING
		and pos.x <= WORLD_SIZE.x - WORLD_EDGE_PADDING
		and pos.y >= WORLD_EDGE_PADDING
		and pos.y <= WORLD_SIZE.y - WORLD_EDGE_PADDING
	)


func clamp_to_world(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, WORLD_EDGE_PADDING, WORLD_SIZE.x - WORLD_EDGE_PADDING),
		clampf(pos.y, WORLD_EDGE_PADDING, WORLD_SIZE.y - WORLD_EDGE_PADDING)
	)


func calculate_pressure() -> float:
	var pressure: float = 0.0
	var monsters: Array[Node] = get_tree().get_nodes_in_group("monsters")

	for node: Node in monsters:
		var monster: CharacterBody2D = node as CharacterBody2D
		if monster == null:
			continue

		if monster.is_dead:
			continue

		pressure += 0.45

		if player != null and is_instance_valid(player):
			if monster.global_position.distance_to(player.global_position) <= PLAYER_NEAR_RADIUS:
				pressure += 1.6

		if is_instance_valid(active_spawn_point):
			var spawn_point_node: Node2D = active_spawn_point as Node2D
			if spawn_point_node != null and monster.global_position.distance_to(spawn_point_node.global_position) <= SPAWN_POINT_NEAR_RADIUS:
				pressure += 2.0

	if player != null and is_instance_valid(player):
		if player.health <= player.max_health * 0.5:
			pressure += 3.0
		if player.health <= player.max_health * 0.25:
			pressure += 3.0

	if is_instance_valid(active_spawn_point):
		var spawn_health: Variant = active_spawn_point.get("health")
		var spawn_max_health: Variant = active_spawn_point.get("max_health")

		if spawn_health is float and spawn_max_health is float:
			var spawn_health_value: float = float(spawn_health)
			var spawn_max_health_value: float = float(spawn_max_health)

			if spawn_health_value <= spawn_max_health_value * 0.5:
				pressure += 3.0
			if spawn_health_value <= spawn_max_health_value * 0.25:
				pressure += 3.0
		elif spawn_health is int and spawn_max_health is int:
			var spawn_health_int: float = float(spawn_health)
			var spawn_max_health_int: float = float(spawn_max_health)

			if spawn_health_int <= spawn_max_health_int * 0.5:
				pressure += 3.0
			if spawn_health_int <= spawn_max_health_int * 0.25:
				pressure += 3.0

	return pressure


func get_spawn_interval_from_pressure(pressure: float) -> float:
	if pressure < 5.0:
		return 1.0
	elif pressure < 10.0:
		return 1.25
	else:
		return 1.55


func get_night_progress() -> float:
	if night_duration <= 0.0:
		return 1.0

	return clamp(night_elapsed / night_duration, 0.0, 1.0)


func get_spawn_strength() -> int:
	var progress: float = get_night_progress()

	if progress < 0.25:
		return 1
	elif progress < 0.75:
		return 2

	return 3


func get_alive_monster_count() -> int:
	var count: int = 0
	var monsters: Array[Node] = get_tree().get_nodes_in_group("monsters")

	for node: Node in monsters:
		var monster: CharacterBody2D = node as CharacterBody2D
		if monster == null:
			continue

		if monster.is_dead:
			continue

		count += 1

	return count


func get_total_spawn_budget_for_night(night_number: int) -> int:
	return 7 + (night_number * 3) + int(night_number)


func get_alive_cap_for_night(night_number: int) -> int:
	return mini(4 + night_number, 14)


func roll_monster_type(night_number: int) -> int:
	var roll: float = randf()

	if night_number <= 2:
		if roll < 0.20:
			return 0
		return 1

	if night_number <= 5:
		if roll < 0.22:
			return 0
		if roll < 0.82:
			return 1
		return 2

	if roll < 0.22:
		return 0

	if roll < 0.60:
		return 1

	return 2
