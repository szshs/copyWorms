# ============================================================
# Level_02_UIBuilder.gd - 关卡2 UI 构建器
# 负责构建关卡2全部 Canvas UI（纯代码构建，与关卡1模式一致）:
#   BlackoutOverlay / NarrativePanel / RedWarningOverlay /
#   PhoneMessageOverlay / EyeCloseOverlay(4块ColorRect) /
#   IdeUI / ConfigEditorUI / RecompileLogPanel / EndingPrompt
# 只构建节点并写入主控字段，不持有任何流程状态
# ============================================================
extends RefCounted
class_name Level_02_UIBuilder

var level: Level_02
var canvas: CanvasLayer

const VIEW_W: float = 1280.0
const VIEW_H: float = 720.0

func _init(parent: Level_02, canvas_layer: CanvasLayer) -> void:
	level = parent
	canvas = canvas_layer

func build_all() -> void:
	_build_blackout_overlay()
	_build_narrative_panel()
	_build_red_warning_overlay()
	_build_phone_message_overlay()
	_build_eye_close_overlay()
	_build_ide_ui()
	_build_config_editor_ui()
	_build_recompile_log_panel()
	_build_ending_prompt()

# ---- 黑屏遮罩（坠落重置/转场共用） ----

func _build_blackout_overlay() -> void:
	var overlay = ColorRect.new()
	overlay.name = "BlackoutOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	level._blackout_overlay = overlay

# ---- 叙事面板（复用关卡1样式） ----

func _build_narrative_panel() -> void:
	var panel = Panel.new()
	panel.name = "NarrativePanel"
	panel.visible = false
	panel.size = Vector2(1280, 200)
	panel.position = Vector2(0, 520)

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
	panel.add_child(label)
	level._narrative_text = label

	canvas.add_child(panel)
	level._narrative_panel = panel

# ---- 干扰红光遮罩 ----

func _build_red_warning_overlay() -> void:
	var overlay = ColorRect.new()
	overlay.name = "RedWarningOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.8, 0.05, 0.05, 0.0)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	level._red_overlay = overlay

	# 长按 Tab 睁眼提示（干扰期显示）
	var hint = Label.new()
	hint.name = "WakeHintLabel"
	hint.visible = false
	hint.text = "长按【Tab】睁开眼睛"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_color", Color(1, 0.85, 0.85, 0.95))
	hint.position = Vector2(440, 70)
	hint.size = Vector2(400, 40)
	canvas.add_child(hint)
	level._wake_hint_label = hint

# ---- 梦境短信 UI（干扰期右上角弹出） ----

func _build_phone_message_overlay() -> void:
	var panel = Panel.new()
	panel.name = "PhoneMessageOverlay"
	panel.visible = false
	panel.size = Vector2(380, 180)
	panel.position = Vector2(870, 30)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.92)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.9, 0.2, 0.2, 0.9)
	style.set_corner_radius_all(6)
	panel.add_theme_stylebox_override("panel", style)

	var label = RichTextLabel.new()
	label.name = "MessageText"
	label.size = Vector2(348, 150)
	label.position = Vector2(16, 14)
	label.bbcode_enabled = true
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_color_override("default_color", Color(0.95, 0.85, 0.85))
	panel.add_child(label)
	level._phone_msg_text = label

	canvas.add_child(panel)
	level._phone_msg_panel = panel

# ---- 睁眼遮罩（4 块黑色 ColorRect 向中心收缩） ----

func _build_eye_close_overlay() -> void:
	var overlay = Control.new()
	overlay.name = "EyeCloseOverlay"
	overlay.visible = false
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var top = ColorRect.new()
	top.name = "EyeTop"
	top.color = Color(0, 0, 0, 1)
	top.position = Vector2(0, 0)
	top.size = Vector2(VIEW_W, 0)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(top)
	level._eye_rect_top = top

	var bottom = ColorRect.new()
	bottom.name = "EyeBottom"
	bottom.color = Color(0, 0, 0, 1)
	bottom.position = Vector2(0, VIEW_H)
	bottom.size = Vector2(VIEW_W, 0)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(bottom)
	level._eye_rect_bottom = bottom

	var left = ColorRect.new()
	left.name = "EyeLeft"
	left.color = Color(0, 0, 0, 1)
	left.position = Vector2(0, 0)
	left.size = Vector2(0, VIEW_H)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(left)
	level._eye_rect_left = left

	var right = ColorRect.new()
	right.name = "EyeRight"
	right.color = Color(0, 0, 0, 1)
	right.position = Vector2(VIEW_W, 0)
	right.size = Vector2(0, VIEW_H)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(right)
	level._eye_rect_right = right

	canvas.add_child(overlay)
	level._eye_overlay = overlay

# ---- CodeBuddy IDE 对话窗口 ----

func _build_ide_ui() -> void:
	var ide = Control.new()
	ide.name = "IdeUI"
	ide.visible = false
	ide.set_anchors_preset(Control.PRESET_FULL_RECT)

	var bg = ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.07, 0.1, 0.97)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ide.add_child(bg)

	var title_bar = ColorRect.new()
	title_bar.name = "TitleBar"
	title_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_bar.color = Color(0.1, 0.12, 0.18, 1.0)
	title_bar.custom_minimum_size = Vector2(0, 40)
	title_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ide.add_child(title_bar)

	var title_label = Label.new()
	title_label.name = "TitleLabel"
	title_label.text = "◆ AI IDE v1.4.2 — localhost:8080 — Xiguan_Dream [RECOVERED]"
	title_label.add_theme_font_size_override("font_size", 15)
	title_label.add_theme_color_override("font_color", Color(0.4, 0.85, 0.5))
	title_label.position = Vector2(15, 10)
	ide.add_child(title_label)

	var chat_panel = Panel.new()
	chat_panel.name = "ChatPanel"
	chat_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	chat_panel.offset_left = 20
	chat_panel.offset_top = 55
	chat_panel.offset_right = -20
	chat_panel.offset_bottom = -25

	var chat_style = StyleBoxFlat.new()
	chat_style.bg_color = Color(0.08, 0.1, 0.14, 0.9)
	chat_style.border_width_left = 2
	chat_style.border_width_right = 2
	chat_style.border_width_top = 2
	chat_style.border_width_bottom = 2
	chat_style.border_color = Color(0.2, 0.25, 0.35)
	chat_style.set_corner_radius_all(6)
	chat_panel.add_theme_stylebox_override("panel", chat_style)
	ide.add_child(chat_panel)

	var chat = RichTextLabel.new()
	chat.name = "ChatWindow"
	chat.set_anchors_preset(Control.PRESET_FULL_RECT)
	chat.offset_left = 35
	chat.offset_top = 70
	chat.offset_right = -35
	chat.offset_bottom = -60
	chat.bbcode_enabled = true
	chat.scroll_following = true
	chat.add_theme_font_size_override("normal_font_size", 15)
	chat.add_theme_color_override("default_color", Color(0.85, 0.85, 0.85))
	ide.add_child(chat)
	level._chat_window = chat

	var hint = Label.new()
	hint.name = "ContinueHint"
	hint.text = "按【Enter】继续 ▼"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	hint.position = Vector2(1080, 678)
	ide.add_child(hint)

	canvas.add_child(ide)
	level._ide_ui = ide

# ---- 配置篡改编辑器（Xiguan_Dream.ini） ----

func _build_config_editor_ui() -> void:
	var panel = Panel.new()
	panel.name = "ConfigEditorUI"
	panel.visible = false
	panel.size = Vector2(840, 460)
	panel.position = Vector2(220, 130)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.09, 0.12, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.3, 0.5, 0.4)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var title = Label.new()
	title.name = "ConfigTitle"
	title.text = "▣ Xiguan_Dream.ini — 配置编辑器"
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.5, 0.9, 0.6))
	title.position = Vector2(24, 16)
	panel.add_child(title)

	level._config_value_labels.clear()
	level._config_feedback_labels.clear()
	level._config_buttons.clear()

	# 三行配置项（标签 / 当前值 / 修改按钮 / 反馈），具体文案由主控填充
	for i in range(3):
		var row_y = 70 + i * 100

		var item_label = Label.new()
		item_label.name = "ItemLabel_%d" % i
		item_label.add_theme_font_size_override("font_size", 16)
		item_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.8))
		item_label.position = Vector2(36, row_y)
		item_label.size = Vector2(480, 24)
		panel.add_child(item_label)

		var value_label = Label.new()
		value_label.name = "ValueLabel_%d" % i
		value_label.add_theme_font_size_override("font_size", 16)
		value_label.add_theme_color_override("font_color", Color(0.95, 0.6, 0.3))
		value_label.position = Vector2(540, row_y)
		value_label.size = Vector2(140, 24)
		panel.add_child(value_label)
		level._config_value_labels.append(value_label)

		var btn = Button.new()
		btn.name = "ModifyButton_%d" % i
		btn.text = "修改"
		btn.position = Vector2(700, row_y - 4)
		btn.size = Vector2(100, 34)
		btn.add_theme_font_size_override("font_size", 15)
		btn.pressed.connect(level._on_config_button_pressed.bind(i))
		panel.add_child(btn)
		level._config_buttons.append(btn)

		var feedback = Label.new()
		feedback.name = "Feedback_%d" % i
		feedback.add_theme_font_size_override("font_size", 13)
		feedback.add_theme_color_override("font_color", Color(0.4, 0.8, 0.5))
		feedback.position = Vector2(36, row_y + 32)
		feedback.size = Vector2(760, 22)
		feedback.text = ""
		panel.add_child(feedback)
		level._config_feedback_labels.append(feedback)

	var recompile_btn = Button.new()
	recompile_btn.name = "RecompileButton"
	recompile_btn.text = "⟳ 重新编译并注入梦境"
	recompile_btn.disabled = true
	recompile_btn.position = Vector2(280, 392)
	recompile_btn.size = Vector2(280, 44)
	recompile_btn.add_theme_font_size_override("font_size", 16)
	recompile_btn.pressed.connect(level._on_recompile_pressed)
	panel.add_child(recompile_btn)
	level._recompile_button = recompile_btn

	canvas.add_child(panel)
	level._config_ui = panel

# ---- 重编译日志面板 ----

func _build_recompile_log_panel() -> void:
	var panel = Panel.new()
	panel.name = "RecompileLogPanel"
	panel.visible = false
	panel.size = Vector2(840, 420)
	panel.position = Vector2(220, 150)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.05, 0.04, 0.98)
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.2, 0.6, 0.3)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)

	var log_text = RichTextLabel.new()
	log_text.name = "LogText"
	log_text.size = Vector2(792, 380)
	log_text.position = Vector2(24, 20)
	log_text.bbcode_enabled = true
	log_text.scroll_following = true
	log_text.add_theme_font_size_override("normal_font_size", 15)
	log_text.add_theme_color_override("default_color", Color(0.5, 0.9, 0.55))
	panel.add_child(log_text)
	level._recompile_log = log_text

	canvas.add_child(panel)
	level._recompile_panel = panel

# ---- 终局提示（"西关梦境 v2.0..."） ----

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
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.85, 0.8, 0.7))
	label.position = Vector2(240, 240)
	label.size = Vector2(800, 240)
	prompt.add_child(label)
	level._ending_label = label

	canvas.add_child(prompt)
	level._ending_prompt = prompt
