extends Area2D
class_name Hitbox

## 攻击判定盒 —— 挂载在敌人身上，对玩家造成伤害

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1  # 检测玩家
	monitoring = false
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body is Player:
		var player := body as Player
		var kb_dir := (player.global_position - global_position).normalized()
		kb_dir.y = -0.3
		player.take_damage(1, kb_dir.normalized())


func activate() -> void:
	monitoring = true


func deactivate() -> void:
	monitoring = false
