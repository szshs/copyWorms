# 工作会话总结 — 花旦Boss + Level_05 完整实现

> **用途**: 新建对话窗口继承此文档，即可同步所有工作经验。
> **最后更新**: 2026-06-19
> **涉及文件**: `Enemy_BossHuadan`, `SwordEnergy`, `Level_05`, `Level_04`, `PlayerBase`

---

## 1. 项目概况

Godot 4.x 2D 动作游戏，关卡系统为 Level_04（维度侵蚀）→ Level_05（双世界撕裂 + Boss战）。

### 关键全局系统

| 系统 | 文件 | 说明 |
|---|---|---|
| EventBus | `Global/EventBus.gd` | 全局事件总线，支持 `emit`/`subscribe`/`unsubscribe` |
| GlobalDefine | `Global/GlobalDefine.gd` | 碰撞层常量、事件名、状态枚举 |
| GameManager | `Global/GameManager.gd` | 全局单例，管理 `player_ref`、`dream_runtime_flags` |
| InputManager | `Global/` | `block_input(key, source)` / `unblock_input(key)` 多层输入屏蔽 |
| LevelBase | `LevelModule/Formal/LevelBase.gd` | 关卡基类 |
| EnemyBase | `EnemyModule/Formal/EnemyBase.gd` | 敌人基类，有 `stun_timer`、`take_damage`、`config` 等 |
| InteractiveObject | `LevelModule/Formal/InteractiveObject.gd` | 交互物基类，`object_id`、`is_player_in_range`、`mark_completed()` |
| SmoothCamera | Player 内部节点 | 自定义相机，`limit_left/right/top/bottom`、`zoom`、`bind_target()` |
| PlayerBase | `PlayerModule/Formal/PlayerBase.gd` | 玩家基类，`current_health`/`max_health`、`is_facing_right` |

### 事件名（事件名）

- `HEALTH_CHANGED` — {target, current_health, max_health}
- `ENEMY_HURT` — {enemy, ...}
- `ENEMY_DIED` — {enemy, ...}
- `INTERACTIVE_OBJECT_TRIGGERED` — {object_id, ...}
- `LEVEL_COMPLETE` — {level, next_level}
- `PLAYER_ATTACK_HIT` / `PLAYER_HURT` — 用于战斗触发

### 碰撞层

```
TERRAIN = 1, PLAYER = 2, ENEMY = 4, INTERACT = 8
```

---

## 2. Boss: Enemy_BossHuadan（花旦）

### 2.1 文件清单

| 文件 | 作用 |
|---|---|
| `EnemyModule/Formal/Enemy_BossHuadan.gd` | Boss AI 脚本 (619行，4阶段系统) |
| `EnemyModule/Formal/Enemy_BossHuadan.tscn` | Boss 场景（AnimatedSprite2D + MeleeHitbox） |
| `EnemyModule/Formal/SwordEnergy.gd` | 剑气弹幕 (42行) |
| `EnemyModule/Formal/SwordEnergy.tscn` | 剑气场景 |
| `Assets/Effects/剑气.png` | 剑气贴图 |
| `Assets/Sprites/boss_huadan/boss待机.png` | 待机帧(4×3, 128×128) |
| `Assets/Sprites/boss_huadan/boss行走.png` | 行走帧(4×3, 128×128) |
| `Assets/Sprites/boss_huadan/boss攻击.png` | 攻击帧(4×4, 256×256) |
| `Tools/SwordQiProjectile.gd` | 玩家剑气弹体（支持Boss战追踪） |
| `Global/GameManager.gd` | 新增 `boss_target` 字段 |

### 2.2 Boss 核心参数（4阶段制）

```gdscript
max_health = 600                          # 固定血量（覆盖 CleanerConfig 的 30）
SPRITE_SCALE = 1.2                        # 统一缩放
CollisionSize = 80×160                    # 碰撞体
MeleeHitboxSize = 180×200                 # 近战判定（扩大后）
MeleeHitboxOffset = ±100                  # 近战判定偏移

# 冷却
RANGED_COOLDOWN = 1.2s
MELEE_COOLDOWN = 1.5s
EVADE_COOLDOWN = 1.5s
JUMP_COOLDOWN = 3.0s

# 跳跃（阶段递增）
PHASE_JUMP = [0, -500, -520, -580, -720]
JUMP_HEIGHT_THRESHOLD = 80
```

### 2.3 四阶段参数表

| 参数 | Phase 1 | Phase 2 | Phase 3 | Phase 4 |
|---|---|---|---|---|
| HP 范围 | 600~451 | 450~301 | 300~151 | 150~0 |
| 移速 | 200 | 220 | 250 | 350 |
| 跳跃速度 | -500 | -520 | -580 | -720 |
| 剑气伤害 | 12 | 14 | 18 | 22 |
| 近战伤害 | 20 | 22 | 26 | 32 |
| CD 倍率 | 1.0 | 0.8 | 0.6 | 0.4 |
| 最佳距离 | 300 | 250 | 200 | 150 |
| 闪避概率 | 70% | 55% | 30% | 15% |
| 攻击打断 | ✅ | ❌ | ❌ | ❌ |
| 剑气数量 | 1 | 1 | 3 | 3 |
| 悬停系统 | — | — | ✅ 10s | — |
| 近战+剑气 | — | — | — | ✅ |

### 2.4 Boss 行为枚举

```gdscript
enum BossAction { IDLE, APPROACH, RETREAT, RANGED, MELEE, EVADE, JUMP, HOVER }
```

### 2.5 各阶段特性

**Phase 1 (100%~75%)**: 基础行为。决策保守，容易被打断。闪避概率最高(70%)。

**Phase 2 (75%~50%)**: 免疫打断（霸体）。移速+10%，伤害微增。闪避概率降至55%，开始更激进。

**Phase 3 (50%~25%)**:
- 🔥 **跳跃后悬停**: 跳跃后进入HOVER模式，`velocity.y = 0` 悬浮空中10秒
- 🔥 **3发独立瞄准剑气**: 每次发射3道剑气，每道独立瞄准玩家当前位置（非扇形展开）
- 悬停中每1秒发射一轮剑气（进入悬停时0.2s快速首发）
- 悬停中缓慢水平跟随玩家（30%移速）
- 悬停结束 → 正常下落
- 闪避概率降至30%

**Phase 4 (25%~0%)**:
- 🔥 **近战附带剑气**: 每次MELEE开始时额外发射1道剑气
- 🔥 **移速暴增**: 350 (Phase 1的1.75倍)
- 🔥 **跳跃大幅提升**: -720 (Phase 1的1.44倍)
- 决策最激进，近战权重最高(75%)
- 闪避概率仅15%，几乎不躲避

### 2.6 决策树逻辑

每 0.3s 评估一次，攻击/闪避期间锁定（`_action_lock`）。

**最高优先级**: 玩家在上方平台（`dy < -80`）
- 可跳跃 → JUMP
- Phase 3+ 跳跃冷却 → 远程为主
- 其他阶段 → RETREAT + RANGED

**各阶段独立决策树**: Phase 1~4 各有独立的 `_run_phaseN_decision()` 函数，随阶段推进：
- 远程射程逐渐缩小（600→500→350→250）
- 近战权重逐渐增加（30%→40%→40%→75%）
- RETREAT概率逐渐减少

### 2.7 反应式覆盖

**玩家技能/冲刺** → 阶段递减闪避概率:
- Phase 1: 70% → Phase 4: 15%
- 闪避方向反向，0.3s锁定时长

**玩家受伤** → 立即 APPROACH（全阶段相同）

### 2.8 近战攻击系统

- 攻击动画: 12fps, 16帧总长, 第11帧出伤
- 命中窗口: 0.12s (MELEE_HITBOX_DURATION)
- hitbox 偏移: `Vector2(±100, 0)`（依朝向）
- hitbox 大小: `180×200`（tscn 中定义）
- Phase 4: 近战启动时额外调用 `_fire_sword_from_melee()`

### 2.9 剑气系统 (SwordEnergy)

```gdscript
SPEED = 350, MAX_LIFETIME = 8.0s
collision_mask = 4  # 仅检测 PLAYER，穿过所有地形
collision_layer = 0  # 不参与物理碰撞
```

- Phase 1-2: 单发剑气
- Phase 3-4: 3发，每道独立瞄准玩家（不是扇形展开）
- Phase 4 近战: 额外1发沿朝向的剑气
- 命中玩家 → `take_damage(dmg, kb)` + `queue_free()`
- 生命周期 8s 后自毁

### 2.10 玩家弹体追踪系统

在 bg4 Boss战场：
- `GameManager.boss_target` 由 Level_05 设置/清除
- `SwordQiProjectile` 每帧检测 `boss_target`，存在时自动追踪
- 仅 bg4 生效，不影响其他关卡

### 2.11 跳跃与悬停系统

**跳跃**: 仅地面触发，3s 冷却，不锁决策树
**Phase 3 悬停**:
- 跳跃后自动转入HOVER状态
- 持续10秒，`velocity.y = 0` 悬浮
- 缓慢水平追踪玩家
- 每1秒发射3发独立瞄准剑气
- 悬停结束或受stun正常下落

### 2.12 动画

- idle: boss待机.png, 4×3, 6fps, 循环
- walk: boss行走.png, 4×3, 10fps, 循环
- attack: boss攻击.png, 4×4, 256×256, 12fps, 不循环
- HOVER: 使用attack动画
- 朝向: `_sprite.flip_h = not is_facing_right`，30px 滞后死区防频闪

---

## 3. Level_05（第五关）

### 3.1 文件清单

| 文件 | 作用 |
|---|---|
| `LevelModule/Formal/Level_05.gd` | 关卡脚本 (725行) |
| `LevelModule/Formal/Level_05.tscn` | 关卡场景 |
| `LevelModule/Scenes/PixelworkMapStitch/Level05_Cyber/bg 3-1.png` | 赛博地图底层 |
| `LevelModule/Scenes/PixelworkMapStitch/Level05_Lingnan/bg 3-2.png` | 岭南地图上层 |
| `LevelModule/Scenes/PixelworkMapStitch/Level05_Cyber/bg 4.png` | Boss战场背景 (1376×768) |

### 3.2 核心系统

**双世界撕裂 (PixelTearing)**:
- E 键切换上下层地图
- `_corruption` 控制 shader 参数
- `player_uv` 通过 `get_global_transform_with_canvas()` 计算屏幕 UV
- 边缘撕裂强度随侵蚀值增长

**侵蚀值系统**:
- 左侧侵蚀进度条 (280×18)
- 随时间增长: 0.35/秒
- 击杀敌人降低: 15
- 满 100 → `trigger_game_over()`
- 对话期间暂停侵蚀

**继承 Level_04 数据**:
```gdscript
GameManager.dream_runtime_flags["erosion_value"]    # 侵蚀值
GameManager.dream_runtime_flags["player_health"]     # 玩家血量
GameManager.dream_runtime_flags["player_max_health"]
```

### 3.3 Boss 区域

**交互点**: `(2842, 552)`, `object_id = "enter_boss"`, 碰撞盒 60×120

**进入流程**:
1. 玩家走到交互点 → "按Enter进入深处"
2. 按 Enter → 3句对话（花旦登场白）
3. 对话结束 → 传送到 Boss 区域 `(931, 5037)`
4. 相机限制: `[718, 1655, 4509, 5135]`, zoom 1.5
5. Boss 生成在 `(1300, 5037)`
6. Boss 血条显示

**Boss 背景**: `bg 4.png` (1376×768), position `(1187, 4822)`, scale `(0.82, 0.82)`

**Boss 碰撞体**: 由 `BossCollisions` 节点管理，包含 Floor、LeftWall、RightWall 和多个平台 (BS_P1~BS_P10)

### 3.4 Boss 血条

- 位置: 屏幕顶部居中 `(440, 20)`
- 大小: 400×28
- 颜色: 紫色 → 橙色(<60%) → 红色(<30%)
- 显示: "花旦  HP / 300"
- 订阅 `ENEMY_HURT` 事件更新

### 3.5 对话系统

```gdscript
_show_dialog(["第一句", "第二句", ...], callback)
```

- RichTextLabel + BBCode 支持
- Enter 推进
- 对话期间 `InputManager.block_input("对话")` 屏蔽游戏输入
- 对话结束后调用 callback（如传送、显示血条）

**登场对话**:
```
花旦：呵……终于来了。
花旦：侵蚀已至此处，你的梦境不过是碎纸片。
花旦：来吧，让我看看你的剑——还能斩碎什么。
```

**死亡对话**:
```
花旦：……这剑，竟比侵蚀更利。
系统：梦境深处已稳定。侵蚀停止扩散。
```

### 3.6 调试面板

按 1 打开调试面板，包含两个按钮:
- **bg3 (撕裂)**: 传送到双世界区域
- **bg4 (Boss)**: 直接传送到 Boss 区域（跳过对话）

### 3.7 换皮肤系统

```gdscript
_swap_player_skin("Cyber")  # 赛博皮肤
_swap_player_skin("Lingnan") # 岭南皮肤
```

- 销毁旧玩家 → 实例化新皮肤 → 继承血量/朝向/位置
- 恢复摄像机限制
- **关键**: 换皮后 emit `HEALTH_CHANGED` 推送血量到 HUD

---

## 4. HUD 血条修复（Level_04 & Level_05）

### 4.1 问题

- Level_05 的 `_on_ready()` 没有 `_load_hud()` 调用 → 玩家血条不显示
- `_load_hud()` 后不推送初始血量 → HUD 显示空条
- `_swap_player_skin()` 后 `player_ref` 变了，HUD 仍引用旧引用

### 4.2 修复

| 位置 | 修复内容 |
|---|---|
| `Level_05._on_ready()` | 新增 `_load_hud()` 调用 |
| `Level_04._load_hud()` | 末尾 emit `HEALTH_CHANGED` 推送当前血量 |
| `Level_05._load_hud()` | 末尾 emit `HEALTH_CHANGED` 推送当前血量 |
| `Level_04._swap_player_skin()` | 换皮后 emit `HEALTH_CHANGED` |
| `Level_05._swap_player_skin()` | 换皮后 emit `HEALTH_CHANGED` |
| `Level_05._setup_player()` | 创建玩家后 emit `HEALTH_CHANGED` |

### 4.3 注意: GDScript 变量作用域

`var p` 在 `if` 块内声明则只在该块内可见。修复时将 `EventBus.emit` 移到 if 块内部。

---

## 5. 敌人类型

| 敌人 | 场景文件 | 说明 |
|---|---|---|
| Enemy_CyberWolf | `EnemyModule/Formal/Enemy_CyberWolf.tscn` | 赛博狼人 |
| Enemy_LanternGhost | `EnemyModule/Formal/Enemy_LanternGhost.tscn` | 灯笼鬼（漂浮） |
| Enemy_PaperEffigy | `EnemyModule/Formal/Enemy_PaperEffigy.tscn` | 纸符人 |
| Enemy_CyberBull | `EnemyModule/Formal/Enemy_CyberBull.tscn` | 冲撞兽 |
| Enemy_BossHuadan | `EnemyModule/Formal/Enemy_BossHuadan.tscn` | 花旦 Boss |

---

## 6. 已知注意事项

1. **剑气 collision_mask=4**: 只检测玩家，穿过所有地形。之前的 `collision_mask=5`（含TERRAIN）会被平台挡掉。
2. **Boss 跳跃防卡死**: 3s 冷却 + 不锁决策树 + 落地清除标记。受击时不卡。
3. **换皮肤后必须 emit HEALTH_CHANGED**: 否则 HUD 仍指向旧引用，血条不更新。
4. **对话期间暂停侵蚀**: `_process` 中 `if not _dialog_open` 控制。
5. **Boss 背景图**: bg 4.png (1376×768)，position 为 Boss 相机区域中心，scale 0.82 全覆盖。
6. **Boss 不造成接触伤害**: `deals_contact_damage()` 返回 `false`，所有伤害由剑气和近战 hitbox 负责。
7. **TSCN 中 BossEntry 使用 InteractiveObject 脚本**: `ExtResource("5_interact")`，不是直接使用通用脚本。
