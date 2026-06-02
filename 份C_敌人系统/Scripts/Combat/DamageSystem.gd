extends Node
class_name DamageSystem

## 伤害系统 —— 统一管理伤害计算（可扩展防御、暴击等）


static func calculate_damage(base_damage: int, _attacker: Node2D, _defender: Node2D) -> int:
	# 基础伤害计算，后续可扩展护甲、暴击等
	return base_damage
