extends Area2D

const ORB_RADIUS: float = 10.0
const MAGNET_RANGE: float = 140.0
const MAGNET_SPEED: float = 260.0

var xp_value: int = 1
var player: CharacterBody2D = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if player == null:
		player = get_tree().get_first_node_in_group("player") as CharacterBody2D

	if player == null:
		return

	var to_player: Vector2 = player.global_position - global_position
	var distance: float = to_player.length()

	if distance <= MAGNET_RANGE and distance > 0.001:
		global_position += to_player.normalized() * MAGNET_SPEED * delta


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		body.add_xp(xp_value)
		queue_free()


func _draw() -> void:
	draw_circle(Vector2.ZERO, ORB_RADIUS, Color.GREEN)
