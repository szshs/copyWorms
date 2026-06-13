# ============================================================
# Level_03_UIBuilder.gd - 关卡3 UI 构建器
# 负责构建关卡3全部 Canvas UI（纯代码构建，与关卡1/2模式一致）:
#   BlackoutOverlay / NarrativePanel / CodeRainOverlay /
#   WarmGlowOverlay / GlitchOverlay / EndingPrompt
# 只构建节点并写入主控字段，不持有任何流程状态
# ============================================================
extends RefCounted
class_name Level_03_UIBuilder

var level: Level_03
var canvas: CanvasLayer

const VIEW_W: float = 1280.0
const VIEW_H: float = 720.0

func _init(parent: Level_03, canvas_layer: CanvasLayer) -> void:
	level = parent
	canvas = canvas_layer

func build_all() -> void:
	_build_blackout_overlay()
	_build_narrative_panel()
	_build_code_rain_overlay()
	_build_warm_glow_overlay()
	_build_glitch_overlay()
	_build_ending_prompt()


# ---- 黑屏遮罩（转场共用） ----

func _build_blackout_overlay() -> void:
	var overlay = ColorRect.new()
	overlay.name = "BlackoutOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	level._blackout_overlay = overlay


# ---- 叙事面板（复用关卡1/2样式） ----

func _build_narrative_panel() -> void:
	var panel = Panel.new()
	panel.name = "NarrativePanel"
	panel.visible = false
	panel.size = Vector2(1280, 200)
	panel.position = Vector2(0, 520)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var label = RichTextLabel.new()
	label.name = "RichTextLabel"
	label.size = Vector2(1240, 160)
	label.position = Vector2(20, 20)
	label.bbcode_enabled = true
	label.fit_content = true
	label.add_theme_font_size_override("normal_font_size", 18)
	label.add_theme_color_override("default_color", Color(0.9, 0.85, 0.75))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	level._narrative_text = label

	canvas.add_child(panel)
	level._narrative_panel = panel


# ---- 代码雨覆盖层（绿色半透明 + 简单动画） ----

func _build_code_rain_overlay() -> void:
	var overlay = ColorRect.new()
	overlay.name = "CodeRainOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 深绿色半透明，模拟代码雨氛围
	overlay.color = Color(0, 0.15, 0.05, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	level._code_rain_overlay = overlay

	# 代码雨文字区域（模拟绿色代码行下落）
	var code_layer = Control.new()
	code_layer.name = "CodeRainTexts"
	code_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	code_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(code_layer)

	# 生成若干行代码文字
	for i in range(12):
		var code_line = Label.new()
		code_line.name = "CodeLine_%d" % i
		code_line.text = _generate_code_line()
		code_line.add_theme_font_size_override("font_size", 11)
		code_line.add_theme_color_override("font_color", Color(0, 1.0, 0.25, 0.12))
		code_line.position = Vector2(randi_range(50, 900), i * 60)
		code_line.size = Vector2(400, 16)
		code_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		code_layer.add_child(code_line)

## 生成伪代码行（与关卡1的 CODE_SCROLL_LINES 风格一致）
func _generate_code_line() -> String:
	var templates = [
		"var security_matrix = _init_defense()",
		"func _sanitize_memory(data): pass",
		"if player.deviation > threshold:",
		"emit_signal(\"protocol_conflict\")",
		"_rebuild_city(safe_params)",
		"const MAX_DEVIATION = 0.85",
		"for sector in protected_zones:",
		"sector.lockdown()",
		"_override_external_signal()",
		"match dream_state:",
		"SAFE: _maintain_illusion()",
		"BREACH: _deploy_countermeasures()",
	]
	return templates[randi() % templates.size()]


# ---- 温暖光晕覆盖层（光团收集时屏幕泛暖黄） ----

func _build_warm_glow_overlay() -> void:
	var overlay = ColorRect.new()
	overlay.name = "WarmGlowOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(1.0, 0.9, 0.4, 0.0)  # 暖黄色，初始透明
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	level._warm_glow_overlay = overlay


# ---- Glitch 覆盖层（复用关卡1的 GlitchShader） ----

func _build_glitch_overlay() -> void:
	var overlay = ColorRect.new()
	overlay.name = "GlitchOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var shader = load("res://LevelModule/Formal/glitch_effect.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("intensity", 0.0)
		overlay.material = mat

	canvas.add_child(overlay)
	level._glitch_overlay = overlay


# ---- 终局提示（绿色系统文本） ----

func _build_ending_prompt() -> void:
	var prompt = Control.new()
	prompt.name = "EndingPrompt"
	prompt.visible = false
	prompt.set_anchors_preset(Control.PRESET_FULL_RECT)
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0, 0, 0, 0.95)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_child(bg)

	var label = Label.new()
	label.name = "EndingLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 20)
	# 绿色终端文字
	label.add_theme_color_override("font_color", Color(0, 1.0, 0.25, 0.95))
	label.position = Vector2(240, 240)
	label.size = Vector2(800, 240)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.add_child(label)
	level._ending_label = label

	canvas.add_child(prompt)
	level._ending_prompt = prompt
