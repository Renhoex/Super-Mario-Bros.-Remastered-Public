extends Enemy

@export var player_range := 24


func _enter_tree() -> void:
	$Animation.play("Hide")

func _ready() -> void:
	if is_equal_approx(abs(global_rotation_degrees), 180) == false:
		$Sprite/Hitbox/UpsideDownExtension.queue_free()
	else:
		on_timeout()
		# advance the pirahna plant to be offset when upside down
		$Animation.advance(1.0 * $Animation.speed_scale)
	# adjust timer to match speed
	$Timer.wait_time /= $Animation.speed_scale
	$Timer.start()

func on_timeout() -> void:
	var player = get_tree().get_first_node_in_group("Players")
	if abs(player.global_position.x - global_position.x) >= player_range:
		$Animation.play("Rise")
