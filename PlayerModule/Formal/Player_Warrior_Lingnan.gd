# ============================================================
# Player_Warrior_Lingnan.gd - 岭南风皮肤
# 继承 Player_Warrior，覆盖动画映射字典
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
		GlobalDefine.PlayerState.SKILL:   "idle",
		GlobalDefine.PlayerState.HURT:    "idle",
		GlobalDefine.PlayerState.DEAD:    "idle",
	}
