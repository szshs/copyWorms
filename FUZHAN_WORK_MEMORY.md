# 复战流程工作记忆

本文件记录当前 `level_fuzhan_01` / `level_fuzhan_02` 相关实现，作为后续新增关卡与替换流程时的工作留档。具体对白以脚本和根目录需求文档为准，不要根据本文件重新创作文案。

## 相关文件

- `LevelModule/Formal/Level_fuzhan_sub01.gd`
  - 复战流程状态、文本、目标区域选择、返回现实原因、配置解锁判断。
- `LevelModule/Formal/Level_fuzhan_memory_base.gd`
  - 两个复战场景共享的玩家创建、摄像机、HUD、敌人生成、掉落物生成、互动文本、死亡返回现实逻辑。
- `LevelModule/Formal/Level_fuzhan_01.gd`
  - 复战区域 01 的参数配置。
- `LevelModule/Formal/Level_fuzhan_02.gd`
  - 复战区域 02 的参数配置。
- `LevelModule/Formal/Level_fuzhan_01.tscn`
  - 区域 01 场景。地图实例保留，旧交互物、旧退出等内容已清理。
- `LevelModule/Formal/Level_fuzhan_02.tscn`
  - 区域 02 场景。地图实例保留，旧交互物、旧退出等内容已清理。
- `LevelModule/Formal/Level_02_03.gd`
  - Level0203 伪 IDE 与现实房间流程入口，处理 `/memory`、`/config`、复战返回现实、LingnanDropArchiveScreen 调用。
- `Tools/DropItem.gd`
  - 掉落物节点。拾取后调用掉落物图鉴授予逻辑和放大展示。
- `UI/LingnanDropArchiveScreen.gd`
  - 岭南梦物志图鉴界面，含掉落物拥有状态检测与展示逻辑。

## 流程概览

当前流程目标是替换原本 Level0203 直接进入配置编辑器的逻辑：

1. 玩家在 Level0203 伪 IDE 阶段输入 `/memory`。
2. 如果复战未完成，进入当前目标复战区域：
   - 第一次进入 `level_fuzhan_01`。
   - 区域 01 完成后，下一次进入 `level_fuzhan_02`。
3. 每个复战区域需要回收 3 个童年回忆样本。
4. 两个区域合计回收 6 个样本后，`/config` 才开放。
5. 复战死亡不会清理当前已收集进度，只返回现实房间并提示重新进入当前未完成区域。
6. 复战完成或失败都会返回 `Level_02_03.tscn`，由 Level0203 根据返回原因显示现实房间文本和伪 IDE 提示。

## 状态键

状态保存在 `GameManager.dream_runtime_flags` 中，由 `LevelFuzhanSub01` 统一读写。

- `memory_recovery_started`
- `level0203_resume_reality`
- `memory_return_reason`
- `memory_current_area`
- `fuzhan_01_collected`
- `fuzhan_02_collected`
- `fuzhan_01_complete`
- `fuzhan_02_complete`
- `memory_fragments`
- `core_memory_anchor_stabilized`

关键规则：

- `REQUIRED_PER_AREA = 3`
- `REQUIRED_TOTAL = 6`
- `KILLS_PER_DROP = 10`
- `DROP_TYPES = ["月饼", "虾饺", "木棉", "醒狮", "烧卖", "蒲葵扇"]`

## Level0203 接入点

`Level_02_03.gd` 当前承担这些复战相关职责：

- 检测复战返回：`LevelFuzhanSub01.should_resume_reality()`。
- 消费返回原因：`LevelFuzhanSub01.consume_return_reason()`。
- 返回现实房间后显示对应独白：`LevelFuzhanSub01.reality_return_text(reason)`。
- 伪 IDE 命令：
  - `/memory`：进入当前复战目标区域。
  - `/config`：只有 `LevelFuzhanSub01.can_open_config()` 为真时开放，否则提示先完成记忆回收。
- 伪 IDE 左侧 `FILES` 下新增了可打开 `LingnanDropArchiveScreen` 的按钮。

## 复战区域 01 参数

文件：`LevelModule/Formal/Level_fuzhan_01.gd`

- 场景路径：`res://LevelModule/Formal/Level_fuzhan_01.tscn`
- `area_index = 1`
- 玩家出生点：`Vector2(2264, 544)`
- 摄像机设置复用 Level02 风格：
  - `limit_left = 0`
  - `limit_right = 5328`
  - `limit_top = -500`
  - `limit_bottom = 640`
  - `zoom = Vector2.ONE`
  - `lerp_speed = 2.5`
- 敌人生成：
  - `enemy_spawn_y = 540.0`
  - `enemy_spawn_x_range = Vector2(260.0, 5100.0)`
  - `max_alive_enemies = 4`
  - `enemy_spawn_interval = 3.0`
- 掉落物生成：
  - `drop_spawn_y = 560.0`
  - `drop_spawn_x_range = Vector2(200.0, 5200.0)`
  - 最近修复：掉落物现在先计算并夹紧目标全局坐标，加入 `DynamicActors` 后再写入 `global_position`，避免入树顺序或父节点变换造成坐标异常。

## 复战区域 02 参数

文件：`LevelModule/Formal/Level_fuzhan_02.gd`

- 场景路径：`res://LevelModule/Formal/Level_fuzhan_02.tscn`
- `area_index = 2`
- 玩家出生点：`Vector2(1816, 512)`
- 摄像机设置复用 Level0201 风格：
  - `limit_left = 0`
  - `limit_right = 4474`
  - `limit_top = 0`
  - `limit_bottom = 616`
  - `zoom = Vector2(1.5, 1.5)`
  - `lerp_speed = 2.5`
- 敌人生成：
  - `enemy_spawn_y = 540.0`
  - `enemy_spawn_x_range = Vector2(220.0, 4300.0)`
  - `max_alive_enemies = 4`
  - `enemy_spawn_interval = 3.0`
- 掉落物生成：
  - `drop_spawn_y_range = Vector2(360.0, 536.0)`
  - `drop_spawn_x_range = Vector2(1880.0, 4336.0)`

## 敌人与掉落机制

复战区域使用共享基类 `LevelFuzhanMemoryBase`。

- 敌人类型：
  - `Enemy_LanternGhost.tscn`
  - `Enemy_PaperEffigy.tscn`
- 敌人配置：
  - `DataConfig/Enemy/LanternGhostConfig.tres`
  - `DataConfig/Enemy/PaperEffigyConfig.tres`
- 击杀计数达到 `KILLS_PER_DROP` 后生成一个童年回忆样本。
- 同一时间只允许存在一个未回收样本。
- 掉落物生成后，会启动类似 Level01 手机信息屏幕边缘闪烁黄条的提示效果。
- 掉落物拾取后：
  - 调用 `DropItem.on_collected(callback)`。
  - 由 `DropItem` 授予图鉴拥有状态并触发放大展示。
  - 回调进入 `LevelFuzhanSub01.add_fragment(area_index)` 更新当前区域进度。

## 冻结与死亡处理

为避免互动期间被敌人攻击，复战基类当前有敌人冻结逻辑：

- 进入场景的初始互动文本显示期间冻结敌人。
- 掉落物拾取动画播放期间冻结敌人。
- 死亡返回现实前冻结敌人。

死亡规则：

- 不调用原本死亡后的重新开始界面。
- 不清理当前复战进度。
- 将玩家血量守卫到 1，并进入复战失败返回现实流程。
- 返回 Level0203 后，通过 `memory_return_reason` 显示对应提示。

## UI 与文本框

- 复战区域使用 Lingnan UI 主题：`GameUIStyle.set_ui_theme(GameUIStyle.UI_THEME_LINGNAN)`。
- 互动文本使用当前全局 UI 适配逻辑。
- 复战初始文本、掉落物出现文本、完成文本、失败文本都在 `LevelFuzhanSub01` 中维护。
- 文案来源要求：优先参考根目录需求文档和当前脚本常量，不要自行改写。

## 已知注意点

- `Level_02_03.tscn` 的 `level_data` 不是常规 `DataConfig/Level/Level02Data.tres`，而是绑定到 `LevelModule/Backup/Level_02_CliffReality/snapshots/Level02Data.tres`。修改 Level0203 文本时必须确认实际绑定文件。
- `Tools/DropSystem.gd` 是旧掉落物管理工具，目前复战场景没有使用它。
- `level_fuzhan_01` 掉落物如果再次出现小于 0 的情况，优先看运行日志中的：
  - `生成童年回忆掉落物`
  - `global=...`
  - `x_range=...`
  - `y_range=...`
- 当前 `Level_fuzhan_memory_base.gd` 是两个复战场景共享基类，修改掉落/敌人/死亡/文本框逻辑时会同时影响区域 01 和区域 02。

