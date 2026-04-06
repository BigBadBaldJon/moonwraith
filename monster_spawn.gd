extends Node2D

const RUNNER_EMERGE_TIME: float = 1.4
const BASIC_EMERGE_TIME: float = 2.0
const BRUTE_EMERGE_TIME: float = 2.8

const BASE_MARKER_RADIUS: float = 18.0
const MAX_MARKER_RADIUS: float = 34.0
const RISE_START_OFFSET: float = 18.0

@export var WORLD_SIZE: Vector2 = Vector2(2400.0, 2400.0)

var monster_scene: PackedScene = preload("res://monster.tscn")

var night_number: int = 1
var monster_type: int = 1
var target_node: Variant = null

var emerge_duration: float = 2.0
var elapsed: float = 0.0
var spawn_complete: bool = false


func _ready() -> void:
	z_index = -1
	emerge_duration = get_emerge_duration_for_type(monster_type)
	queue_redraw()


func _process(delta: float) -> void:
	if spawn_complete:
		return

	elapsed += delta
	queue_redraw()

	if elapsed >= emerge_duration:
		spawn_complete = true
		spawn_monster()


func configure_spawn(p_night_number: int, p_monster_type: int, p_target_node: Variant) -> void:
	night_number = p_night_number
	monster_type = p_monster_type
	target_node = p_target_node
	emerge_duration = get_emerge_duration_for_type(monster_type)


func get_emerge_duration_for_type(type_value: int) -> float:
	match type_value:
		0:
			return RUNNER_EMERGE_TIME
		1:
			return BASIC_EMERGE_TIME
		2:
			return BRUTE_EMERGE_TIME
		_:
			return BASIC_EMERGE_TIME


func spawn_monster() -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		queue_free()
		return

	var monster: CharacterBody2D = monster_scene.instantiate() as CharacterBody2D
	if monster == null:
		queue_free()
		return

	parent_node.add_child(monster)
	monster.global_position = clamp_to_world(global_position)

	monster.configure_for_night(night_number, monster_type)

	var resolved_target: Variant = resolve_target()
	if resolved_target != null:
		monster.target = resolved_target
		if monster.has_method("set_priority_target"):
			monster.set_priority_target(resolved_target)

	queue_free()


func resolve_target() -> Variant:
	if is_target_valid(target_node):
		return target_node

	var spawn_point: Variant = get_nearest_target_in_group(&"spawn_points")
	if spawn_point != null:
		return spawn_point

	var player_target: Variant = get_nearest_target_in_group(&"player")
	if player_target != null:
		return player_target

	return null


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
	if node_2d.is_in_group("player"):
		var player_dead_value: Variant = node_2d.get("is_dead")
		if player_dead_value is bool and player_dead_value:
			return false

	if not node_2d.has_method("take_damage"):
		return false

	return true


func clamp_to_world(pos: Vector2) -> Vector2:
	return Vector2(
		clampf(pos.x, 24.0, WORLD_SIZE.x - 24.0),
		clampf(pos.y, 24.0, WORLD_SIZE.y - 24.0)
	)


func _draw() -> void:
	var progress: float = 0.0
	if emerge_duration > 0.0:
		progress = clamp(elapsed / emerge_duration, 0.0, 1.0)

	var radius: float = lerp(BASE_MARKER_RADIUS, MAX_MARKER_RADIUS, progress)
	var alpha: float = 0.25 + (0.35 * sin(progress * PI))
	var crack_color: Color = Color(0.10, 0.06, 0.06, alpha)
	var inner_color: Color = Color(0.25, 0.06, 0.06, 0.22 + (progress * 0.18))

	draw_circle(Vector2.ZERO, radius, crack_color)
	draw_circle(Vector2.ZERO, radius * 0.62, inner_color)

	var line_length: float = radius * 0.9
	for i: int in range(6):
		var angle: float = (TAU / 6.0) * float(i) + (progress * 0.5)
		var start: Vector2 = Vector2.RIGHT.rotated(angle) * (radius * 0.35)
		var end: Vector2 = Vector2.RIGHT.rotated(angle) * line_length
		draw_line(start, end, Color(0.05, 0.02, 0.02, 0.65), 2.0)

	var rise_offset: float = lerp(RISE_START_OFFSET, 0.0, progress)
	var body_radius: float = radius * 0.42

	match monster_type:
		0:
			draw_circle(Vector2(0.0, rise_offset), body_radius * 0.85, Color(1.0, 0.35, 0.35, 0.50))
		1:
			draw_circle(Vector2(0.0, rise_offset), body_radius, Color(0.9, 0.1, 0.1, 0.55))
		2:
			draw_circle(Vector2(0.0, rise_offset), body_radius * 1.2, Color(0.65, 0.0, 0.0, 0.60))
		_:
			draw_circle(Vector2(0.0, rise_offset), body_radius, Color(0.9, 0.1, 0.1, 0.55))
