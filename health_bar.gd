extends Node2D

class_name HealthBar

const BAR_WIDTH: float = 30.0
const BAR_HEIGHT: float = 5.0
const BORDER_WIDTH: float = 1.0

const BACKGROUND_COLOR: Color = Color(0.0, 0.0, 0.0, 0.65)
const BORDER_COLOR: Color = Color(1.0, 1.0, 1.0, 0.55)
const HIGH_COLOR: Color = Color(0.20, 0.85, 0.20, 0.95)
const MID_COLOR: Color = Color(0.95, 0.80, 0.20, 0.95)
const LOW_COLOR: Color = Color(0.95, 0.20, 0.20, 0.95)

@export var y_offset: float = -34.0
@export var always_visible: bool = true

var max_health: float = 100.0
var current_health: float = 100.0


func _ready() -> void:
	position = Vector2(0.0, y_offset)
	queue_redraw()


func set_health(new_current_health: float, new_max_health: float) -> void:
	max_health = max(new_max_health, 1.0)
	current_health = clampf(new_current_health, 0.0, max_health)

	if always_visible:
		visible = true
	else:
		visible = current_health < max_health

	queue_redraw()


func _draw() -> void:
	if not visible:
		return

	var bar_position: Vector2 = Vector2(-BAR_WIDTH * 0.5, 0.0)
	var bar_size: Vector2 = Vector2(BAR_WIDTH, BAR_HEIGHT)
	var bar_rect: Rect2 = Rect2(bar_position, bar_size)

	draw_rect(bar_rect, BACKGROUND_COLOR, true)
	draw_rect(bar_rect, BORDER_COLOR, false, BORDER_WIDTH)

	var health_ratio: float = current_health / max_health
	var fill_width: float = BAR_WIDTH * health_ratio

	if fill_width <= 0.0:
		return

	var fill_color: Color = HIGH_COLOR
	if health_ratio <= 0.25:
		fill_color = LOW_COLOR
	elif health_ratio <= 0.60:
		fill_color = MID_COLOR

	var fill_rect: Rect2 = Rect2(
		Vector2(-BAR_WIDTH * 0.5, 0.0),
		Vector2(fill_width, BAR_HEIGHT)
	)

	draw_rect(fill_rect, fill_color, true)
