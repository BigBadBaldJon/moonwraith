extends Node2D

const GRID_SIZE: int = 64
const LINE_WIDTH: float = 1.0
const DRAW_MARGIN: int = 128

const DAY_BACKGROUND: Color = Color(1.0, 1.0, 1.0)
const NIGHT_BACKGROUND: Color = Color(0.10, 0.12, 0.18)

const DAY_GRID: Color = Color(0.0, 0.0, 0.0, 0.18)
const NIGHT_GRID: Color = Color(0.6, 0.7, 1.0, 0.18)

var background_color: Color = DAY_BACKGROUND
var grid_color: Color = DAY_GRID

@onready var camera: Camera2D = $"../Player/Camera2D"

var transition_tween: Tween = null


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var center: Vector2 = camera.get_screen_center_position()
	var viewport_size: Vector2 = get_viewport_rect().size
	var rect_pos: Vector2 = center - viewport_size * 0.5

	draw_rect(Rect2(rect_pos, viewport_size), background_color, true)

	var left: float = center.x - (viewport_size.x * 0.5) - DRAW_MARGIN
	var right: float = center.x + (viewport_size.x * 0.5) + DRAW_MARGIN
	var top: float = center.y - (viewport_size.y * 0.5) - DRAW_MARGIN
	var bottom: float = center.y + (viewport_size.y * 0.5) + DRAW_MARGIN

	var start_x: int = int(floor(left / GRID_SIZE)) * GRID_SIZE
	var end_x: int = int(ceil(right / GRID_SIZE)) * GRID_SIZE
	var start_y: int = int(floor(top / GRID_SIZE)) * GRID_SIZE
	var end_y: int = int(ceil(bottom / GRID_SIZE)) * GRID_SIZE

	for x: int in range(start_x, end_x + GRID_SIZE, GRID_SIZE):
		draw_line(Vector2(x, top), Vector2(x, bottom), grid_color, LINE_WIDTH)

	for y: int in range(start_y, end_y + GRID_SIZE, GRID_SIZE):
		draw_line(Vector2(left, y), Vector2(right, y), grid_color, LINE_WIDTH)


func set_day() -> void:
	start_transition(DAY_BACKGROUND, DAY_GRID, 3.0)


func set_night() -> void:
	start_transition(NIGHT_BACKGROUND, NIGHT_GRID, 2.5)


func start_transition(target_bg: Color, target_grid: Color, time: float) -> void:
	if transition_tween != null:
		transition_tween.kill()

	transition_tween = create_tween()
	transition_tween.set_parallel(true)
	transition_tween.tween_property(self, "background_color", target_bg, time)
	transition_tween.tween_property(self, "grid_color", target_grid, time)
