extends Node2D

const DAY_DURATION: float = 45.0
const NIGHT_DURATION: float = 60.0

const DAY_AMBIENT: Color = Color(1.0, 1.0, 1.0, 1.0)
const NIGHT_AMBIENT: Color = Color(0.12, 0.14, 0.20, 1.0)

const DAY_TO_NIGHT_TRANSITION_TIME: float = 2.5
const NIGHT_TO_DAY_TRANSITION_TIME: float = 3.5

const DAY_SUNSET_OFFSET: float = 2.5
const NIGHT_SUNRISE_OFFSET: float = 3.5

const HARVEST_RANGE: float = 70.0
const HARVEST_AMOUNT: int = 1

const WORLD_SIZE: Vector2 = Vector2(2400.0, 2400.0)
const WORLD_CENTER: Vector2 = WORLD_SIZE * 0.5
const WORLD_HALF: Vector2 = WORLD_SIZE * 0.5

const RESOURCE_MIN_SPACING: float = 120.0
const RESOURCE_PLAYER_SAFE_RADIUS: float = 260.0
const RESOURCE_CLUSTER_RADIUS: float = 110.0
const RESOURCE_PLACEMENT_ATTEMPTS: int = 40
const RESOURCE_CLUSTER_ATTEMPTS: int = 16

const BASIC_RESOURCE_TOTAL: int = 55
const UNCOMMON_RESOURCE_TOTAL: int = 24
const RARE_RESOURCE_TOTAL: int = 10
const EXOTIC_RESOURCE_TOTAL: int = 5

const TOWER_WOOD_COST: int = 15
const TOWER_STONE_COST: int = 5

const SPAWN_POINT_WOOD_COST: int = 30
const SPAWN_POINT_STONE_COST: int = 10

enum BuildType {NONE, SPAWN_POINT, TOWER}
enum ResourceTier {BASIC, UNCOMMON, RARE, EXOTIC}

@onready var night_director: Node = $NightDirector
@onready var grid_background: Node2D = $GridBackground
@onready var canvas_modulate: CanvasModulate = $CanvasModulate
@onready var player: CharacterBody2D = $Player

@onready var health_label: Label = $HudLayer/Hud/HealthPanel/HealthLabel
@onready var game_over_label: Label = $HudLayer/Hud/GameOverLabel
@onready var phase_label: Label = $HudLayer/Hud/TopLeftPanel/TopLeftUI/PhaseLabel
@onready var night_label: Label = $HudLayer/Hud/TopLeftPanel/TopLeftUI/NightLabel
@onready var level_label: Label = $HudLayer/Hud/TopLeftPanel/TopLeftUI/LevelLabel
@onready var xp_label: Label = $HudLayer/Hud/TopLeftPanel/TopLeftUI/XpLabel

@onready var upgrade_panel: PanelContainer = $HudLayer/Hud/UpgradePanel
@onready var points_label: Label = $HudLayer/Hud/UpgradePanel/VBox/PointsLabel
@onready var damage_button: Button = $HudLayer/Hud/UpgradePanel/VBox/DamageButton
@onready var attack_speed_button: Button = $HudLayer/Hud/UpgradePanel/VBox/AttackSpeedButton
@onready var move_speed_button: Button = $HudLayer/Hud/UpgradePanel/VBox/MoveSpeedButton
@onready var max_health_button: Button = $HudLayer/Hud/UpgradePanel/VBox/MaxHealthButton
@onready var range_button: Button = $HudLayer/Hud/UpgradePanel/VBox/RangeButton
@onready var close_label: Label = $HudLayer/Hud/UpgradePanel/VBox/CloseLabel

var tower_scene: PackedScene = preload("res://tower.tscn")
var spawn_point_scene: PackedScene = preload("res://spawn_point.tscn")
var basic_resource_scene: PackedScene = preload("res://resource_node.tscn")
var uncommon_resource_scene: PackedScene = preload("res://resource_node.tscn")
var rare_resource_scene: PackedScene = preload("res://resource_node.tscn")
var exotic_resource_scene: PackedScene = preload("res://resource_node.tscn")

var is_night: bool = false
var current_night: int = 0
var phase_time_left: float = 0.0

var transition_tween: Tween = null

var wood: int = 0
var stone: int = 0
var iron: int = 0
var crystal: int = 0
var selected_build_type: BuildType = BuildType.TOWER
var current_spawn_point: StaticBody2D = null
var respawn_in_progress: bool = false


func _ready() -> void:
	randomize()
	player.global_position = clamp_to_world(WORLD_CENTER, 24.0)
	night_director.setup(player, self)
	canvas_modulate.color = DAY_AMBIENT
	player.set_night_light_enabled(false)

	health_label.modulate = Color.BLACK
	game_over_label.modulate = Color.BLACK
	phase_label.modulate = Color.BLACK
	night_label.modulate = Color.BLACK
	level_label.modulate = Color.BLACK
	xp_label.modulate = Color.BLACK
	points_label.modulate = Color.BLACK
	close_label.modulate = Color.BLACK

	upgrade_panel.visible = false
	close_label.text = "Press U to close"

	damage_button.pressed.connect(_on_damage_button_pressed)
	attack_speed_button.pressed.connect(_on_attack_speed_button_pressed)
	move_speed_button.pressed.connect(_on_move_speed_button_pressed)
	max_health_button.pressed.connect(_on_max_health_button_pressed)
	range_button.pressed.connect(_on_range_button_pressed)

	generate_full_resource_map()
	start_day()


func _process(delta: float) -> void:
	phase_time_left -= delta

	if phase_time_left < 0.0:
		phase_time_left = 0.0

	handle_build_selection()
	handle_player_death_state()
	update_ui()
	handle_upgrade_panel_toggle()


func _physics_process(_delta: float) -> void:
	if night_director != null:
		night_director.set_active_spawn_point(current_spawn_point)

	clamp_dynamic_world_objects()
	handle_player_attack()
	handle_build_placement()
	handle_harvest()


func update_ui() -> void:
	health_label.text = "HP: " + str(int(player.health)) + "/" + str(int(player.max_health))
	level_label.text = "Level: " + str(player.level)
	xp_label.text = "XP: " + str(player.xp) + "/" + str(player.xp_to_next_level)
	points_label.text = "Upgrade Points: " + str(player.upgrade_points)

	if player.is_dead and not has_valid_spawn_point():
		game_over_label.text = "GAME OVER"
	else:
		game_over_label.text = ""

	if is_night:
		phase_label.text = "Phase: Night (" + str(int(phase_time_left)) + "s)"
	else:
		phase_label.text = "Phase: Day (" + str(int(phase_time_left)) + "s)"

	night_label.text = "Night: " + str(current_night) + "   Wood: " + str(wood) + "   Stone: " + str(stone) + "   Iron: " + str(iron) + "   Crystal: " + str(crystal) + "   Build: " + get_build_type_name()


func start_day() -> void:
	is_night = false
	phase_time_left = DAY_DURATION
	canvas_modulate.color = DAY_AMBIENT
	player.set_night_light_enabled(false)
	grid_background.set_day()
	night_director.end_night()
	replenish_resources_if_needed()

	run_day_phase()


func start_night() -> void:
	is_night = true
	current_night += 1
	phase_time_left = NIGHT_DURATION

	grid_background.set_night()

	var night_center: Vector2 = player.global_position

	if has_valid_spawn_point():
		night_center = current_spawn_point.global_position

	night_director.start_night(
		current_night,
		clamp_to_world(night_center, 24.0),
		NIGHT_DURATION,
		current_spawn_point
	)
	run_night_phase()


func transition_to_day() -> void:
	stop_transition_tween()

	transition_tween = create_tween()
	transition_tween.tween_property(
		canvas_modulate,
		"color",
		DAY_AMBIENT,
		NIGHT_TO_DAY_TRANSITION_TIME
	)


func transition_to_night() -> void:
	stop_transition_tween()

	transition_tween = create_tween()
	transition_tween.tween_property(
		canvas_modulate,
		"color",
		NIGHT_AMBIENT,
		DAY_TO_NIGHT_TRANSITION_TIME
	)


func stop_transition_tween() -> void:
	if transition_tween != null:
		transition_tween.kill()
		transition_tween = null


func run_day_phase() -> void:
	await get_tree().create_timer(DAY_DURATION - DAY_SUNSET_OFFSET).timeout

	if player.is_dead:
		return

	transition_to_night()
	player.set_night_light_enabled(true)

	await get_tree().create_timer(DAY_SUNSET_OFFSET).timeout

	if player.is_dead:
		return

	start_night()


func run_night_phase() -> void:
	await get_tree().create_timer(NIGHT_DURATION - NIGHT_SUNRISE_OFFSET).timeout

	if player.is_dead:
		return

	night_director.end_night()
	transition_to_day()
	player.set_night_light_enabled(false)

	await get_tree().create_timer(NIGHT_SUNRISE_OFFSET).timeout

	if player.is_dead:
		return

	clear_monsters()
	start_day()


func clear_monsters() -> void:
	for child: Node in get_children():
		if child is CharacterBody2D and child.scene_file_path == "res://monster.tscn":
			child.queue_free()


func handle_player_attack() -> void:
	if player.is_dead:
		return

	if upgrade_panel.visible:
		return

	if not Input.is_action_just_pressed("attack"):
		return

	player.perform_attack()


func handle_build_selection() -> void:
	if Input.is_action_just_pressed("build_spawn"):
		selected_build_type = BuildType.SPAWN_POINT

	if Input.is_action_just_pressed("build_tower"):
		selected_build_type = BuildType.TOWER


func handle_build_placement() -> void:
	if player.is_dead:
		return

	if upgrade_panel.visible:
		return

	if is_night:
		return

	if not Input.is_action_just_pressed("place_object"):
		return

	match selected_build_type:
		BuildType.SPAWN_POINT:
			try_place_spawn_point()
		BuildType.TOWER:
			try_place_tower()


func try_place_tower() -> void:
	if wood < TOWER_WOOD_COST:
		return

	if stone < TOWER_STONE_COST:
		return

	var place_distance: float = 70.0
	var placement_position: Vector2 = clamp_to_world(player.global_position + (player.facing_direction * place_distance), 24.0)

	if not can_place_tower_at(placement_position):
		return

	var tower: StaticBody2D = tower_scene.instantiate()
	add_child(tower)
	tower.global_position = placement_position

	wood -= TOWER_WOOD_COST
	stone -= TOWER_STONE_COST


func try_place_spawn_point() -> void:
	if wood < SPAWN_POINT_WOOD_COST:
		return

	if stone < SPAWN_POINT_STONE_COST:
		return

	var place_distance: float = 70.0
	var placement_position: Vector2 = clamp_to_world(player.global_position + (player.facing_direction * place_distance), 24.0)

	if not can_place_spawn_point_at(placement_position):
		return

	if current_spawn_point != null and is_instance_valid(current_spawn_point):
		current_spawn_point.queue_free()
		current_spawn_point = null

	var spawn_point: StaticBody2D = spawn_point_scene.instantiate()
	add_child(spawn_point)
	spawn_point.global_position = placement_position

	current_spawn_point = spawn_point
	wood -= SPAWN_POINT_WOOD_COST
	stone -= SPAWN_POINT_STONE_COST


func handle_harvest() -> void:
	if player.is_dead:
		return

	if upgrade_panel.visible:
		return

	if is_night:
		return

	if not Input.is_action_just_pressed("harvest"):
		return

	var nearest_resource: Node = get_nearest_resource_node(HARVEST_RANGE)

	if nearest_resource == null:
		return

	if nearest_resource.has_method("harvest"):
		var resource_name: String = get_resource_name_from_node(nearest_resource)
		var gained: Variant = nearest_resource.call("harvest", HARVEST_AMOUNT)

		if gained is int:
			add_resource_by_name(resource_name, int(gained))


func get_nearest_resource_node(max_range: float) -> Node:
	var nearest: Node = null
	var nearest_distance: float = max_range

	for child: Node in get_children():
		if not child.has_method("harvest"):
			continue

		if not (child is Node2D):
			continue

		var node_2d: Node2D = child as Node2D
		var distance: float = player.global_position.distance_to(node_2d.global_position)

		if distance <= nearest_distance:
			nearest = child
			nearest_distance = distance

	return nearest


func get_resource_name_from_node(node: Node) -> String:
	if node.has_method("get_resource_name"):
		var resource_name: Variant = node.call("get_resource_name")

		if resource_name is String:
			return String(resource_name)

	var meta_name: Variant = node.get_meta("resource_name", "Wood")

	if meta_name is String:
		return String(meta_name)

	return "Wood"


func add_resource_by_name(resource_name: String, amount: int) -> void:
	match resource_name.to_lower():
		"wood":
			wood += amount
		"stone":
			stone += amount
		"iron":
			iron += amount
		"crystal":
			crystal += amount
		_:
			wood += amount


func generate_full_resource_map() -> void:
	clear_existing_resources()
	spawn_resource_tier(basic_resource_scene, BASIC_RESOURCE_TOTAL, ResourceTier.BASIC)
	spawn_resource_tier(uncommon_resource_scene, UNCOMMON_RESOURCE_TOTAL, ResourceTier.UNCOMMON)
	spawn_resource_tier(rare_resource_scene, RARE_RESOURCE_TOTAL, ResourceTier.RARE)
	spawn_resource_tier(exotic_resource_scene, EXOTIC_RESOURCE_TOTAL, ResourceTier.EXOTIC)


func replenish_resources_if_needed() -> void:
	ensure_resource_tier_count(basic_resource_scene, BASIC_RESOURCE_TOTAL, ResourceTier.BASIC)
	ensure_resource_tier_count(uncommon_resource_scene, UNCOMMON_RESOURCE_TOTAL, ResourceTier.UNCOMMON)
	ensure_resource_tier_count(rare_resource_scene, RARE_RESOURCE_TOTAL, ResourceTier.RARE)
	ensure_resource_tier_count(exotic_resource_scene, EXOTIC_RESOURCE_TOTAL, ResourceTier.EXOTIC)


func clear_existing_resources() -> void:
	for child: Node in get_children():
		if child.has_method("harvest"):
			child.queue_free()


func ensure_resource_tier_count(scene: PackedScene, target_total: int, tier: ResourceTier) -> void:
	var current_count: int = count_resource_nodes_in_tier(tier)
	var missing: int = target_total - current_count

	if missing <= 0:
		return

	for _i: int in range(missing):
		spawn_single_resource_node(scene, tier)


func count_resource_nodes_in_tier(tier: ResourceTier) -> int:
	var count: int = 0

	for child: Node in get_children():
		if not child.has_method("harvest"):
			continue

		if int(child.get_meta("resource_tier", -1)) == int(tier):
			count += 1

	return count


func spawn_resource_tier(scene: PackedScene, total: int, tier: ResourceTier) -> void:
	var clusters: int = maxi(1, total / 4)
	var remaining: int = total

	for cluster_index: int in range(clusters):
		var clusters_left: int = clusters - cluster_index
		var amount_in_cluster: int = maxi(1, int(round(float(remaining) / float(clusters_left))))
		var center: Vector2 = find_resource_position_for_tier(tier)
		spawn_resource_cluster(scene, center, amount_in_cluster, tier)
		remaining -= amount_in_cluster


func spawn_resource_cluster(scene: PackedScene, center: Vector2, amount: int, tier: ResourceTier) -> void:
	for _i: int in range(amount):
		var placed: bool = false

		for _attempt: int in range(RESOURCE_CLUSTER_ATTEMPTS):
			var offset: Vector2 = Vector2(
				randf_range(-RESOURCE_CLUSTER_RADIUS, RESOURCE_CLUSTER_RADIUS),
				randf_range(-RESOURCE_CLUSTER_RADIUS, RESOURCE_CLUSTER_RADIUS)
			)
			var candidate: Vector2 = clamp_to_world(center + offset, 24.0)

			if can_place_resource_at(candidate):
				spawn_resource_instance(scene, candidate, tier)
				placed = true
				break

		if not placed:
			spawn_single_resource_node(scene, tier)


func spawn_single_resource_node(scene: PackedScene, tier: ResourceTier) -> void:
	var candidate: Vector2 = find_resource_position_for_tier(tier)
	spawn_resource_instance(scene, candidate, tier)


func spawn_resource_instance(scene: PackedScene, position: Vector2, tier: ResourceTier) -> void:
	var node: Node = scene.instantiate()
	add_child(node)

	if node is Node2D:
		(node as Node2D).global_position = position

	var resource_name: String = get_resource_tier_name(tier)
	node.set_meta("resource_tier", int(tier))
	node.set_meta("resource_name", resource_name)

	if node.has_method("set_resource_tier"):
		node.call("set_resource_tier", resource_name)


func find_resource_position_for_tier(tier: ResourceTier) -> Vector2:
	for _attempt: int in range(RESOURCE_PLACEMENT_ATTEMPTS):
		var candidate: Vector2 = Vector2(
			randf_range(0.0, WORLD_SIZE.x),
			randf_range(0.0, WORLD_SIZE.y)
		)

		if not can_place_resource_at(candidate):
			continue

		var normalized_distance: float = get_distance_from_center(candidate) / get_max_center_distance()

		match tier:
			ResourceTier.BASIC:
				if normalized_distance <= 1.0:
					return candidate
			ResourceTier.UNCOMMON:
				if normalized_distance >= 0.25:
					return candidate
			ResourceTier.RARE:
				if normalized_distance >= 0.45:
					return candidate
			ResourceTier.EXOTIC:
				if normalized_distance >= 0.65:
					return candidate

	return Vector2(
		randf_range(0.0, WORLD_SIZE.x),
		randf_range(0.0, WORLD_SIZE.y)
	)


func can_place_resource_at(position: Vector2) -> bool:
	if position.distance_to(WORLD_CENTER) < RESOURCE_PLAYER_SAFE_RADIUS:
		return false

	for child: Node in get_children():
		if not (child is Node2D):
			continue

		if child == player:
			continue

		if child.scene_file_path == "res://monster.tscn":
			continue

		var node_2d: Node2D = child as Node2D

		if node_2d.global_position.distance_to(position) < RESOURCE_MIN_SPACING:
			return false

	return true


func handle_upgrade_panel_toggle() -> void:
	if Input.is_action_just_pressed("open_upgrades"):
		upgrade_panel.visible = not upgrade_panel.visible


func handle_player_death_state() -> void:
	if not player.is_dead:
		return

	if respawn_in_progress:
		return

	if has_valid_spawn_point():
		respawn_in_progress = true
		respawn_player()


func respawn_player() -> void:
	if not has_valid_spawn_point():
		respawn_in_progress = false
		return

	player.respawn_at(clamp_to_world(current_spawn_point.global_position, 24.0))
	respawn_in_progress = false


func has_valid_spawn_point() -> bool:
	return current_spawn_point != null and is_instance_valid(current_spawn_point)


func get_build_type_name() -> String:
	match selected_build_type:
		BuildType.SPAWN_POINT:
			return "Spawn"
		BuildType.TOWER:
			return "Tower"
		_:
			return "None"


func _on_damage_button_pressed() -> void:
	player.spend_point_on_damage()


func _on_attack_speed_button_pressed() -> void:
	player.spend_point_on_attack_speed()


func _on_move_speed_button_pressed() -> void:
	player.spend_point_on_move_speed()


func _on_max_health_button_pressed() -> void:
	player.spend_point_on_max_health()


func _on_range_button_pressed() -> void:
	player.spend_point_on_range()


func can_place_tower_at(position: Vector2, min_distance: float = 70.0) -> bool:
	if position.distance_to(player.global_position) < 55.0:
		return false

	var towers: Array[Node] = get_tree().get_nodes_in_group("towers")

	for tower_node: Node in towers:
		var tower: StaticBody2D = tower_node as StaticBody2D

		if tower == null:
			continue

		if tower.global_position.distance_to(position) < min_distance:
			return false

	var spawn_points: Array[Node] = get_tree().get_nodes_in_group("spawn_points")

	for spawn_node: Node in spawn_points:
		var spawn_point: StaticBody2D = spawn_node as StaticBody2D

		if spawn_point == null:
			continue

		if spawn_point.global_position.distance_to(position) < 90.0:
			return false

	for child: Node in get_children():
		if not (child is Node2D):
			continue

		if child.is_in_group("resource_nodes"):
			var resource_node: Node2D = child as Node2D

			if resource_node != null and resource_node.global_position.distance_to(position) < 55.0:
				return false

	return true


func can_place_spawn_point_at(position: Vector2, min_distance: float = 110.0) -> bool:
	if position.distance_to(player.global_position) < 70.0:
		return false

	var towers: Array[Node] = get_tree().get_nodes_in_group("towers")

	for tower_node: Node in towers:
		var tower: StaticBody2D = tower_node as StaticBody2D

		if tower == null:
			continue

		if tower.global_position.distance_to(position) < min_distance:
			return false

	var spawn_points: Array[Node] = get_tree().get_nodes_in_group("spawn_points")

	for spawn_node: Node in spawn_points:
		var spawn_point: StaticBody2D = spawn_node as StaticBody2D

		if spawn_point == null:
			continue

		if spawn_point.global_position.distance_to(position) < min_distance:
			return false

	for child: Node in get_children():
		if not (child is Node2D):
			continue

		if child.is_in_group("resource_nodes"):
			var resource_node: Node2D = child as Node2D

			if resource_node != null and resource_node.global_position.distance_to(position) < 70.0:
				return false

	return true


func clamp_dynamic_world_objects() -> void:
	player.global_position = clamp_to_world(player.global_position, 24.0)

	if has_valid_spawn_point():
		current_spawn_point.global_position = clamp_to_world(current_spawn_point.global_position, 24.0)

	for child: Node in get_children():
		if child == player:
			continue

		if not (child is Node2D):
			continue

		if child == current_spawn_point:
			continue

		var node_2d: Node2D = child as Node2D
		var padding: float = 8.0

		if child.is_in_group("resource_nodes"):
			padding = 18.0
		elif child.is_in_group("towers"):
			padding = 18.0
		elif child.is_in_group("spawn_points"):
			padding = 18.0
		elif child.is_in_group("monsters"):
			padding = 20.0

		node_2d.global_position = clamp_to_world(node_2d.global_position, padding)


func clamp_to_world(position: Vector2, padding: float = 0.0) -> Vector2:
	return Vector2(
		clampf(position.x, padding, WORLD_SIZE.x - padding),
		clampf(position.y, padding, WORLD_SIZE.y - padding)
	)


func get_distance_from_center(position: Vector2) -> float:
	return WORLD_CENTER.distance_to(position)


func get_max_center_distance() -> float:
	return WORLD_CENTER.distance_to(Vector2.ZERO)


func get_resource_tier_name(tier: ResourceTier) -> String:
	match tier:
		ResourceTier.BASIC:
			return "Wood"
		ResourceTier.UNCOMMON:
			return "Stone"
		ResourceTier.RARE:
			return "Iron"
		ResourceTier.EXOTIC:
			return "Crystal"
		_:
			return "Unknown"
