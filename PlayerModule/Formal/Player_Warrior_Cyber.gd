extends Player_Warrior
class_name Player_Warrior_Cyber

var _hit_pending: bool = false

func _on_ready():
	super._on_ready()
	_anim_map = {
		GlobalDefine.PlayerState.IDLE:   "idle",
		GlobalDefine.PlayerState.RUN:    "walk",
		GlobalDefine.PlayerState.JUMP:   "jump",
		GlobalDefine.PlayerState.FALL:   "jump",
		GlobalDefine.PlayerState.DASH:   "idle",
		GlobalDefine.PlayerState.ATTACK: "attack",
		GlobalDefine.PlayerState.SKILL:  "attack",
		GlobalDefine.PlayerState.HURT:   "hit",
		GlobalDefine.PlayerState.DEAD:   "defeated",
	}
	_has_hit_anim = true
	_has_defeated_anim = true

func _on_attack() -> void:
	_hit_pending = true
	get_tree().create_timer(0.1).timeout.connect(_do_delayed_hit)

func _do_delayed_hit() -> void:
	if not _hit_pending:
		return
	_hit_pending = false
	if not is_attacking or has_hit_this_attack:
		return
	has_hit_this_attack = true

	var attack_dir := _get_attack_direction()
	var attack_center = global_position + attack_dir * 40
	var attack_range = config.attack_range if config else 80.0

	for enemy in GameManager.get_enemies():
		if not is_instance_valid(enemy):
			continue
		if attack_center.distance_to(enemy.global_position) <= attack_range:
			var result = DamageCalculator.calculate(
				config.attack_damage if config else 25, 0, GlobalDefine.DamageType.PHYSICAL
			)
			var kb_dir = attack_dir.normalized() if attack_dir != Vector2.ZERO else Vector2(1, 0)
			if enemy.has_method("take_damage"):
				enemy.take_damage(result["damage"], kb_dir)
			EventBus.emit(GlobalDefine.EventName.PLAYER_ATTACK_HIT, {
				"attacker": self, "target": enemy, "damage": result["damage"], "is_crit": result["is_crit"]
			})
			break
