# Level_02 悬崖 / 现实线机制备份

> **备份日期**：2026-06-16  
> **来源版本**：Level_02 完整四文件拆分 + `Level_02_sub01.tscn` + `Level02Data`

本目录保存从第二关移除的「断崖坠落 → 现实干扰 → 睁眼转场 → 现实房间解谜 → 入梦进第三关」完整实现，供后续关卡或分支剧情复用。

## 目录结构

```
Level_02_CliffReality/
├── README.md                          # 本说明
└── snapshots/                         # 移除前的完整文件快照（可直接对照/还原）
    ├── Level_02.gd                    # 主控（含断崖/干扰/现实/终局全流程）
    ├── Level_02_FSM.gd                # 状态机（含 REALITY_* 状态分支）
    ├── Level_02_SceneBuilder.gd       # 双空间构建 + 断崖触发器
    ├── Level_02_UIBuilder.gd          # 红光/短信/睁眼/IDE/配置/重编译 UI
    ├── Level_02_sub01.tscn            # 现实房间子场景
    ├── Level02Data.gd
    └── Level02Data.tres               # 断崖/现实/IDE/配置谜题全部文案
```

## 备份涵盖的机制

### 断崖线（未含断崖地形本身，地形仍留在正式 SceneBuilder）
| 机制 | 主控方法 | 状态 |
|------|----------|------|
| 断崖接近触发 | `_on_cliff_approach_body_entered` | `DREAM_CLIFF_LOOP` |
| 坠落深渊触发 + 黑屏重置 | `_on_fall_pit_body_entered` → `_trigger_fall_reset` | 可重复 |
| 坠落次数达阈值 | `fall_count` + `interference_fall_threshold` | → 干扰期 |
| 首见断崖独白 | `cliff_first_sight_text` | Level02Data |

### 干扰 / 睁眼
| 机制 | 主控方法 | 状态 |
|------|----------|------|
| 红光闪烁 + 梦境灰化 | `_trigger_reality_interference` | `DREAM_INTERFERENCE` |
| 梦境短信回声 UI | `_phone_msg_panel` | 干扰期 |
| 阴影敌人刷新 | `_on_shadow_spawn_timer_timeout` | 干扰期 |
| 玩家沉重化 | `_apply_interference_restrictions` | 干扰期 |
| 长按 Tab 睁眼 | `_update_wake_hold` | `WAKING_HOLD_TAB` |
| 死亡兜底强制惊醒 | `_check_interference_death_guard` | 干扰期 |

### 现实转场与子空间
| 机制 | 主控方法 | 状态 |
|------|----------|------|
| 梦境↔现实空间切换 | `_complete_wake_up_transition` | 隐藏 DreamWorldRoot |
| 玩家换皮 Warrior | `_swap_to_reality_player` | 现实子空间 |
| Level_01 相机/输入规则 | `_apply_reality_space_settings` | 现实子空间 |
| 现实房间场景 | `Level_02_sub01.tscn` | `RealityRoomRoot` |

### 现实交互线 → 第三关
| 顺序 | 交互 | 状态流转 |
|------|------|----------|
| 1 | 手机 | `REALITY_PHONE_LOCKED` → `REALITY_PHONE_READ` |
| 2 | 电脑 | `REALITY_IDE_CHAT` → `REALITY_CONFIG_EDIT` |
| 3 | 配置篡改 | `_set_config_value` × 3 → 重编译 |
| 4 | 重编译 | `REALITY_RECOMPILE` → 写入 `GameManager.dream_runtime_flags` |
| 5 | 床 | `REALITY_BED_READY` → `LEVEL_END_TRANSIT` → Level_03 |

## 接回步骤（概要）

1. 将 `snapshots/` 中对应段落合并回 `LevelModule/Formal/Level_02*.gd`
2. 恢复 `Level_02_SceneBuilder` 中的 `_build_reality_room()`、断崖触发器、现实出生点
3. 恢复 `Level_02_UIBuilder.build_all()` 中的干扰/睁眼/IDE/配置 UI 构建
4. 在 `Level_02.gd` 的 `enum LevelState` 中补回 `DREAM_CLIFF_LOOP` … `REALITY_BED_READY`
5. 确保 `Level_02_sub01.tscn` 路径为 `res://LevelModule/Formal/Level_02_sub01.tscn`
6. `Level02Data.tres` 中断崖/现实/IDE/配置字段已完整保留在快照中

## 跨关卡数据

原流程在重编译成功后写入：

```gdscript
GameManager.dream_runtime_flags = {
    "player_damage_reduction": true,
    "base_jump_height": 99,
    "allow_external_signal": false,
    "dream_version": "2.0"
}
```

`Level_03._apply_dream_runtime_flags()` 读取此字典启用二段跳等增强。若跳过现实线直接进第三关，第三关会使用默认能力（无跨关卡增强）。

## 当前正式版 Level_02 简化说明

移除备份机制后，正式版流程为：

**阁楼（观察满洲窗 → 推门）→ 老街探索（藤椅回忆 + 战斗）→ 关卡结束进第三关**

断崖地形（右墙）仍可作为视觉背景保留，但无坠落触发与现实转场。
