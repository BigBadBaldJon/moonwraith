extends StaticBody2D

class_name ResourceNode

enum ResourceType {
	WOOD,
	STONE,
	IRON,
	CRYSTAL,
	SCRAP,
	MOON_SHARD
}

const MIN_BLOCK_COUNT: int = 4
const MAX_BLOCK_COUNT: int = 18
const BLOCK_SIZE_MIN: float = 8.0
const BLOCK_SIZE_MAX: float = 15.0
const CLUSTER_RADIUS: float = 18.0
const BLOCK_ROTATION_MIN: float = -35.0
const BLOCK_ROTATION_MAX: float = 35.0

@export var resource_type: ResourceType = ResourceType.WOOD
@export var max_amount: int = 12

var amount: int = 0

@onready var visual_root: Node2D = $Visual

var blocks: Array[ColorRect] = []
var block_tint_offsets: Array[float] = []
var visuals_initialized: bool = false


func _ready() -> void:
	add_to_group("resource_nodes")
	add_to_group("blocking_objects")
	amount = max_amount
	call_deferred("initialize_visuals")


func initialize_visuals() -> void:
	build_organic_blocks()
	visuals_initialized = true
	update_visual()


func harvest(value: int) -> int:
	if amount <= 0:
		return 0

	var harvested: int = min(value, amount)
	amount -= harvested
	update_visual()

	if amount <= 0:
		queue_free()

	return harvested


func set_resource_tier(name: String) -> void:
	match name.to_lower():
		"wood":
			resource_type = ResourceType.WOOD
		"stone":
			resource_type = ResourceType.STONE
		"iron":
			resource_type = ResourceType.IRON
		"crystal":
			resource_type = ResourceType.CRYSTAL
		"scrap":
			resource_type = ResourceType.SCRAP
		"moon_shard", "moon shard":
			resource_type = ResourceType.MOON_SHARD

	build_organic_blocks()
	update_visual()


func get_resource_name() -> String:
	match resource_type:
		ResourceType.WOOD:
			return "wood"
		ResourceType.STONE:
			return "stone"
		ResourceType.IRON:
			return "iron"
		ResourceType.CRYSTAL:
			return "crystal"
		ResourceType.SCRAP:
			return "scrap"
		ResourceType.MOON_SHARD:
			return "moon_shard"
		_:
			return "wood"


func get_blocking_radius() -> float:
	return 18.0


func build_organic_blocks() -> void:
	for child: Node in visual_root.get_children():
		child.queue_free()

	blocks.clear()
	block_tint_offsets.clear()

	var block_count: int = get_block_count_for_max_amount()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(str(global_position) + ":" + str(get_instance_id()) + ":" + str(max_amount) + ":" + str(resource_type))

	var center: Vector2 = Vector2.ZERO

	for index: int in range(block_count):
		var block: ColorRect = ColorRect.new()
		var block_size: float = rng.randf_range(BLOCK_SIZE_MIN, BLOCK_SIZE_MAX)
		block.size = Vector2(block_size, block_size)

		var angle: float = rng.randf_range(0.0, TAU)
		var radial_weight: float = pow(rng.randf(), 1.55)
		var radius: float = CLUSTER_RADIUS * radial_weight
		var jitter: Vector2 = Vector2(rng.randf_range(-2.4, 2.4), rng.randf_range(-2.4, 2.4))

		if index > 0 and index % 3 == 0:
			center += Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))

		var offset: Vector2 = center + (Vector2.RIGHT.rotated(angle) * radius) + jitter
		block.position = offset - (block.size * 0.5)
		block.rotation_degrees = rng.randf_range(BLOCK_ROTATION_MIN, BLOCK_ROTATION_MAX)

		visual_root.add_child(block)
		blocks.append(block)
		block_tint_offsets.append(rng.randf_range(-0.10, 0.10))


func get_block_count_for_max_amount() -> int:
	var amount_ratio: float = clampf(float(max_amount) / 16.0, 0.0, 1.0)
	return clampi(
		int(round(lerp(float(MIN_BLOCK_COUNT), float(MAX_BLOCK_COUNT), amount_ratio))),
		MIN_BLOCK_COUNT,
		MAX_BLOCK_COUNT
	)


func update_visual() -> void:
	var ratio: float = 1.0
	if max_amount > 0:
		ratio = clampf(float(amount) / float(max_amount), 0.0, 1.0)

	if not visuals_initialized or blocks.is_empty():
		return

	var base_color: Color = get_base_color()
	var low_color: Color = base_color.darkened(0.45)
	var mid_color: Color = base_color.darkened(0.20)
	var final_color: Color = base_color

	if ratio > 0.66:
		final_color = base_color
	elif ratio > 0.33:
		final_color = mid_color
	else:
		final_color = low_color

	var visible_blocks: int = 0
	if amount > 0:
		visible_blocks = maxi(1, int(ceil(ratio * float(blocks.size()))))

	for index: int in range(blocks.size()):
		var block: ColorRect = blocks[index]
		if block == null:
			continue

		block.visible = index < visible_blocks
		if not block.visible:
			continue

		var tint_offset: float = 0.0
		if index < block_tint_offsets.size():
			tint_offset = float(block_tint_offsets[index])

		if tint_offset >= 0.0:
			block.color = final_color.lightened(tint_offset)
		else:
			block.color = final_color.darkened(-tint_offset)


func get_base_color() -> Color:
	match resource_type:
		ResourceType.WOOD:
			return Color(0.22, 0.78, 0.25)
		ResourceType.STONE:
			return Color(0.62, 0.62, 0.62)
		ResourceType.IRON:
			return Color(0.55, 0.62, 0.74)
		ResourceType.CRYSTAL:
			return Color(0.40, 0.95, 1.0)
		ResourceType.SCRAP:
			return Color(0.72, 0.54, 0.30)
		ResourceType.MOON_SHARD:
			return Color(0.78, 0.55, 1.0)
		_:
			return Color(0.22, 0.78, 0.25)
