extends Control

const PAGES := {
	"city": ["Город", "Один экран. Зданий семь, рисунка города нет."],
	"campaign": ["Кампания", "Бой считается на телефоне из отряда. Золото стадии не начисляется."],
	"heroes": ["Герои", "В отряде только те, кто уже есть. Повышение уровня серверное, здесь уровень не растёт."],
	"preview": ["3D-просмотр", "Отдельной витрины нет. Трёхмерные модели видны в бою."],
	"formation": ["Отряд", "Два спереди, три сзади. Слот хранит id героя и переключает только полученных. На сервер не уходит."],
	"inventory": ["Инвентарь", "Шесть слотов и артефакт ещё не работают."],
	"summon": ["Призыв", "Этот экран сервер не вызывает и никого не добавляет."],
	"arena": ["Арена", "Рейтинга и PvP нет. Это не бой кампании и наград нет."],
	"guild": ["Гильдия", "Раздел есть. Совместной игры нет."],
	"dungeons": ["Подземелья", "Раздел есть. Боёв подземелья нет."],
	"fortress": ["Крепость", "База игрока. Золото простоя отсюда не выдаётся."],
	"tavern": ["Таверна", "Гостей нет. Героев и наград не выдаёт."],
	"world": ["Мир", "Отдельной карты нет. Ниже те же места, что стоят в городе."],
	"events": ["События", "Событий нет. Наград нет."],
	"tasks": ["Задания", "Ежедневных заданий нет. Наград нет."],
	"rewards": ["Награды", "Забрать нечего. Ничего не выдаётся."],
	"pass": ["Боевой пропуск", "Пропуска нет. Оплаты нет, ничего не выдаётся."],
	"offers": ["Акции", "Акций нет. Деньги не списываются и награды не выдаются."],
	"shop": ["Магазин", "Лавка и донат только нарисованы. Оплаты нет, ничего не списывается и не выдаётся."],
	"vip": ["VIP", "Скорость боя зависит от VIP. Повысить его с телефона нельзя."],
	"profile": ["Профиль", "Карточка героя. Снаряжение пустое, уровень не растёт."],
	"quests": ["Квесты", "Список пуст. Наград нет."],
	"settings": ["Настройки", "Аккаунт, язык и версия. Сервер с телефона не вызывается."],
	"idle": ["Сбор", "Быстрый сбор наград простоя. Сервер не вызывается, золото не выдаётся."],
	"mail": ["Почта", "Входящих нет. Вложения не выдаются."],
	"chats": ["Чаты", "Три канала. Ни один не подключён, сообщения не отправляются."],
	"chat_server": ["Чат сервера", "Общий канал. Соединения нет."],
	"chat_guild": ["Чат гильдии", "Гильдии нет. Канал не подключён."],
	"chat_pm": ["Личные", "Диалогов нет. Сообщения не отправляются."],
	"more": ["Разделы", "Неготовые разделы открываются и пишут, чего в них нет."],
}

var _margin: MarginContainer
var _title: Label
var _body: Label
var _host: Control
var _bar_buttons: Array[Button] = []
var _page := "city"
var _open_hero := "temp_a"
var _chip_gold: Label
var _chip_gems: Label
var _chip_vip: Button
var _parallax_far: Control
var _parallax_near: Control
var _bobs: Array = []
var _clock := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("1c2430")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	_margin = MarginContainer.new()
	_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_margin)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	_margin.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 34)
	_title.add_theme_color_override("font_color", Color("f4efe4"))
	column.add_child(_title)
	var top := VBoxContainer.new()
	top.add_theme_constant_override("separation", 6)
	column.add_child(top)
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 6)
	top.add_child(top_row)
	top_row.add_child(_top_button("Профиль", func() -> void: _show("profile")))
	var vip := Button.new()
	_chip_vip = vip
	vip.text = "VIP 0"
	vip.custom_minimum_size = Vector2(88, 44)
	vip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(vip)
	vip.pressed.connect(func() -> void: _show("vip"))
	top_row.add_child(vip)
	top_row.add_child(_top_button("Почта", func() -> void: _show("mail")))
	top_row.add_child(_top_button("Настройки", func() -> void: _show("settings")))
	var money := HBoxContainer.new()
	money.add_theme_constant_override("separation", 12)
	top.add_child(money)
	_chip_gold = _chip("Золото: нет")
	_chip_gems = _chip("Алмазы: нет")
	money.add_child(_chip_gold)
	money.add_child(_chip_gems)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_color_override("font_color", Color("c5cdd8"))
	column.add_child(_body)
	_host = Control.new()
	_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_child(_host)
	_build_bar(column)
	get_viewport().size_changed.connect(_apply_safe)
	_apply_safe()
	_show("city")


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED or what == NOTIFICATION_APPLICATION_RESUMED:
		_apply_safe()


func _apply_safe() -> void:
	var screen := DisplayServer.screen_get_size()
	var safe := DisplayServer.get_display_safe_area()
	var view := get_viewport().get_visible_rect().size
	var top := 16
	var left := 16
	var right := 16
	var bottom := 16
	if screen.x > 0 and screen.y > 0 and view.x > 0.0 and view.y > 0.0:
		var sx := view.x / float(screen.x)
		var sy := view.y / float(screen.y)
		left = int(safe.position.x * sx)
		top = int(safe.position.y * sy)
		right = int((screen.x - safe.position.x - safe.size.x) * sx)
		bottom = int((screen.y - safe.position.y - safe.size.y) * sy)
	_margin.add_theme_constant_override("margin_left", maxi(left, 16))
	_margin.add_theme_constant_override("margin_top", maxi(top, 16))
	_margin.add_theme_constant_override("margin_right", maxi(right, 16))
	_margin.add_theme_constant_override("margin_bottom", maxi(bottom, 12))


func _build_bar(column: VBoxContainer) -> void:
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.custom_minimum_size = Vector2(0, 72)
	column.add_child(bar)
	for item in [["heroes", "Герои"], ["inventory", "Инвентарь"], ["city", "Город"], ["quests", "Квесты"], ["world", "Мир"]]:
		var button := Button.new()
		button.text = item[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 64)
		_style_button(button)
		button.set_meta("page", item[0])
		var page := str(item[0])
		button.pressed.connect(func() -> void:
			_show(page)
		)
		bar.add_child(button)
		_bar_buttons.append(button)


func _show(page: String) -> void:
	_page = page
	var info: Array = PAGES[page]
	_title.text = info[0]
	_body.text = info[1]
	_title.visible = page != "city"
	_body.visible = page != "city"
	_chip_gold.text = "Золото: нет"
	_chip_gems.text = "Алмазы: нет"
	_chip_vip.text = "VIP %d" % Roster.vip
	_clear_host()
	_mark_bar()
	if page == "city":
		_city()
	elif page == "heroes":
		_heroes()
	elif page == "profile":
		_profile()
	elif page == "formation":
		_formation()
	elif page == "more":
		_more()
	elif page == "shop":
		_shop()
	elif page == "vip":
		_vip()
	elif page == "settings":
		_settings()
	elif page == "idle":
		_idle()
	elif page == "mail":
		_mail()
	elif page == "chats":
		_chats()
	elif page == "chat_server":
		_chat("Чат сервера")
	elif page == "chat_guild":
		_chat("Чат гильдии")
	elif page == "chat_pm":
		_chat("Личные сообщения")
	elif page == "inventory":
		_inventory()
	elif page == "quests":
		_quests()
	elif page == "summon":
		_summon()
	elif page == "guild" or page == "dungeons":
		_closed()
	elif page == "campaign":
		_body.text = "Стадия %d. Ниже состав врагов. Золото не копится." % Roster.stage
		_before_battle()
	elif page == "arena":
		_plain()
	elif page == "fortress":
		_fortress()
	elif page == "world":
		_world()
	elif page == "tavern" or page == "events" or page == "tasks" or page == "rewards" or page == "pass" or page == "offers":
		_plain()
	elif page == "preview":
		_action("Открыть бой", func() -> void:
			get_tree().change_scene_to_file("res://scenes/battle.tscn")
		)


func _mark_bar() -> void:
	for button in _bar_buttons:
		button.disabled = str(button.get_meta("page")) == _page


func _clear_host() -> void:
	_bobs.clear()
	_parallax_far = null
	_parallax_near = null
	for child in _host.get_children():
		_host.remove_child(child)
		child.free()


func _mount(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(node)


func _process(delta: float) -> void:
	if _page != "city" or _bobs.is_empty():
		return
	_clock += delta
	if is_instance_valid(_parallax_far):
		_parallax_far.position.x = sin(_clock * 0.18) * 16.0
	if is_instance_valid(_parallax_near):
		_parallax_near.position.x = sin(_clock * 0.22) * 8.0
	for bob in _bobs:
		var node: Control = bob["node"]
		if not is_instance_valid(node):
			continue
		var shift := sin(_clock * 1.15 + float(bob["phase"])) * 3.0
		node.offset_top = float(bob["top"]) + shift
		node.offset_bottom = float(bob["bottom"]) + shift


func _city() -> void:
	var root := Control.new()
	_mount(root)
	_parallax_far = _hill_layer(Color("24362c"), 220.0)
	_parallax_near = _hill_layer(Color("31483a"), 140.0)
	root.add_child(_parallax_far)
	root.add_child(_parallax_near)
	var spots := [
		{"page": "fortress", "title": "Крепость", "color": "8d6a3a", "x": 0.50, "y": 0.02, "phase": 0.0},
		{"page": "summon", "title": "Призыв", "color": "3d6d8c", "x": 0.18, "y": 0.26, "phase": 0.8},
		{"page": "tavern", "title": "Таверна", "color": "7a4e3a", "x": 0.78, "y": 0.24, "phase": 1.4},
		{"page": "guild", "title": "Гильдия", "color": "3e6b52", "x": 0.16, "y": 0.50, "phase": 2.0},
		{"page": "arena", "title": "Арена", "color": "8a3d3d", "x": 0.50, "y": 0.48, "phase": 2.6},
		{"page": "campaign", "title": "Кампания", "color": "4d5d86", "x": 0.82, "y": 0.50, "phase": 3.1},
		{"page": "dungeons", "title": "Подземелья", "color": "4a4458", "x": 0.50, "y": 0.74, "phase": 3.8},
	]
	for spot in spots:
		var button := _building_button(str(spot["page"]), str(spot["title"]), Color(str(spot["color"])))
		root.add_child(button)
		_bobs.append({"node": button, "x": float(spot["x"]), "y": float(spot["y"]), "phase": float(spot["phase"]), "top": 0.0, "bottom": 0.0})
	var rail := VBoxContainer.new()
	rail.add_theme_constant_override("separation", 6)
	rail.anchor_left = 1.0
	rail.anchor_right = 1.0
	rail.anchor_top = 0.0
	rail.anchor_bottom = 1.0
	rail.offset_left = -104.0
	rail.offset_right = -4.0
	rail.offset_top = 4.0
	rail.offset_bottom = -4.0
	root.add_child(rail)
	for item in [["events", "События"], ["tasks", "Задания"], ["rewards", "Награды"], ["pass", "Боевой пропуск"], ["offers", "Акции"]]:
		var side := Button.new()
		side.text = item[1]
		side.custom_minimum_size = Vector2(96, 48)
		side.size_flags_vertical = Control.SIZE_EXPAND_FILL
		side.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		side.clip_text = true
		_style_button(side)
		var side_page := str(item[0])
		side.pressed.connect(func() -> void: _show(side_page))
		rail.add_child(side)
	root.resized.connect(_place_buildings)
	_place_buildings()


func _hill_layer(color: Color, height: float) -> ColorRect:
	var hill := ColorRect.new()
	hill.color = color
	hill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hill.anchor_left = -0.08
	hill.anchor_right = 1.08
	hill.anchor_top = 1.0
	hill.anchor_bottom = 1.0
	hill.offset_top = -height
	hill.offset_bottom = 24.0
	return hill


func _place_buildings() -> void:
	if _bobs.is_empty():
		return
	var node0: Control = _bobs[0]["node"]
	var root := node0.get_parent() as Control
	if root == null:
		return
	var usable := maxf(root.size.x - 112.0, 180.0)
	var height := maxf(root.size.y, 320.0)
	var bw := clampf(usable * 0.30, 96.0, 150.0)
	for bob in _bobs:
		var node: Control = bob["node"]
		var left := float(bob["x"]) * usable - bw * 0.5
		var top := float(bob["y"]) * (height - 96.0)
		bob["top"] = top
		bob["bottom"] = top + 84.0
		node.anchor_left = 0.0
		node.anchor_right = 0.0
		node.anchor_top = 0.0
		node.anchor_bottom = 0.0
		node.offset_left = left
		node.offset_right = left + bw
		node.offset_top = top
		node.offset_bottom = top + 84.0


func _building_button(page: String, title: String, color: Color) -> Button:
	var button := Button.new()
	button.text = title
	button.add_theme_font_size_override("font_size", 18)
	button.add_theme_color_override("font_color", Color("f4efe4"))
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(10)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 16
	style.content_margin_bottom = 8
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = color.lightened(0.12)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void: _show(page))
	return button


func _top_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.clip_text = true
	_style_button(button)
	button.pressed.connect(action)
	return button


func _plain() -> void:
	var column := _scroll_column()
	column.add_child(_card(_title.text, _body.text))


func _fortress() -> void:
	var column := _scroll_column()
	column.add_child(_card("Крепость", "База игрока. Быстрый сбор открывается здесь и ничего не выдаёт."))
	column.add_child(_text_button("Сбор", func() -> void: _show("idle")))


func _world() -> void:
	var column := _scroll_column()
	column.add_child(_card("Мир", "Отдельной карты нет. Ниже те же места, что стоят в городе."))
	for item in [["campaign", "Кампания"], ["arena", "Арена"], ["dungeons", "Подземелья"], ["guild", "Гильдия"], ["fortress", "Крепость"], ["formation", "Отряд"], ["chats", "Чаты"], ["shop", "Магазин"]]:
		column.add_child(_nav_button(item[0], item[1]))


func _nav_button(page: String, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(button)
	button.pressed.connect(func() -> void:
		_show(page)
	)
	return button


func _heroes() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_mount(column)
	for hero_id in Roster.owned_ids():
		var row: Dictionary = Roster.combat(str(hero_id))
		var role := "танк"
		if str(row["role"]) == "ranger":
			role = "стрелок"
		elif str(row["role"]) == "healer":
			role = "целитель"
		var picked := str(hero_id)
		var button := Button.new()
		button.text = "%s\n%s, уровень %d" % [str(row["name"]), role, int(row["level"])]
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(0, 96)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_button(button)
		button.pressed.connect(func() -> void:
			_open_hero = picked
			_show("profile")
		)
		column.add_child(button)
	column.add_child(_nav_button("formation", "Отряд"))
	column.add_child(_nav_button("preview", "3D в бою"))


func _card(title: String, text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_box())
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 28)
	heading.add_theme_color_override("font_color", Color("f4efe4"))
	column.add_child(heading)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_color_override("font_color", Color("c5cdd8"))
	column.add_child(body)
	return panel


func _formation() -> void:
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 14)
	_mount(column)
	column.add_child(_center_label("Фронт, ближе к врагу"))
	var front := HBoxContainer.new()
	front.alignment = BoxContainer.ALIGNMENT_CENTER
	front.add_theme_constant_override("separation", 12)
	column.add_child(front)
	front.add_child(_slot_button(0))
	front.add_child(_slot_button(1))
	column.add_child(_center_label("Тыл"))
	var back := HBoxContainer.new()
	back.alignment = BoxContainer.ALIGNMENT_CENTER
	back.add_theme_constant_override("separation", 12)
	column.add_child(back)
	back.add_child(_slot_button(2))
	back.add_child(_slot_button(3))
	back.add_child(_slot_button(4))
	var hint := _formation_hint()
	if hint != "":
		column.add_child(_center_label(hint))


func _formation_hint() -> String:
	var tanks := 0
	var front_tanks := 0
	for index in 5:
		var row: Dictionary = Roster.combat(str(Roster.slots[index]))
		if str(row["role"]) != "tank":
			continue
		tanks += 1
		if index < 2:
			front_tanks += 1
	if tanks > 0 and front_tanks == 0:
		return "Танков лучше поставить ближе к врагу."
	return ""


func _before_battle() -> void:
	var column := _scroll_column()
	var stage := maxi(1, Roster.stage)
	var roles := ["Танк", "Воин", "Стрелок", "Маг", "Целитель"]
	var line := ["Ближе к тебе", "Ближе к тебе", "Дальше", "Дальше", "Дальше"]
	column.add_child(_center_label("Враги стадии %d" % stage))
	for index in 5:
		column.add_child(_card(roles[index], "Жрец. %s. %d HP, удар %d." % [line[index], 40 * stage, 6 * stage]))
	column.add_child(_text_button("В бой", func() -> void:
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
	))


func _center_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _slot_button(index: int) -> Button:
	var button := Button.new()
	var row: Dictionary = Roster.combat(str(Roster.slots[index]))
	button.text = str(row["name"])
	button.custom_minimum_size = Vector2(150, 88)
	_style_button(button)
	button.pressed.connect(func() -> void:
		Roster.cycle_slot(index)
		_show("formation")
	)
	return button


func _more() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mount(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	for page in ["idle", "mail", "chats", "shop", "vip", "inventory", "settings", "quests", "guild", "dungeons", "preview", "campaign"]:
		column.add_child(_nav_button(page, PAGES[page][0]))


func _action(text: String, action: Callable) -> void:
	var column := VBoxContainer.new()
	_mount(column)
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 72)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_style_button(button)
	button.pressed.connect(action)
	column.add_child(button)


func _profile() -> void:
	var row: Dictionary = Roster.combat(_open_hero)
	var column := _scroll_column()
	var role := "танк, подходит к врагу"
	if str(row["role"]) == "ranger":
		role = "стрелок, стоит на месте"
	elif str(row["role"]) == "healer":
		role = "целитель"
	column.add_child(_card("Имя", str(row["name"])))
	column.add_child(_card("Роль", role))
	column.add_child(_card("Уровень", str(int(row["level"]))))
	column.add_child(_card("Здоровье", str(int(row["hp"]))))
	column.add_child(_card("Атака", str(int(row["atk"]))))
	column.add_child(_card("Защита", str(int(row["def"]))))
	column.add_child(_card("Повышение", "Повысить нельзя. Это сделает сервер."))
	column.add_child(_center_label("Снаряжение"))
	for slot_name in ["Оружие", "Шлем", "Доспех", "Сапоги", "Кольцо", "Амулет", "Артефакт"]:
		column.add_child(_card(slot_name, "Пусто. Надеть нельзя."))
	column.add_child(_text_button("3D в бою", func() -> void:
		get_tree().change_scene_to_file("res://scenes/battle.tscn")
	))


func _shop() -> void:
	var column := _scroll_column()
	column.add_child(_center_label("Донат"))
	for pack in ["Малый набор", "Средний набор", "Большой набор"]:
		column.add_child(_card(pack, "Кнопки оплаты нет. Деньги не списываются, награда не выдаётся."))
	column.add_child(_center_label("Лавка"))
	column.add_child(_card("Золото и снаряжение", "Витрина пустая. Купить нельзя."))


func _vip() -> void:
	var column := _scroll_column()
	column.add_child(_card("Сейчас VIP %d" % Roster.vip, "Телефон сам уровень не поднимает. Оплаты нет."))
	column.add_child(_card("VIP 0", "В бою только x1. Это значение по умолчанию."))
	column.add_child(_card("VIP 1", "Открывает x2."))
	column.add_child(_card("VIP 4", "Открывает x4."))
	column.add_child(_card("VIP 7", "Открывает симуляцию: бой просчитывается сразу, без просмотра."))
	column.add_child(_text_button("Открыть оплату", func() -> void:
		_body.text = "Оплаты нет. VIP остаётся %d, ничего не списано и не выдано." % Roster.vip
	))


func _idle() -> void:
	var column := _scroll_column()
	column.add_child(_card("Простой", "На сервере золото копится до 8 часов. Телефон это время не считает и сервер не вызывает."))
	column.add_child(_card("Быстрый сбор", "На сервере кнопка сразу забирает накопленное. Здесь она ничего не даёт."))
	column.add_child(_text_button("Собрать", func() -> void:
		_body.text = "Не собрано. Золото не выдано."
	))


func _mail() -> void:
	var column := _scroll_column()
	column.add_child(_card("Входящие", "Писем нет."))
	column.add_child(_text_button("Забрать вложения", func() -> void:
		_body.text = "Забирать нечего. Награда не выдана."
	))


func _chats() -> void:
	var column := _scroll_column()
	column.add_child(_nav_button("chat_server", "Чат сервера"))
	column.add_child(_nav_button("chat_guild", "Чат гильдии"))
	column.add_child(_nav_button("chat_pm", "Личные сообщения"))


func _chat(channel: String) -> void:
	var column := _scroll_column()
	column.add_child(_card("Лента", "Сообщений нет."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	var line := LineEdit.new()
	line.placeholder_text = "Сообщение"
	line.custom_minimum_size = Vector2(0, 64)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(line)
	row.add_child(_text_button("Отправить", func() -> void:
		line.text = ""
		_body.text = "Не отправлено. %s не подключён." % channel
	))


func _settings() -> void:
	var column := _scroll_column()
	column.add_child(_card("Аккаунт", "Гость не создавался. Сервер не вызывался. Почта восстановления на сервере отвечает 501."))
	column.add_child(_card("Язык", "Русский. Других языков в клиенте нет."))
	column.add_child(_card("Звук", "Звука в игре нет, переключать нечего."))
	column.add_child(_card("Бой", "Считается на телефоне из отряда. Награда не выдаётся."))
	column.add_child(_card("Версия", "0.1.11, подпись debug, не для магазина."))


func _inventory() -> void:
	var column := _scroll_column()
	for slot_name in ["Оружие", "Шлем", "Доспех", "Сапоги", "Кольцо", "Амулет", "Артефакт"]:
		column.add_child(_card(slot_name, "Пусто."))


func _quests() -> void:
	var column := _scroll_column()
	column.add_child(_card("Ежедневные", "Пусто. Награды нет."))
	column.add_child(_card("Недельные", "Пусто. Награды нет."))


func _summon() -> void:
	var column := _scroll_column()
	column.add_child(_card("Круг призыва", "На сервере это стоит 50 золота. Здесь кнопка сервер не вызывает."))
	column.add_child(_text_button("Призвать", func() -> void:
		_body.text = "Не вызвано. Герой не добавлен, золото не списано."
	))


func _closed() -> void:
	var column := _scroll_column()
	column.add_child(_card("Закрыто", "Раздел есть на экране. Совместной игры и отдельных боёв нет."))


func _scroll_column() -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mount(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	return column


func _text_button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 64)
	_style_button(button)
	button.pressed.connect(action)
	return button


func _chip(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color("f4efe4"))
	label.add_theme_font_size_override("font_size", 16)
	return label


func _panel_box() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("243044")
	box.border_color = Color("3d4a5c")
	box.set_border_width_all(1)
	box.set_corner_radius_all(12)
	box.content_margin_left = 14
	box.content_margin_top = 10
	box.content_margin_right = 14
	box.content_margin_bottom = 10
	return box


func _style_button(button: Button) -> void:
	var normal := _panel_box()
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color("314158")
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("1a2433")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", pressed)
	button.add_theme_color_override("font_color", Color("f4efe4"))
	button.add_theme_color_override("font_disabled_color", Color("8d96a3"))
