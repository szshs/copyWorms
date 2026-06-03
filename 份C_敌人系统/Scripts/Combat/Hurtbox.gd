extends Area2D
class_name Hurtbox

## 受伤判定盒 —— 挂载在敌人身上，接收玩家攻击

func _ready() -> void:
	collision_layer = 32
	collision_mask = 4  # 检测玩家攻击层


func _on_area_entered(area: Area2D) -> void:
	var enemy := get_parent()
	if enemy is EnemyBase:
		var e := enemy as EnemyBase
		if area.get_parent() is Player:
			var player := area.get_parent() as Player
			if player.is_attacking:
				e.take_damage(1, player.global_position)
