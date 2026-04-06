extends Node2D

@export var ground_size: int = 2400
const TILE_SIZE: int = 32

const GRASS_CHANCE: float = 0.35
const ROCK_CHANCE: float = 0.08

var day_color: Color = Color(0.45, 0.62, 0.38)
var night_color: Color = Color(0.12, 0.18, 0.14)

var _current_color: Color = day_color

var noise: FastNoiseLite = FastNoiseLite.new()

var terrain_cells: Array = []
var foliage_cells: Array = []


func _ready() -> void:
	z_index = -100

	noise.seed = randi()
	noise.frequency = 0.05

	generate_world()
	queue_redraw()


func generate_world() -> void:
	terrain_cells.clear()
	foliage_cells.clear()

	var half: int = int(ground_size / 2)

	for x: int in range(-half, half, TILE_SIZE):
		for y: int in range(-half, half, TILE_SIZE):
			var n: float = noise.get_noise_2d(x, y)
			var terrain_color: Color = Color(0.30, 0.55, 0.25)

			if n > 0.25:
				terrain_color = Color(0.42, 0.68, 0.32)
			elif n > 0.05:
				terrain_color = Color(0.36, 0.60, 0.28)
			elif n < -0.35:
				terrain_color = Color(0.25, 0.48, 0.22)

			terrain_cells.append([Vector2(x, y), terrain_color])

			var roll: float = randf()
			if roll < ROCK_CHANCE:
				foliage_cells.append([Vector2(x, y), "rock"])
			elif roll < GRASS_CHANCE:
				foliage_cells.append([Vector2(x, y), "grass"])


func set_current_color(value: Color) -> void:
	_current_color = value
	queue_redraw()


func get_current_color() -> Color:
	return _current_color


func set_day() -> void:
	set_current_color(day_color)


func set_night() -> void:
	set_current_color(night_color)


func _draw() -> void:
	draw_terrain()
	draw_foliage()


func draw_terrain() -> void:
	for cell: Variant in terrain_cells:
		var pos: Vector2 = cell[0]
		var base_color: Color = cell[1]
		var final_color: Color = base_color * _current_color
		draw_rect(Rect2(pos, Vector2(TILE_SIZE, TILE_SIZE)), final_color, true)


func draw_foliage() -> void:
	for item: Variant in foliage_cells:
		var pos: Vector2 = item[0]
		var item_type: String = item[1]

		if item_type == "grass":
			draw_line(pos + Vector2(10, 28), pos + Vector2(14, 18), Color(0.15, 0.35, 0.12) * _current_color, 2)
			draw_line(pos + Vector2(16, 28), pos + Vector2(18, 16), Color(0.18, 0.40, 0.14) * _current_color, 2)
			draw_line(pos + Vector2(22, 28), pos + Vector2(20, 18), Color(0.15, 0.35, 0.12) * _current_color, 2)
		elif item_type == "rock":
			draw_circle(pos + Vector2(16, 22), 6, Color(0.35, 0.35, 0.35) * _current_color)
