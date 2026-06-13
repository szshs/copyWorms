# ============================================================
# Player_Warrior_Lingnan.gd - 岭南风皮肤
# 继承 Player_Warrior，覆盖动画映射字典
# 动画列表: idle, walk, attack, attack_in_air, jump, hit, defeated
# SpriteFrames 由 .tscn 中的 SubResource 提供
# ============================================================
extends Player_Warrior
class_name Player_Warrior_Lingnan

func _on_ready():
	super._on_ready()
	_anim_map = {
		GlobalDefine.PlayerState.IDLE:    "idle",
		GlobalDefine.PlayerState.RUN:     "walk",
		GlobalDefine.PlayerState.JUMP:    "jump",
		GlobalDefine.PlayerState.FALL:    "jump",
		GlobalDefine.PlayerState.DASH:    "idle",
		GlobalDefine.PlayerState.ATTACK:  "attack",
		GlobalDefine.PlayerState.SKILL:   "attack",
		GlobalDefine.PlayerState.HURT:    "hit",
		GlobalDefine.PlayerState.DEAD:    "defeated",
	}
	# 岭南皮肤有专属 hit / defeated / attack_in_air 动画
	_has_hit_anim = true
	_has_defeated_anim = true
