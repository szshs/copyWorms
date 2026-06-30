# ============================================================
# LingnanDropArchiveScreen.gd
# Standalone Lingnan drop archive / display cabinet UI.
#
# Usage:
#   var screen := LingnanDropArchiveScreen.new()
#   add_child(screen)
#   screen.open("mooncake")
# ============================================================
extends CanvasLayer
class_name LingnanDropArchiveScreen

signal closed()

const PANEL_TEXTURE := "res://Assets/UI/Lingnan/lingnan_panel_roof.png"
const BUTTON_TEXTURE := "res://Assets/UI/Lingnan/lingnanbotton_pressed.png"

const COLOR_DIM := Color(0.01, 0.012, 0.014, 0.82)
const COLOR_INK := Color(0.055, 0.095, 0.075, 0.98)
const COLOR_INK_DARK := Color(0.026, 0.046, 0.038, 0.98)
const COLOR_JADE := Color(0.13, 0.36, 0.27, 1.0)
const COLOR_JADE_SOFT := Color(0.20, 0.48, 0.36, 0.86)
const COLOR_GOLD := Color(0.92, 0.68, 0.28, 1.0)
const COLOR_PAPER := Color(0.92, 0.86, 0.72, 1.0)
const COLOR_TEXT := Color(0.10, 0.20, 0.14, 1.0)
const COLOR_TEXT_DARK := Color(0.055, 0.105, 0.075, 1.0)
const COLOR_TEXT_MUTED := Color(0.36, 0.43, 0.34, 1.0)

const ITEM_DATA: Array[Dictionary] = [
	{
		"id": "mooncake",
		"name": "月饼",
		"rarity": "广府记忆",
		"source": "岭南梦境 · 街巷敌人掉落",
		"icon": "res://Assets/Effects/月饼.png",
		"usage": "恢复少量精神稳定度，并记录一次节庆记忆。",
		"description": "雕花饼模压出的月饼，表皮留着细密纹路。它不是单纯的食物，更像从梦境里凝结出的团圆符号。",
		"lore": "广府节庆常以食物维系家族和街坊关系。梦境将这种关系压缩成可拾取的物件，提醒玩家：记忆不是宏大的叙事，而是仍能被分食的一小块甜。"
	},
	{
		"id": "har_gow",
		"name": "虾饺",
		"rarity": "茶楼珍品",
		"source": "岭南梦境 · 茶楼幻影",
		"icon": "res://Assets/Effects/虾饺.png",
		"usage": "短时间提高移动流畅度，减少梦境迟滞。",
		"description": "半透明的虾饺在光下像满洲窗的彩玻璃。薄皮包住鲜红内馅，也包住一句没有说出口的早茶问候。",
		"lore": "茶楼是岭南城市的公共客厅。虾饺代表一种日常秩序：慢慢坐下，慢慢说话，慢慢从混乱里恢复人的节奏。"
	},
	{
		"id": "kapok",
		"name": "木棉",
		"rarity": "英雄花",
		"source": "岭南梦境 · 老街树影",
		"icon": "res://Assets/Effects/木棉.png",
		"usage": "用于解锁岭南图鉴中的地点记录。",
		"description": "落在青砖地上的木棉花，颜色像燃尽前的火。它没有香气，却有一种站直的力量。",
		"lore": "木棉常被称作英雄花。它在梦里不是装饰，而是对抗侵蚀的标记：即使城市不断被改写，也仍有东西保持挺拔。"
	},
	{
		"id": "lion_dance",
		"name": "醒狮",
		"rarity": "醒梦之物",
		"source": "岭南梦境 · 祠前仪式",
		"icon": "res://Assets/Effects/醒狮.png",
		"usage": "触发一次醒梦提示，标记附近关键交互。",
		"description": "狮头的眼睛像刚点亮的灯。它被拾起时没有锣鼓声，但梦境边缘会短暂震动。",
		"lore": "醒狮既是表演，也是驱邪和开新的仪式。作为掉落物，它象征玩家重新夺回对梦的主动权。"
	},
	{
		"id": "siu_mai",
		"name": "广式烧卖",
		"rarity": "市井风味",
		"source": "岭南梦境 · 骑楼摊档",
		"icon": "res://Assets/Effects/广式烧卖.png",
		"usage": "补充少量体力，并增加图鉴收集进度。",
		"description": "热气在梦中凝成一圈浅金色的光。烧卖不贵重，却有真实生活的重量。",
		"lore": "岭南的市井并不只属于怀旧，它是一套仍在运转的生活技术。摊档、骑楼和人声共同构成城市的低频心跳。"
	},
	{
		"id": "palm_fan",
		"name": "蒲葵扇",
		"rarity": "旧物回声",
		"source": "岭南梦境 · 祖屋角落",
		"icon": "res://Assets/Effects/蒲葵扇.png",
		"usage": "短暂驱散屏幕边缘的梦境雾化效果。",
		"description": "一把磨得发亮的蒲葵扇，边缘有旧线缝补。扇面轻轻一晃，像把闷热和噪声都推远了。",
		"lore": "蒲葵扇连接着家庭、夏夜和街巷乘凉的经验。它的价值不在稀有，而在于它让梦境重新出现人的温度。"
	}
]

var _root: Control = null
var _main_panel: Panel = null
var _selected_index: int = 0
var _item_buttons: Array[Button] = []
var _left_icon: TextureRect = null
var _left_placeholder: Label = null
var _name_label: Label = null
var _rarity_label: Label = null
var _source_label: Label = null
var _usage_label: Label = null
var _article_label: RichTextLabel = null
var _was_opened: bool = false


func _ready() -> void:
	layer = 850
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _exit_tree() -> void:
	_restore_game_state()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_pause"):
		close()
		get_viewport().set_input_as_handled()


static func show_archive(parent: Node, selected_id: String = "") -> LingnanDropArchiveScreen:
	var screen := LingnanDropArchiveScreen.new()
	parent.add_child(screen)
	screen.open(selected_id)
	return screen


func open(selected_id: String = "") -> void:
	if _root == null:
		_build_ui()
	_center_main_panel()
	visible = true
	_was_opened = true
	InputManager.block_input("岭南图鉴", self)
	InputManager.set_pause_allowed(false)
	var player = GameManager.player_ref
	if player and is_instance_valid(player) and player.has_method("set_frozen"):
		player.set_frozen(true)
	_select_item(_index_for_id(selected_id))
	_play_open_motion()


func close() -> void:
	if not visible:
		return
	visible = false
	_restore_game_state()
	closed.emit()
	queue_free()


func _restore_game_state() -> void:
	if not _was_opened:
		return
	_was_opened = false
	var player = GameManager.player_ref
	if player and is_instance_valid(player) and player.has_method("set_frozen"):
		player.set_frozen(false)
	InputManager.unblock_input("岭南图鉴")
	InputManager.set_pause_allowed(true)


func _build_ui() -> void:
	if _root:
		return
	_root = Control.new()
	_root.name = "LingnanDropArchiveRoot"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)

	var dim := ColorRect.new()
	dim.name = "ArchiveDim"
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = COLOR_DIM
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	_main_panel = Panel.new()
	_main_panel.name = "LingnanArchivePanel"
	_main_panel.size = Vector2(1180, 640)
	_main_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_panel.add_theme_stylebox_override("panel", _make_main_panel_style())
	_root.add_child(_main_panel)
	_center_main_panel()

	_add_header()
	_add_left_display()
	_add_item_cabinet()
	_add_article_area()
	_add_close_button()
	_select_item(0)


func _add_header() -> void:
	var title := Label.new()
	title.name = "ArchiveTitle"
	title.text = "岭南梦物志"
	title.position = Vector2(116, 106)
	title.size = Vector2(420, 48)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	title.add_theme_color_override("font_outline_color", Color(0.94, 0.84, 0.62, 0.8))
	title.add_theme_constant_override("outline_size", 2)
	_main_panel.add_child(title)

	_add_line(Vector2(86, 160), Vector2(1000, 2), Color(0.42, 0.34, 0.20, 0.42))
	_add_line(Vector2(86, 166), Vector2(1000, 1), Color(0.12, 0.28, 0.20, 0.26))


func _add_left_display() -> void:
	var display := Panel.new()
	display.name = "SelectedItemDisplay"
	display.position = Vector2(82, 158)
	display.size = Vector2(292, 402)
	display.add_theme_stylebox_override("panel", _make_display_style())
	_main_panel.add_child(display)

	var lamp := ColorRect.new()
	lamp.name = "CabinetLamp"
	lamp.position = Vector2(38, 24)
	lamp.size = Vector2(216, 5)
	lamp.color = Color(1.0, 0.78, 0.34, 0.76)
	lamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.add_child(lamp)

	var icon_frame := Panel.new()
	icon_frame.name = "SelectedIconFrame"
	icon_frame.position = Vector2(44, 48)
	icon_frame.size = Vector2(204, 184)
	icon_frame.add_theme_stylebox_override("panel", _make_glass_style(true))
	display.add_child(icon_frame)

	_left_icon = TextureRect.new()
	_left_icon.name = "SelectedIcon"
	_left_icon.position = Vector2(18, 14)
	_left_icon.size = Vector2(168, 150)
	_left_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_left_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_left_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(_left_icon)

	_left_placeholder = Label.new()
	_left_placeholder.name = "SelectedIconPlaceholder"
	_left_placeholder.position = Vector2(18, 58)
	_left_placeholder.size = Vector2(168, 42)
	_left_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_left_placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_left_placeholder.add_theme_font_size_override("font_size", 28)
	_left_placeholder.add_theme_color_override("font_color", COLOR_PAPER)
	_left_placeholder.hide()
	icon_frame.add_child(_left_placeholder)

	_name_label = _make_info_label("", Vector2(30, 254), Vector2(232, 36), 30, COLOR_PAPER)
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display.add_child(_name_label)

	_rarity_label = _make_info_label("", Vector2(44, 296), Vector2(204, 28), 20, COLOR_GOLD)
	_rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display.add_child(_rarity_label)

	_source_label = _make_info_label("", Vector2(28, 330), Vector2(236, 48), 17, Color(0.73, 0.86, 0.76, 1.0))
	_source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_source_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	display.add_child(_source_label)


func _add_item_cabinet() -> void:
	var cabinet := Panel.new()
	cabinet.name = "DropCabinetGrid"
	cabinet.position = Vector2(408, 170)
	cabinet.size = Vector2(342, 390)
	cabinet.add_theme_stylebox_override("panel", _make_cabinet_style())
	_main_panel.add_child(cabinet)

	var title := Label.new()
	title.text = "展柜目录"
	title.position = Vector2(28, 20)
	title.size = Vector2(180, 28)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", COLOR_PAPER)
	cabinet.add_child(title)

	var hint := Label.new()
	hint.text = "点击物件查看百科"
	hint.position = Vector2(210, 25)
	hint.size = Vector2(106, 22)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_font_size_override("font_size", 15)
	hint.add_theme_color_override("font_color", Color(0.64, 0.76, 0.64, 1.0))
	cabinet.add_child(hint)

	_item_buttons.clear()
	for i in range(ITEM_DATA.size()):
		var row := int(i / 2)
		var col := i % 2
		var btn := _make_item_button(i)
		btn.position = Vector2(28 + col * 146, 68 + row * 98)
		cabinet.add_child(btn)
		_item_buttons.append(btn)


func _add_article_area() -> void:
	var article := Panel.new()
	article.name = "ArchiveArticlePanel"
	article.position = Vector2(782, 158)
	article.size = Vector2(314, 402)
	article.add_theme_stylebox_override("panel", _make_paper_style())
	_main_panel.add_child(article)

	var title := Label.new()
	title.text = "百科札记"
	title.position = Vector2(28, 26)
	title.size = Vector2(180, 30)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", COLOR_TEXT_DARK)
	article.add_child(title)

	_usage_label = Label.new()
	_usage_label.name = "UsageLabel"
	_usage_label.position = Vector2(30, 68)
	_usage_label.size = Vector2(254, 54)
	_usage_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_usage_label.add_theme_font_size_override("font_size", 18)
	_usage_label.add_theme_color_override("font_color", COLOR_JADE)
	article.add_child(_usage_label)

	_add_line_to(article, Vector2(30, 132), Vector2(254, 2), Color(0.42, 0.34, 0.20, 0.32))

	_article_label = RichTextLabel.new()
	_article_label.name = "ArticleText"
	_article_label.position = Vector2(30, 150)
	_article_label.size = Vector2(254, 214)
	_article_label.bbcode_enabled = true
	_article_label.fit_content = false
	_article_label.scroll_active = true
	_article_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_article_label.add_theme_font_size_override("normal_font_size", 18)
	_article_label.add_theme_color_override("default_color", COLOR_TEXT)
	_article_label.add_theme_constant_override("line_separation", 5)
	article.add_child(_article_label)


func _add_close_button() -> void:
	var btn := Button.new()
	btn.name = "CloseButton"
	btn.text = "退出图鉴"
	btn.position = Vector2(936, 88)
	btn.size = Vector2(142, 46)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _make_lingnan_button_style("normal"))
	btn.add_theme_stylebox_override("hover", _make_lingnan_button_style("hover"))
	btn.add_theme_stylebox_override("pressed", _make_lingnan_button_style("pressed"))
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", COLOR_PAPER)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", COLOR_GOLD)
	btn.pressed.connect(close)
	_main_panel.add_child(btn)


func _make_item_button(index: int) -> Button:
	var item := ITEM_DATA[index]
	var btn := Button.new()
	btn.name = "DropItem_%s" % str(item.get("id", index))
	btn.size = Vector2(126, 82)
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = ""
	btn.add_theme_stylebox_override("normal", _make_item_style(false, false))
	btn.add_theme_stylebox_override("hover", _make_item_style(false, true))
	btn.add_theme_stylebox_override("pressed", _make_item_style(true, false))

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.position = Vector2(14, 8)
	icon.size = Vector2(98, 46)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture = _load_texture(str(item.get("icon", "")))
	btn.add_child(icon)

	var placeholder := Label.new()
	placeholder.name = "Placeholder"
	placeholder.position = Vector2(10, 12)
	placeholder.size = Vector2(106, 36)
	placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	placeholder.add_theme_font_size_override("font_size", 18)
	placeholder.add_theme_color_override("font_color", COLOR_PAPER)
	placeholder.text = str(item.get("name", "?"))
	placeholder.visible = icon.texture == null
	placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(placeholder)

	var label := Label.new()
	label.name = "Name"
	label.text = str(item.get("name", "未命名"))
	label.position = Vector2(8, 56)
	label.size = Vector2(110, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", COLOR_PAPER)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(label)

	btn.pressed.connect(func() -> void:
		_select_item(index)
	)
	return btn


func _select_item(index: int) -> void:
	_selected_index = clampi(index, 0, ITEM_DATA.size() - 1)
	var item := ITEM_DATA[_selected_index]
	var texture := _load_texture(str(item.get("icon", "")))
	_left_icon.texture = texture
	_left_icon.visible = texture != null
	_left_placeholder.text = str(item.get("name", "?"))
	_left_placeholder.visible = texture == null
	_name_label.text = str(item.get("name", "未命名"))
	_rarity_label.text = "◇ " + str(item.get("rarity", "未知品级")) + " ◇"
	_source_label.text = str(item.get("source", "来源未记录"))
	_usage_label.text = "用途：" + str(item.get("usage", "暂无用途记录。"))
	_article_label.text = "[b]说明[/b]\n%s\n\n[b]背景[/b]\n%s" % [
		str(item.get("description", "暂无说明。")),
		str(item.get("lore", "暂无背景记录。"))
	]
	_refresh_item_button_states()


func _refresh_item_button_states() -> void:
	for i in range(_item_buttons.size()):
		var btn := _item_buttons[i]
		var selected := i == _selected_index
		btn.add_theme_stylebox_override("normal", _make_item_style(selected, false))
		btn.add_theme_stylebox_override("hover", _make_item_style(selected, true))
		btn.add_theme_stylebox_override("pressed", _make_item_style(true, false))


func _index_for_id(selected_id: String) -> int:
	if selected_id == "":
		return 0
	for i in range(ITEM_DATA.size()):
		if str(ITEM_DATA[i].get("id", "")) == selected_id or str(ITEM_DATA[i].get("name", "")) == selected_id:
			return i
	return 0


func _play_open_motion() -> void:
	if not _main_panel:
		return
	_main_panel.modulate.a = 0.0
	_main_panel.scale = Vector2(0.985, 0.985)
	_main_panel.pivot_offset = _main_panel.size / 2.0
	var tw := create_tween()
	tw.tween_property(_main_panel, "modulate:a", 1.0, 0.16)
	tw.parallel().tween_property(_main_panel, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _center_main_panel() -> void:
	if not _main_panel:
		return
	var viewport_size := Vector2(1280, 720)
	if get_viewport():
		viewport_size = get_viewport().get_visible_rect().size
	_main_panel.position = (viewport_size - _main_panel.size) * 0.5


func _make_info_label(text: String, pos: Vector2, size: Vector2, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.62))
	label.add_theme_constant_override("outline_size", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _add_line(pos: Vector2, size: Vector2, color: Color) -> void:
	_add_line_to(_main_panel, pos, size, color)


func _add_line_to(parent: Node, pos: Vector2, size: Vector2, color: Color) -> void:
	var line := ColorRect.new()
	line.position = pos
	line.size = size
	line.color = color
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(line)


func _make_main_panel_style() -> StyleBox:
	var texture_style := _make_texture_style(PANEL_TEXTURE, Vector4(88, 116, 88, 66), Vector4(72, 96, 72, 62))
	if texture_style:
		return texture_style
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.83, 0.78, 0.64, 0.98)
	style.border_color = COLOR_JADE
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0, 0, 0, 0.48)
	style.shadow_size = 18
	return style


func _make_display_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = COLOR_INK
	style.border_color = Color(0.36, 0.23, 0.10, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 10
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style


func _make_cabinet_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.12, 0.09, 0.96)
	style.border_color = Color(0.50, 0.35, 0.16, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.shadow_color = Color(0, 0, 0, 0.34)
	style.shadow_size = 8
	return style


func _make_paper_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.91, 0.86, 0.74, 0.98)
	style.border_color = Color(0.46, 0.36, 0.20, 0.92)
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.20)
	style.shadow_size = 8
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	return style


func _make_glass_style(selected: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.84, 0.95, 0.88, 0.08)
	style.border_color = COLOR_GOLD if selected else COLOR_JADE_SOFT
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.shadow_size = 6
	return style


func _make_item_style(selected: bool, hover: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.09, 0.16, 0.12, 0.98)
	if selected:
		style.bg_color = Color(0.13, 0.23, 0.17, 1.0)
		style.border_color = COLOR_GOLD
		style.shadow_color = Color(0.95, 0.65, 0.18, 0.28)
		style.shadow_size = 10
	elif hover:
		style.bg_color = Color(0.12, 0.22, 0.16, 1.0)
		style.border_color = Color(0.54, 0.76, 0.58, 1.0)
		style.shadow_color = Color(0.3, 0.8, 0.55, 0.20)
		style.shadow_size = 8
	else:
		style.border_color = Color(0.28, 0.46, 0.34, 0.85)
		style.shadow_color = Color(0, 0, 0, 0.20)
		style.shadow_size = 4
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	style.content_margin_left = 4
	style.content_margin_right = 4
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	return style


func _make_lingnan_button_style(state: String) -> StyleBox:
	var texture_style := _make_texture_style(BUTTON_TEXTURE, Vector4(38, 30, 38, 30), Vector4(18, 8, 18, 8))
	if texture_style:
		return texture_style
	var style := StyleBoxFlat.new()
	match state:
		"hover":
			style.bg_color = Color(0.13, 0.27, 0.20, 1.0)
			style.border_color = COLOR_GOLD
		"pressed":
			style.bg_color = Color(0.05, 0.10, 0.08, 1.0)
			style.border_color = COLOR_GOLD
		_:
			style.bg_color = COLOR_INK_DARK
			style.border_color = COLOR_JADE_SOFT
	style.set_border_width_all(3)
	style.set_corner_radius_all(7)
	return style


func _make_texture_style(path: String, texture_margins: Vector4, content_margins: Vector4) -> StyleBoxTexture:
	var tex := _load_texture(path)
	if tex == null:
		return null
	var style := StyleBoxTexture.new()
	style.texture = tex
	style.texture_margin_left = texture_margins.x
	style.texture_margin_top = texture_margins.y
	style.texture_margin_right = texture_margins.z
	style.texture_margin_bottom = texture_margins.w
	style.content_margin_left = content_margins.x
	style.content_margin_top = content_margins.y
	style.content_margin_right = content_margins.z
	style.content_margin_bottom = content_margins.w
	style.draw_center = true
	return style


func _load_texture(path: String) -> Texture2D:
	if path == "":
		return null
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	if FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			return ImageTexture.create_from_image(image)
	return null
