# ============================================================
# Player_Warrior.gd - 战士玩家角色
# 继承 PlayerBase，实现战士特有的攻击和技能逻辑
# ============================================================
extends PlayerBase
class_name Player_Warrior

func _on_ready() -> void:
	super._on_ready()
	if not config:
		config = load("res://DataConfig/Player/WarriorConfig.tres") as PlayerConfig
		_apply_config()
	can_double_jump = true

func _on_attack() -> void:
	super._on_attack()
	if has_hit_this_attack:
		return
	has_hit_this_attack = true

	# 攻击范围：玩家前方扇形区域
	var facing_dir = 1.0 if is_facing_right else -1.0
	var attack_center = global_position + Vector2(facing_dir * 40, -10)
	var attack_range = config.attack_range if config else 80.0

	print("[Warrior] 攻击！范围=%d 中心=%s" % [attack_range, attack_center])

	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		var dist = attack_center.distance_to(enemy.global_position)
		print("  检测敌人 %s 距离=%f" % [enemy.name, dist])
		if dist <= attack_range:
			var result = DamageCalculator.calculate(
				config.attack_damage if config else 25,
				0,
				GlobalDefine.DamageType.PHYSICAL
			)
			# 击退方向：水平为主，略带向上
			var kb_dir = Vector2(facing_dir, -0.3).normalized()
			if enemy.has_method("take_damage"):
				enemy.take_damage(result["damage"], kb_dir)
			EventBus.emit(GlobalDefine.EventName.PLAYER_ATTACK_HIT, {
				"attacker": self,
				"target": enemy,
				"damage": result["damage"],
				"is_crit": result["is_crit"]
			})
			print("  命中！伤害=%d" % result["damage"])
			break

func _on_skill() -> void:
	super._on_skill()
	print("[Warrior] 释放技能：横斩")
	var skill_config = load("res://DataConfig/Skill/SlashConfig.tres") as SkillConfig
	if not skill_config:
		return

	is_attacking = true
	has_hit_this_attack = false
	attack_timer = 0.4
	attack_cooldown_timer = skill_config.cooldown
	_change_state(GlobalDefine.PlayerState.SKILL)

	var facing_dir = 1.0 if is_facing_right else -1.0
	var attack_center = global_position + Vector2(facing_dir * 40, -10)
	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		if attack_center.distance_to(enemy.global_position) <= skill_config.range_x:
			var result = DamageCalculator.calculate(
				skill_config.damage,
				0,
				skill_config.damage_type,
				0.15
			)
			var kb_dir = Vector2(facing_dir, -0.3).normalized()
			if enemy.has_method("take_damage"):
				enemy.take_damage(result["damage"], kb_dir)
			EventBus.emit(GlobalDefine.EventName.PLAYER_ATTACK_HIT, {
				"attacker": self,
				"target": enemy,
				"damage": result["damage"],
				"is_crit": result["is_crit"]
			})

func _get_placeholder_color() -> Color:
	return Color(0.2, 0.6, 0.9)

func _on_die() -> void:
	super._on_die()
	GameManager.trigger_game_over()
