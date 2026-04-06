extends Area2D

const DRAW_RADIUS: float = 4.0

@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var impact_sound: AudioStreamPlayer2D = $ImpactSound

@export var speed: float = 420.0
@export var damage: float = 6.0
@export var max_distance: float = 260.0
@export var faction: StringName = &"tower"
@export var knockback_force: float = 140.0

var direction: Vector2 = Vector2.RIGHT
var travelled_distance: float = 0.0
var is_active: bool = false


func _ready() -> void:
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = DRAW_RADIUS
	collision_shape.shape = shape

	body_entered.connect(_on_body_entered)
	queue_redraw()


func setup(p_direction: Vector2, p_damage: float, p_faction: StringName) -> void:
	direction = p_direction.normalized()
	damage = p_damage
	faction = p_faction
	travelled_distance = 0.0
	is_active = true
	rotation = direction.angle()
	queue_redraw()


func _physics_process(delta: float) -> void:
	if not is_active:
		return

	var movement: Vector2 = direction * speed * delta
	global_position += movement
	travelled_distance += movement.length()

	if travelled_distance >= max_distance:
		is_active = false
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	if not is_active:
		return

	if not _can_hit(body):
		return

	if body.has_method("take_damage"):
		body.call("take_damage", damage)

	if body.has_method("apply_knockback"):
		body.call("apply_knockback", direction, knockback_force)

	_play_impact_sound()

	is_active = false
	queue_free()


func _play_impact_sound() -> void:
	if impact_sound == null:
		return

	if impact_sound.stream == null:
		return

	var temp_player: AudioStreamPlayer2D = AudioStreamPlayer2D.new()
	temp_player.stream = impact_sound.stream
	temp_player.volume_db = impact_sound.volume_db
	temp_player.pitch_scale = randf_range(0.96, 1.04)
	temp_player.max_polyphony = 1
	temp_player.global_position = global_position

	get_tree().current_scene.add_child(temp_player)
	temp_player.play()
	temp_player.finished.connect(temp_player.queue_free)


func _can_hit(body: Node2D) -> bool:
	match faction:
		&"tower", &"player":
			return body.is_in_group("monsters")
		&"monster":
			return body.is_in_group("player")
		_:
			return false


func _draw() -> void:
	draw_circle(Vector2.ZERO, DRAW_RADIUS, Color.WHITE)
