# 织梦者 · HackathonGame

> 一款用 **Godot 4.6** 制作的 2D 横版叙事探索游戏——在岭南骑楼与赛博幻景之间，跟随开发者阿明，从一场「西关梦境」走向现实。

**当前版本：v0.13.0** · GDScript · GL Compatibility · 1280×720

---

## 游戏简介

《织梦者》以**叙事驱动**为核心：关卡即状态机，探索、对话与交互推动剧情，战斗为叙事服务。玩家从卧室醒来，穿过老街与断崖，在 IDE 里与 AI 对话、篡改「梦境配置」，最终在维度侵蚀与 Boss 战中觉醒——结局落在一句：**「太阳照常升起」**。

---

## 特色

- **完整 7 关流水线**：从标题界面到终局再回标题，全流程可通关
- **双世界视觉**：岭南骑楼 ↔ 赛博城市场景切换，PixelTearing 侵蚀与 Glitch 演出
- **分段式大关卡**：Level_02 拆为 4 段（阁楼→老街→梯子谜题→断崖/现实房间/IDE）
- **IDE 解谜**：CODE-BUDDY 风格对话界面，配置篡改 + 重编译叙事
- **多样敌人**：灯笼鬼、纸扎人、赛博狼/牛、花旦 Boss（4 阶段 AI）
- **全局音频**：`MusicManager` BGM 淡入淡出 + `SFXManager` 音效池
- **Shader 特效**：代码雨、防火墙结界、记忆光团、像素崩坏等

---

## 关卡流程

```
TitleScreen
  → Level_01   卧室觉醒 · IDE · 手机 climax
  → Level_02   阁楼 → 老街（+ 02_01 / 02_02 / 02_03 分段）
  → Level_03   赛博蜃景 · 爷爷 · 记忆光团
  → Level_04   维度侵蚀 · 双世界硬切
  → Level_05   Boss 花旦战 · 视频演出
  → Level_final  「太阳照常升起」
  → TitleScreen  （闭环）
```

---

## 操作说明

| 按键 | 功能 |
|------|------|
| `A` / `D` 或方向键 | 移动 |
| `Space` | 跳跃 |
| `J` / 鼠标左键 | 攻击 |
| `K` / `Shift` | 闪身 |
| `I` | 技能 |
| `Enter` | 交互 / 确认对话 |
| `Esc` | 暂停 |
| `W` / `S` | 梯子攀爬（部分关卡） |
| `G` | 切换外观（Level_05） |
| 长按 `Tab` | 睁眼（Level_02_03 干扰期） |

> 叙事关卡会动态禁用部分操作（如 Level_01 禁攻击/跳跃/闪身）。

---

## 快速开始

### 环境要求

- [Godot 4.6](https://godotengine.org/)（GL Compatibility 渲染器）
- 无需额外依赖，克隆即用

### 运行

1. 克隆仓库
2. 用 Godot 4.6 打开项目根目录（含 `project.godot`）
3. 按 **F5** 运行，或导入后点击「运行项目」

主场景：`res://UI/TitleScreen.tscn`

### Web 导出（可选）

项目已配置 HTML5 导出预设，导出路径：`../织梦者导出/index.html`

---

## 技术概览

| 项目 | 说明 |
|------|------|
| 引擎 | Godot 4.6 · GDScript |
| 架构 | 事件总线（EventBus）+ Autoload 全局系统 |
| Autoload | `GlobalDefine` · `EventBus` · `GameManager` · `InputManager` · `KeybindManager` · `MusicManager` · `SFXManager` |
| 关卡模式 | 主控 + SceneBuilder + FSM + UIBuilder + Config/Data 资源 |
| 玩家皮肤 | Warrior / Cyber / Lingnan（含 SmoothCamera） |

```
copyWorms/
├── Global/           # Autoload、MainEntry 正式入口
├── LevelModule/      # 关卡脚本与场景（Level_01 ~ Level_final）
├── PlayerModule/     # 玩家与摄像机
├── EnemyModule/      # 敌人与 Boss
├── DataConfig/       # LevelConfig / LevelData 数值与文案
├── UI/               # TitleScreen、HUD、键位设置
├── Tools/            # CodeRain、WarningBarrier、弹体特效等
└── Assets/           # 音乐、音效、贴图、字体
```

详细设计文档见 **[TECHNICAL_ARCHITECTURE_REPORT.md](./TECHNICAL_ARCHITECTURE_REPORT.md)**（面向关卡设计与二次开发）。

---

## 开发说明

- **叙事文案**：优先编辑 `DataConfig/Level/LevelXXData.tres`，避免在 `.gd` 中硬编码字符串
- **跨模块通信**：统一走 `EventBus`，碰撞层使用 `GlobalDefine.Collision.*` 常量
- **关卡切换**：Level_01~04 由 `MainEntry` 托管；Level_04 之后使用 `change_scene_to_file` 整树切换

---

## 致谢

黑客松参赛项目 · 岭南文化 × 赛博叙事 × meta 解谜
