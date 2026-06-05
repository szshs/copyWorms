# HackathonGame 技术架构报告

> **目标读者**：下游 AI 关卡设计助手
> **生成时间**：2026-06-05
> **引擎版本**：Godot 4.6 (GL Compatibility, GDScript)
> **项目版本**：v0.1.0

---

## 1. 项目元信息

| 属性 | 值 |
|---|---|
| 项目名称 | HackathonGame |
| 类型 | 2D 横版动作游戏（类空洞骑士） |
| 分辨率 | 1280×720，canvas_items 拉伸 |
| 主场景 | `res://UI/TitleScreen.tscn` |
| 3 个 Autoload | `GlobalDefine`, `EventBus`, `GameManager` |
| 运行模式 | `FORMAL`（正式）/ `SELF_TEST`（自测）双模式 |

---

## 2. 核心架构与系统模块划分

### 2.1 分层架构

```
┌────────────────────────────────────────────────────┐
│ UI 层                                              │
│   TitleScreen.gd   HUD.gd                         │
│   (CanvasLayer，纯代码构建 UI，无 .theme)           │
├────────────────────────────────────────────────────┤
│ 游戏逻辑层                                          │
│   LevelBase → Level_01      (关卡)                │
│   PlayerBase → Player_Warrior (玩家)               │
│   EnemyBase → Enemy_Slime   (敌人)                │
│   DamageCalculator          (伤害工具)             │
├────────────────────────────────────────────────────┤
│ 数据配置层（仅 Resource，非节点）                     │
│   PlayerConfig.gd → WarriorConfig.tres            │
│   EnemyConfig.gd  → SlimeConfig.tres              │
│   SkillConfig.gd  → SlashConfig.tres              │
│   LevelConfig.gd  → Level01Config.tres            │
├────────────────────────────────────────────────────┤
│ 基础设施层（Autoload）                               │
│   GlobalDefine  (枚举+事件名常量，不可修改)           │
│   EventBus      (跨模块唯一通信通道)                 │
│   GameManager   (全局引用/状态管理)                  │
└────────────────────────────────────────────────────┘
```

### 2.2 模块间通信规则（绝对约束）

**所有模块间通信必须通过 `EventBus`，严禁跨模块直接引用节点。**

- 关卡不直接持有玩家/敌人引用 → 通过 `GameManager.player_ref` / `GameManager.get_enemies()`
- 敌人不直接持有玩家引用 → 通过 `GameManager.player_ref`
- UI 不直接查询任何游戏对象 → 全由事件驱动

---

## 3. 全局系统接口

### 3.1 GlobalDefine — 枚举与常量（不可修改）

```gdscript
# === 运行模式 ===
enum RunMode { FORMAL, SELF_TEST }

# === 玩家状态 ===
enum PlayerState {
    IDLE, RUN, JUMP, FALL, DASH, ATTACK, SKILL, HURT, DEAD
}

# === 敌人状态 ===
enum EnemyState {
    IDLE, PATROL, CHASE, ATTACK, HURT, DEAD
}

# === 伤害类型 ===
enum DamageType { PHYSICAL, MAGIC, TRUE_DAMAGE }

# === 事件名称 ===
class EventName:
    # 玩家事件
    PLAYER_SPAWNED         = "player_spawned"
    PLAYER_DIED            = "player_died"
    PLAYER_HURT            = "player_hurt"
    PLAYER_ATTACK_HIT      = "player_attack_hit"
    PLAYER_STATE_CHANGED   = "player_state_changed"

    # 敌人事件
    ENEMY_SPAWNED          = "enemy_spawned"
    ENEMY_DIED             = "enemy_died"
    ENEMY_HURT             = "enemy_hurt"
    ENEMY_DETECTED         = "enemy_detected"

    # 游戏事件
    GAME_START             = "game_start"
    GAME_PAUSE             = "game_pause"
    GAME_RESUME            = "game_resume"
    GAME_OVER              = "game_over"
    LEVEL_LOADED           = "level_loaded"
    LEVEL_COMPLETE         = "level_complete"

    # 伤害事件
    DAMAGE_APPLIED         = "damage_applied"
    HEALTH_CHANGED         = "health_changed"
```

### 3.2 EventBus API（Autoload，全局可调）

```gdscript
# 注册监听（关卡场景在 _ready 中注册自己即可）
EventBus.subscribe(event_name: String, node: Node, method: String)

# 注销监听（场景退出时调用）
EventBus.unsubscribe(event_name: String, node: Node)

# 发射事件（立即执行所有监听者回调）
EventBus.emit(event_name: String, data: Dictionary)

# 延迟发射（下一帧批处理，适合帧内多次触发的场景）
EventBus.emit_deferred(event_name: String, data: Dictionary)
```

**关卡设计用到的关键事件及其 data 字典结构：**

| 事件名称 | 触发时机 | data 字典 |
|---|---|---|
| `GAME_START` | 游戏正式启动 | `{}` |
| `LEVEL_LOADED` | 关卡 `_ready()` 末尾自动发射 | `{"level": self}` |
| `LEVEL_COMPLETE` | **目前无人发射（预留）** | 待定义 |
| `GAME_OVER` | 玩家死亡触发 | `{}` |
| `ENEMY_DIED` | 敌人 `die()` 末尾 | `{"enemy": Node2D, "exp_reward": int}` |
| `ENEMY_SPAWNED` | `GameManager.register_enemy()` | `{"enemy": Node2D}` |
| `PLAYER_DIED` | 玩家死亡 | `{"player": Node2D}` |
| `HEALTH_CHANGED` | 玩家/敌人受伤/回血 | `{"target": Node, "current_health": int, "max_health": int}` |

### 3.3 GameManager API（Autoload，全局可调）

```gdscript
# ===== 全局引用（只读使用） =====
var player_ref: Node2D         # 当前玩家节点
var current_level: Node        # 当前关卡节点
var enemy_list: Array[Node2D]  # 所有存活敌人

# ===== 游戏状态 =====
var is_paused: bool            # 暂停状态
var is_game_over: bool         # 游戏结束标志
var run_mode: int              # FORMAL(0) 或 SELF_TEST(1)

# ===== 敌人管理 =====
register_player(player: Node2D)         # 关卡生成玩家后调用
register_enemy(enemy: Node2D)           # 敌人 _ready 自动调用，无需手动
unregister_enemy(enemy: Node2D)        # 敌人死亡自动调用
get_enemies() -> Array[Node2D]         # 获取存活敌人（自动过滤无效引用）
get_nearest_enemy(pos: Vector2) -> Node2D  # 获取离某点最近的敌人

# ===== 游戏控制 =====
trigger_game_over()                     # 触发 GAME_OVER 流程
toggle_pause()                          # 切换暂停
is_self_test() -> bool
is_formal() -> bool
```

---

## 4. 关卡系统接口规范

### 4.1 关卡基类 LevelBase（`res://LevelModule/Formal/LevelBase.gd`）

**继承链**：`Node2D`

**导出字段（编辑器中可见，代码内可赋值）**：
```gdscript
@export var level_config: LevelConfig           # 关卡配置 .tres
@export var enemy_spawn_points: Array[Marker2D]  # 编辑器放置的标记点
@export var player_spawn_point: Marker2D         # 编辑器放置的玩家出生标记
```

**生命周期（严格顺序）**：
```
_ready()
├── _apply_config()          # 设置背景色
├── _setup_camera()          # 创建/关联摄像机，应用 limit 边界
├── _setup_player()          # 自动从 .tscn 加载玩家（如未注册）
├── _setup_enemies()         # 遍历 enemy_spawn_points，逐个调 _spawn_enemy_at()
├── _setup_triggers()        # 虚函数，子类重写
├── GameManager.current_level = self
├── EventBus.emit(LEVEL_LOADED, {"level": self})
└── _on_ready()              # 虚函数：子类在此实现关卡内容
```

**子类必须重写的虚函数**：
```gdscript
_on_ready()                         # 关卡内容入口（建筑地形、生成敌人、设置触发器等）
_spawn_enemy_at(spawn_point: Marker2D) -> Node2D  # 【重要】按标记点类型生成不同敌人
_setup_triggers()                   # 关卡触发器逻辑
```

**子类可调用的公共方法**：
```gdscript
# 创建矩形地面平台（StaticBody2D + CollisionShape2D + ColorRect）
create_ground(pos: Vector2, size: Vector2, color: Color) -> StaticBody2D
# 内部自动设置 collision_layer = 1

# 创建墙壁（等同于 create_ground）
create_wall(pos: Vector2, size: Vector2, color: Color) -> StaticBody2D

# 在指定坐标生成敌人
spawn_enemy(enemy_scene_path: String, position: Vector2) -> Node2D
```

### 4.2 关卡配置资源 LevelConfig（`res://DataConfig/Level/LevelConfig.gd`）

```gdscript
class_name LevelConfig extends Resource

# 关卡信息
@export var level_name: String = "未命名关卡"
@export var level_id: String = ""
@export var bgm_resource: AudioStream = null       # BGM（当前全部为 null）
@export var bg_color: Color = Color(0.1, 0.1, 0.2) # 通过 RenderingServer 设置背景色

# 摄像机边界限制
@export var camera_limit_left: int = -10000
@export var camera_limit_right: int = 10000
@export var camera_limit_top: int = -10000
@export var camera_limit_bottom: int = 10000

# 重生点
@export var spawn_point: Vector2 = Vector2(100, 500)
```

### 4.3 现有关卡模板：Level_01

**路径**：`res://LevelModule/Formal/Level_01.tscn` + `Level_01.gd`

```gdscript
# _on_ready 模式：
_on_ready():
    super._on_ready()
    # 1. 加载配置
    if not level_config:
        level_config = load("res://DataConfig/Level/Level01Config.tres")
        _apply_config()
    # 2. 搭建地形
    _build_terrain()
    # 3. 生成敌人
    _spawn_level_enemies()
```

**新建关卡请严格遵循此模式。**

---

## 5. 玩家系统（关卡需了解的接口）

### 5.1 玩家节点类型

`CharacterBody2D` (PlayerBase) → `Player_Warrior`

**场景路径**：`res://PlayerModule/Formal/Player_Warrior.tscn`

### 5.2 玩家碰撞层

| 层 | 用途 |
|---|---|
| `collision_layer = 4` | 玩家自身所在的碰撞层 |
| `collision_mask = 1` | 只检测第 1 层（地形层） |

**关键含义**：玩家不会与敌人发生物理碰撞（敌人 `collision_layer = 2`）。玩家对敌人的接触伤害通过代码级 Rect2 检测实现（`_check_enemy_contact()` 每帧遍历）。

### 5.3 玩家核心数值（默认 WarriorConfig.tres）

| 参数 | 值 | 说明 |
|---|---|---|
| `max_health` | 100 | 最大生命值 |
| `move_speed` | 300.0 | 水平移动速度 |
| `jump_velocity` | -650.0 | 起跳初速度（负=向上） |
| `jump_hold_gravity_scale` | 0.35 | 长按跳跃时的重力缩放（越小跳越高） |
| `jump_release_gravity_scale` | 2.5 | 松手后的重力缩放（快速落下） |
| `gravity` | 1200.0 | 基础重力 |
| `attack_damage` | 25 | 普攻伤害 |
| `attack_cooldown` | 0.4s | 普攻冷却 |
| `attack_range` | 80.0 | 普攻半径（圆心=玩家向前面 40px + 上方 -10px） |
| `dash_speed` | 800.0 | 冲刺速度 |
| `dash_duration` | 0.2s | 冲刺持续时间（期间无敌） |
| `dash_cooldown` | 0.8s | 冲刺冷却 |
| `hurt_invincible_time` | 1.0s | 受伤后无敌帧时长 |
| `can_double_jump` | true | 战士默认开启二段跳 |

### 5.4 玩家可执行的动作

| 动作 | 触发方式 | 对关卡的影响 |
|---|---|---|
| 移动 | 方向键/摇杆 | 水平速度受 `_handle_state` 控制 |
| 跳跃 | 空格 (player_jump) | 二段跳可用时空中再按一次触发 |
| 普攻 | 鼠标左键/J | 圆形范围 80px，对范围内最近敌人造成 (25×暴击) 伤害 |
| 冲刺 | Shift/K | 水平高速移动 + 短暂无敌 |
| 技能横斩 | I | 范围 100px，伤害 35，CD 2s |

---

## 6. 敌人系统（关卡需了解的接口）

### 6.1 现有敌人类型：Enemy_Slime

**场景路径**：`res://EnemyModule/Formal/Enemy_Slime.tscn`

**配置**：`res://DataConfig/Enemy/SlimeConfig.tres`

| 参数 | 史莱姆值 | 说明 |
|---|---|---|
| `max_health` | 30 | 血量（战士一刀暴击 37.5 可能秒杀） |
| `move_speed` | 80.0 | 巡逻/基础移速 |
| `chase_speed_multiplier` | 1.5 | 追逐速度 = 80×1.5 = 120 |
| `attack_damage` | 8 | 造成伤害 |
| `attack_cooldown` | 1.5s | 攻击后冷却 |
| `attack_range` | 35.0 | 近战攻击距离 |
| `detect_range` | 250.0 | 发现玩家的检测半径 |
| `wander_radius` | 80.0 | 巡逻活动半径（以出生点为基准 ±80px） |
| `patrol_wait_time` | 2.5s | 巡逻间隔等待 |
| `knockback_resistance` | 0.1 | 击退抗性（1.0=完全免疫） |
| `drop_health_chance` | 0.15 | 死亡后掉落生命概率（**当前未实现掉落**） |
| `exp_reward` | 5 | 死亡经验（**当前未实现经验系统**） |

**史莱姆特有行为**：
- 每 2~4 秒随机起跳（`jump_velocity = -300`）
- 追逐时向玩家方向跳跃（水平速度 150）
- 巡逻时沿巡逻方向跳跃（水平速度 100）

### 6.2 敌人碰撞层

| 层 | 值 |
|---|---|
| `collision_layer = 2` | 敌人所在层 |
| `collision_mask = 1` | 只与地形层碰撞 |

### 6.3 敌人基类 EnemyBase 公共接口

```gdscript
# 敌人收到伤害（玩家攻击/技能调用此方法）
take_damage(damage: int, knockback_dir: Vector2 = Vector2.ZERO)

# 可查询的属性
var current_health: int
var max_health: int
var current_state: int  # 对应 EnemyState 枚举
var config: EnemyConfig
```

### 6.4 创建新敌人类型的方式

```
1. 创建 EnemyConfig 子类的 .tres 实例，填入具体数值
2. 新建脚本 extends EnemyBase
3. 重写虚函数：
   - _on_ready()       → 初始化特有行为
   - _on_physics_process(delta) → 追加 AI 逻辑
   - _on_attack()      → 攻击玩家逻辑
   - _get_placeholder_color()/size() → 占位视觉
4. 创建 .tscn 场景（CharacterBody2D 根节点，挂载脚本）
```

---

## 7. 伤害系统

### 7.1 DamageCalculator（静态工具类）

```gdscript
# 计算最终伤害
static func calculate(
    attacker_atk: int,          # 攻击力
    target_def: int = 0,        # 防御力（当前全部传 0！）
    damage_type: int = PHYSICAL, # DamageType 枚举值
    crit_rate: float = 0.05,    # 暴击率（0.0~1.0）
    crit_mult: float = 1.5      # 暴击倍率
) -> Dictionary  # {"damage": int, "is_crit": bool}

# 计算击退方向
static func get_knockback_direction(attacker_pos: Vector2, target_pos: Vector2) -> Vector2
```

**伤害公式（PHYSICAL）**：`max(attack - def×0.5, attack×0.3)` × 暴击倍率

### 7.2 伤害流程（玩家攻击敌人）

```
玩家按攻击键
→ PlayerBase.perform_attack()
  → is_attacking = true, attack_timer = 0.25s
  → _on_attack() (虚函数，子类实现)
    → Player_Warrior._on_attack()
      → 遍历 GameManager.get_enemies()
      → 距离判定：attack_center.distance_to(enemy.global_position) <= 80
      → DamageCalculator.calculate(25, 0, PHYSICAL)
      → enemy.take_damage(result["damage"], kb_dir)
      → EventBus.emit(PLAYER_ATTACK_HIT, {...})
      → break（只命中第一个！）
```

### 7.3 敌人对玩家伤害（两条路径）

**路径 A**：接触伤害（`PlayerBase._check_enemy_contact()`，每帧 Rect2 碰撞检测）
- 离开无敌帧且未死亡时触发
- 伤害 = `enemy.config.attack_damage`（史莱姆=8）
- 击退水平 300、垂直 -200
- 无敌帧设为 1.5 秒

**路径 B**：敌人主动攻击（`EnemyBase._perform_attack()` → `Enemy_Slime._on_attack()`）
- 离开无敌帧时触发
- 通过 `target.take_damage(result["damage"], kb_dir)` 调用玩家的 `take_damage` 方法
- 玩家的 `take_damage` 被调用时：无敌帧 = `hurt_invincible_time` (1.0s)，击退力 = `hurt_knockback` (300)

---

## 8. 碰撞层系统

**这是关卡地形设计的核心约束。**

| 层号 | 用途 | 节点 |
|---|---|---|
| **1** | 地形层 | `StaticBody2D`（地面、平台、墙壁） |
| **2** | 敌人层 | `EnemyBase` 及其子类 |
| **4** | 玩家层 | `PlayerBase` 及其子类 |

**碰撞掩码规则**：
- 玩家 (`mask=1`)：只与地形碰撞，不与敌人碰撞
- 敌人 (`mask=1`)：只与地形碰撞，不与玩家碰撞
- 地形 (`layer=1`)：被动接受其他层的碰撞

**含义**：
- 玩家和敌人之间**不会**因物理引擎发生碰撞
- 玩家对敌人的接触伤害通过 `PlayerBase._check_enemy_contact()` 的 Rect2 代码级检测实现
- 所有 `StaticBody2D` 地形必须设置 `collision_layer = 1`（`create_ground()` 已自动设置）

---

## 9. 坐标系统与物理单位

| 参数 | 值 |
|---|---|
| 屏幕逻辑分辨率 | 1280×720 |
| 原点 | 左上角 (0,0) |
| Y 轴方向 | **向下为正**（Godot 2D 默认） |
| 重力 | 1200 px/s² 向下 |
| 摄像机锚点 | DRAG_CENTER（跟随玩家中心） |
| 地面 Y | 通常 620（屏幕底部上方 100px） |
| 玩家出生 Y | 通常 550~500（在地面 Y 上方留余量） |
| 跳跃速度 | -650 px/s（负=向上） |

**关卡设计时注意**：
- `create_ground(pos, size)` 的 `pos` 是**平台中心**坐标
- 地面 Y 推荐 620，厚度推荐 80（保证不穿透）
- 平台 Y 推荐 460/420/340/200（阶梯式）
- 墙壁 X 推荐 0（左墙）和 1280（右墙），厚度 20

---

## 10. 资源加载机制

### 10.1 已存在的可引用资源路径

```
玩家:     res://PlayerModule/Formal/Player_Warrior.tscn
敌人:     res://EnemyModule/Formal/Enemy_Slime.tscn
关卡01:   res://LevelModule/Formal/Level_01.tscn
HUD:      res://UI/HUD.tscn
主菜单:   res://UI/TitleScreen.tscn

玩家配置: res://DataConfig/Player/WarriorConfig.tres
敌人配置: res://DataConfig/Enemy/SlimeConfig.tres
技能配置: res://DataConfig/Skill/SlashConfig.tres
关卡配置: res://DataConfig/Level/Level01Config.tres
```

### 10.2 背景图片资源

```
res://LevelModule/Background images/
├── Generated Image June 04, 2026 - 9_38PM.jpg
├── Generated Image June 04, 2026 - 9_41PM.jpg
├── Generated Image June 04, 2026 - 9_43PM.jpg
└── Generated Image June 04, 2026 - 9_55PM.jpg
```

**这些图片已导入但未在任何代码或场景中引用**。如需关卡背景，可以通过以下代码加载：

```gdscript
var bg_texture = load("res://LevelModule/Background images/Generated Image June 04, 2026 - 9_41PM.jpg")
var bg = TextureRect.new()
bg.texture = bg_texture
bg.set_anchors_preset(Control.PRESET_FULL_RECT)
add_child(bg)
# 注意：关卡是 Node2D，TextureRect 需要作为 CanvasLayer 的子节点
```

### 10.3 玩家精灵资产

```
res://Assets/Sprites/player Ani/
├── 人物行走.png     (已在 Player_Warrior.tscn 中引用，切为 64×64 ×16 帧 "walk" 动画)
├── 人物待机.png     (未引用)
├── 人物跳跃.png     (未引用)
├── 人物冲刺.png     (未引用)
└── 另外 2 张        (未引用)
```

---

## 11. 功能边界与尚未实现的系统

### 11.1 可立即使用的系统

- ✅ 9 态玩家状态机（含二段跳、长按变高跳）
- ✅ 冲刺（0.2s，无敌帧覆盖）
- ✅ 普攻 + 技能横斩
- ✅ 6 态敌人 AI（巡逻/追逐/攻击/受伤/死亡）
- ✅ EventBus 事件驱动通信
- ✅ 暂停/恢复/游戏结束面板
- ✅ HUD 血条显示（百分比宽度缩放）
- ✅ 代码级 StaticBody2D 平台搭建
- ✅ 摄像机跟随 + limit 边界限制
- ✅ 双层运行模式（正式/自测）

### 11.2 已定义但未实现的功能（关卡可用事件驱动激活）

| 功能 | 现有基础 | 缺失 |
|---|---|---|
| **关卡完成逻辑** | `EventName.LEVEL_COMPLETE` 已定义 | 无人发射 |
| **关卡触发器/门/传送** | `LevelBase._setup_triggers()` 虚函数已定义 | 无具体实现 |
| **多关卡切换** | `EventBus` 和 `MainEntry` 支持 load/scene | 无第二关，无切换逻辑 |
| **重生点** | `LevelConfig.spawn_point` 已定义 | 死亡后直接 Game Over，未重生 |
| **敌人标记点系统** | `enemy_spawn_points: Array[Marker2D]` 已定义 | `_spawn_enemy_at()` 返回 null，Level_01 实际用独立方法 |
| **防御系统** | `DamageCalculator.calculate(target_def)` | 所有调用 `target_def = 0` |
| **Mana/能量** | `SkillConfig.mana_cost = 15` | 玩家无能量条，技能不扣费 |
| **经验/升级** | `EnemyConfig.exp_reward` | 无经验系统 |
| **掉落系统** | `EnemyConfig.drop_health_chance` | 无掉落 |
| **回血** | `PlayerBase.heal(amount)` 方法存在 | 无人调用 |
| **BGM/音效** | `LevelConfig.bgm_resource` 字段存在 | 全部 null，无音频文件 |
| **伤害数字飘屏** | 无 | 无 |

### 11.3 已知技术限制

| 限制 | 说明 |
|---|---|
| **敌人数量上限** | 无硬上限，但 `PlayerBase._check_enemy_contact()` 每帧 O(n) 遍历 + Rect2 判断，预估值：50+ 敌人时可能降至 < 60fps |
| **平台斜率** | `create_ground()` 仅支持矩形，不支持斜面或曲线地形 |
| **关卡宽度** | camera_limit 默认 ±2000，可扩展到 ±10000，但地形必须在 1280×720 可视范围内用代码构建 |
| **碰撞形状** | 仅矩形，无圆形或多边形碰撞体 |
| **多玩家** | 不支持，GameManager 只持有单个 `player_ref` |
| **存档** | 无任何持久化机制 |

---

## 12. 关卡开发标准流程

### 12.1 新建正式关卡的步骤

```
1. 在 DataConfig/Level/ 创建 Level02Config.tres
   - level_name = "第二关名称"
   - level_id = "level_02"
   - 设置 camera_limit 边界
   - 设置 spawn_point

2. 在 LevelModule/Formal/ 创建 Level_02.gd
   class_name Level_02
   extends LevelBase

   func _on_ready():
       super._on_ready()
       if not level_config:
           level_config = load("res://DataConfig/Level/Level02Config.tres")
           _apply_config()
       _build_terrain()
       _spawn_level_enemies()
       # _setup_triggers() ...（未来实现）

3. 在 LevelModule/Formal/ 创建 Level_02.tscn
   [gd_scene load_steps=2 format=3]
   [ext_resource type="Script" path=".../Level_02.gd" id="1_main"]
   [node name="Level_02" type="Node2D"]
   script = ExtResource("1_main")

4. 在 LevelModule/SelfTest/ 创建 LevelTest_02.gd + .tscn
   参考 LevelTest.gd 结构：地形+玩家+敌人+HUD

5. 如需从 Level_01 过渡到 Level_02：
   监听 ENEMY_DIED 事件，所有敌人死亡后发射 LEVEL_COMPLETE，
   然后 change_scene_to_file("res://LevelModule/Formal/Level_02.tscn")
```

### 12.2 地形设计参数速查

```
主地面:  create_ground(Vector2(640, 620), Vector2(1280, 80))
左墙:    create_wall(Vector2(0, 360), Vector2(20, 720))
右墙:    create_wall(Vector2(1280, 360), Vector2(20, 720))
平台:    create_ground(Vector2(X, Y), Vector2(宽度, 16~20))

平台 Y 推荐阶梯：
  VERY_LOW:  500  (略高于地面)
  LOW:       460
  MID:       420
  HIGH:      340
  VERY_HIGH: 200

玩家跳跃可达高度（以 WarriorConfig 计算）：
  一段跳 max ≈ asb(-650²)/(2×1200×0.35) + 64 ≈ 510 px（高于平台中心）
  站立跳跃起点 y=550 可到达 y≈40 的高度
```

### 12.3 敌人放置策略

```gdscript
# 方法 1：直接 spawn（推荐）
spawn_enemy("res://EnemyModule/Formal/Enemy_Slime.tscn", Vector2(300, 588))
# 注意：Y=588 让 36px 高的敌人脚踩在 Y=620 的地面中心（620 - 80/2 + 36/2 ≈ 588）

# 方法 2：用 Marker2D 标记点（需要先重写 _spawn_enemy_at()）
@export var enemy_spawn_points: Array[Marker2D]
# 在编辑器中放置 Marker2D，每个标记点可附加元数据
```

**史莱姆推荐放置位置**：
- 地面敌人 Y = 588（适配 80px 厚地面）
- 平台敌人 Y = platform_Y - (platform_thickness/2) + (enemy_height/2)
  - 例：平台 Y=460, thickness=20, enemy=36 → Y = 460 - 10 + 18 = 468

---

## 13. 附录：文件路径速查

```
项目根目录
├── project.godot                           # 引擎配置
├── Global/                                  # Autoload（3个已注册单例）
│   ├── GlobalDefine.gd
│   ├── EventBus.gd
│   ├── GameManager.gd
│   ├── MainEntry.gd / .tscn
├── Tools/
│   └── DamageCalculator.gd                  # 静态伤害工具
├── UI/
│   ├── TitleScreen.gd / .tscn               # 主菜单（纯代码 UI）
│   └── HUD.gd / .tscn                       # HUD（CanvasLayer）
├── DataConfig/
│   ├── Player/ PlayerConfig.gd + WarriorConfig.tres
│   ├── Enemy/  EnemyConfig.gd + SlimeConfig.tres
│   ├── Skill/  SkillConfig.gd + SlashConfig.tres
│   └── Level/  LevelConfig.gd + Level01Config.tres
├── PlayerModule/
│   ├── Formal/ PlayerBase.gd + Player_Warrior.gd/.tscn
│   └── SelfTest/ PlayerTest.gd/.tscn
├── EnemyModule/
│   ├── Formal/ EnemyBase.gd + Enemy_Slime.gd/.tscn
│   └── SelfTest/ EnemyTest.gd/.tscn
├── LevelModule/
│   ├── Formal/ LevelBase.gd + Level_01.gd/.tscn
│   ├── SelfTest/ LevelTest.gd/.tscn
│   └── Background images/ (4 张 JPG + .import)
└── Assets/Sprites/player Ani/ (6 张 PNG)
```

---

**此报告覆盖所有关卡设计所需的技术边界、接口规范和约束条件。设计关卡时请严格遵循上述 API 和碰撞层规则，通过 EventBus 进行跨模块通信。**
