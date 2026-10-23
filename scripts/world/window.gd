extends StaticBody2D
## Window: blocks walking but not sight. Hold E (1.2 s) to vault through it;
## the character is moved across the opening only if the far side is free.
## The killer uses the same window through KillerMotor (no teleport).

@export var width_gu := 1.2
@export var thickness_gu := 0.3

var _shape: CollisionShape2D


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"window")
	collision_layer = GameParams.L_WINDOW
	collision_mask = 0
	z_index = 7
	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(width_gu, thickness_gu) * GameParams.PX_PER_GU
	_shape.shape = r
	add_child(_shape)


func get_normal() -> Vector2:
	return Vector2.DOWN.rotated(global_rotation)


## Returns {"ok": bool, "from": Vector2, "to": Vector2, "reason": String} for moving actor across.
func plan_vault(actor: Node2D, radius_px: float) -> Dictionary:
	var n := get_normal()
	var side := signf(n.dot(actor.global_position - global_position))
	if side == 0.0:
		side = 1.0
	var off := GameParams.gu(thickness_gu * 0.5) + radius_px + GameParams.gu(0.12)
	var from := global_position + n * side * off
	var to := global_position - n * side * off
	var q := PhysicsShapeQueryParameters2D.new()
	var c := CircleShape2D.new()
	c.radius = radius_px
	q.shape = c
	q.transform = Transform2D(0.0, to)
	q.collision_mask = GameParams.MOVE_MASK | GameParams.L_SURVIVOR | GameParams.L_KILLER
	q.exclude = [actor.get_rid()]
	var hits := get_world_2d().direct_space_state.intersect_shape(q, 4)
	for h in hits:
		if h.collider != self:
			return {"ok": false, "from": from, "to": to, "reason": "проём занят"}
	return {"ok": true, "from": from, "to": to, "reason": ""}


func on_vaulted(actor: Node) -> void:
	SoundEventBus.emit(&"window", global_position, GameParams.current().window_sound_radius, actor.get_instance_id())


# --- Interactable ------------------------------------------------------------

func get_interact_position() -> Vector2:
	return global_position


func can_interact(actor: Node) -> bool:
	return actor.has_method(&"start_vault")


func get_interact_duration(_actor: Node) -> float:
	return GameParams.current().window_vault_time


func requires_hold() -> bool:
	return true


func get_interact_hint(actor: Node) -> String:
	var plan := plan_vault(actor, GameParams.gu(GameParams.current().survivor_radius))
	if not plan.ok:
		return "Окно: " + plan.reason
	return "Удерживайте E — перелезть через окно"


func can_start(actor: Node) -> bool:
	return plan_vault(actor, GameParams.gu(GameParams.current().survivor_radius)).ok


func interact(_actor: Node) -> void:
	pass  # movement is performed by the actor's channel (start_vault)


func _draw() -> void:
	var w := GameParams.gu(width_gu)
	var t := GameParams.gu(thickness_gu)
	draw_texture_rect(Art.tex("sprites/window.png"), Rect2(-w * 0.5, -t * 0.5, w, t), false)
