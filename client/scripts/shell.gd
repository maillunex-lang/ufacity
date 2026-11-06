extends Control

const PAGES := {
	"city": ["Город", "Рисунок-заглушка. Финального арта города нет."],
	"campaign": ["Кампания", "Бой считается на телефоне из отряда. Золото стадии не начисляется: сервер с телефона не вызывается."],
	"heroes": ["Герои", "В отряде только те, кто уже есть. Повышение уровня серверное, здесь золото не тратится и уровень не растёт."],
	"preview": ["3D-просмотр", "Отдельной витрины нет. Трёхмерные модели видны в бою."],
	"formation": ["Отряд", "Два спереди, три сзади. Слот хранит id героя и переключает только полученных. На сервер не уходит."],
	"inventory": ["Инвентарь", "Шесть слотов и артефакт ещё не работают."],
	"summon": ["Призыв", "На сервере призыв стоит 50 золота. Этот экран сервер не вызывает и никого не добавляет."],
	"arena": ["Арена", "Это бой отряда против жрецов первой стадии, не PvP и не рейтинг."],
	"guild": ["Гильдия", "Раздел есть. Совместной игры нет."],
	"dungeons": ["Подземелья", "Раздел есть. Боёв подземелья нет."],
	"shop": ["Магазин", "Лавка и донат только нарисованы. Оплаты нет, ничего не списывается и не выдаётся."],
	"vip": ["VIP", "Скорость боя зависит от VIP. Повысить его с телефона нельзя."],
	"profile": ["Профиль", "Карточка героя. Снаряжение пустое, уровень не растёт."],
	"quests": ["Задания", "Список пуст. Наград нет."],
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
var _chip_stage: Label
var _chip_gold: Label
var _chip_vip: Button


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
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	column.add_child(chips)
	_chip_stage = _chip("Стадия 1")
	_chip_gold = _chip("Золото: нет")
	chips.add_child(_chip_stage)
	chips.add_child(_chip_gold)
	var vip := Button.new()
	_chip_vip = vip
	vip.text = "VIP 0"
	vip.custom_minimum_size = Vector2(96, 40)
	_style_button(vip)
	vip.pressed.connect(func() -> void: _show("vip"))
	chips.add_child(vip)
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
	for item in [["city", "Город"], ["heroes", "Герои"], ["arena", "Бой"], ["summon", "Призыв"], ["more", "Ещё"]]:
		var button := Button.new()
		button.text = item[1]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 64)
		_style_button(button)
		button.set_meta("page", item[0])
		var page := str(item[0])
		button.pressed.connect(func() -> void:
			if page == "more":
				_show("more")
			elif page == "arena":
				get_tree().change_scene_to_file("res://scenes/battle.tscn")
			else:
				_show(page)
		)
		bar.add_child(button)
		_bar_buttons.append(button)


func _show(page: String) -> void:
	_page = page
	var info: Array = PAGES[page]
	_title.text = info[0]
	_body.text = info[1]
	_chip_stage.text = "Стадия %d" % Roster.stage
	_chip_gold.text = "Золото: нет"
	_chip_vip.text = "VIP %d" % Roster.vip
	if page == "city":
		_body.text += "\nСтадия %d. Золото не копится." % Roster.stage
	elif page == "campaign":
		_body.text = "Стадия %d. Враги: жрецы, %d HP и удар %d. Победа откроет следующую, поражение оставит эту. Золото не копится." % [Roster.stage, 40 * Roster.stage, 6 * Roster.stage]
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
	elif page == "campaign" or page == "arena":
		_action("В бой", func() -> void:
			get_tree().change_scene_to_file("res://scenes/battle.tscn")
		)
	elif page == "preview":
		_action("Открыть бой", func() -> void:
			get_tree().change_scene_to_file("res://scenes/battle.tscn")
		)


func _mark_bar() -> void:
	for button in _bar_buttons:
		button.disabled = str(button.get_meta("page")) == _page


func _clear_host() -> void:
	for child in _host.get_children():
		_host.remove_child(child)
		child.free()


func _mount(node: Control) -> void:
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	_host.add_child(node)


func _city() -> void:
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_mount(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 12)
	scroll.add_child(column)
	var art := ColorRect.new()
	art.color = Color("243044")
	art.custom_minimum_size = Vector2(0, 140)
	column.add_child(art)
	var art_label := Label.new()
	art_label.text = "Место рисунка города"
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(art_label)
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	column.add_child(tools)
	for item in [["idle", "Сбор"], ["mail", "Почта"], ["chats", "Чаты"]]:
		var button := _nav_button(item[0], item[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tools.add_child(button)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	column.add_child(grid)
	for item in [
		["campaign", "Кампания"],
		["heroes", "Герои"],
		["formation", "Отряд"],
		["inventory", "Инвентарь"],
		["summon", "Призыв"],
		["arena", "Арена"],
		["guild", "Гильдия"],
		["dungeons", "Подземелья"],
		["shop", "Магазин"],
		["vip", "VIP"],
		["quests", "Задания"],
		["settings", "Настройки"],
	]:
		grid.add_child(_nav_button(item[0], item[1]))


func _nav_button(page: String, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_style_button(button)
	button.pressed.connect(func() -> void:
		if page == "arena":
			get_tree().change_scene_to_file("res://scenes/battle.tscn")
		else:
			_show(page)
	)
	return button


func _heroes() -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_mount(column)
	for hero_id in Roster.owned_ids():
		var row: Dictionary = Roster.combat(str(hero_id))
		var role := "танк, подходит"
		if str(row["role"]) == "ranger":
			role = "стрелок, стоит"
		elif str(row["role"]) == "healer":
			role = "целитель"
		column.add_child(_card(str(row["name"]), "%s, %s. Уровень %d, копий %d. %d HP, удар %d." % [str(row["rarity"]), role, int(row["level"]), int(row["copies"]), int(row["hp"]), int(row["atk"])]))
		var picked := str(hero_id)
		column.add_child(_text_button("Профиль", func() -> void:
			_open_hero = picked
			_show("profile")
		))
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
	column.add_child(_card(str(row["name"]), "%s. %s.\nУровень %d, копий %d. %d HP, удар %d, защита %d.\nId %s. Уровень не растёт: золото сервера не подключено." % [str(row["rarity"]), role, int(row["level"]), int(row["copies"]), int(row["hp"]), int(row["atk"]), int(row["def"]), str(row["id"])]))
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
