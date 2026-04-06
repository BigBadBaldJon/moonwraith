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

@export var resource_type: ResourceType = ResourceType.WOOD
@export var max_amount: int = 12

var amount: int = 0

@onready var cubes: Array = $Visual.get_children()


func _ready() -> void:
	add_to_group("resource_nodes")
	add_to_group("blocking_objects")
	amount = max_amount
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


func update_visual() -> void:
	var ratio: float = 1.0
	if max_amount > 0:
		ratio = float(amount) / float(max_amount)

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

	for cube: Variant in cubes:
		if cube is ColorRect:
			cube.color = final_color


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
