extends Control

const PAGES := {
	"city": ["Город", "Рисунок-заглушка. Финального арта города нет."],
	"campaign": ["Кампания", "Бой считается на телефоне из отряда. Золото стадии не начисляется: сервер с телефона не вызывается."],
	"heroes": ["Герои", "Карточки двух моделей. Прокачка, редкость и экипировка не работают."],
	"preview": ["3D-просмотр", "Отдельной витрины нет. Трёхмерные модели видны в бою."],
	"formation": ["Отряд", "Два спереди, три сзади. Выбор хранится на телефоне и меняет бой. На сервер не уходит."],
	"inventory": ["Инвентарь", "Шесть слотов и артефакт ещё не работают."],
	"summon": ["Призыв", "Сервер умеет крутить призыв за своё золото. Этот экран его не вызывает и ничего не выдаёт."],
	"arena": ["Арена", "Это бой отряда против жрецов первой стадии, не PvP и не рейтинг."],
	"guild": ["Гильдия", "Раздел есть. Совместной игры нет."],
	"dungeons": ["Подземелья", "Раздел есть. Боёв подземелья нет."],
	"shop": ["Магазин", "Витрина-заглушка. Покупок нет."],
	"quests": ["Задания", "Список пуст. Наград нет."],
	"settings": ["Настройки", "Гостевой вход на сервере есть. Аккаунты живут в памяти процесса и пропадают при перезапуске. Почта восстановления отвечает 501."],
	"more": ["Разделы", "Неготовые разделы открываются и пишут, чего в них нет."],
}

var _margin: MarginContainer
var _title: Label
var _body: Label
var _host: Control
var _bar_buttons: Array[Button] = []
var _page := "city"


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
	column.add_child(_title)
	_body = Label.new()
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	_clear_host()
	_mark_bar()
	if page == "city":
		_city()
	elif page == "heroes":
		_heroes()
	elif page == "formation":
		_formation()
	elif page == "more":
		_more()
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
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_mount(column)
	var art := ColorRect.new()
	art.color = Color("243044")
	art.custom_minimum_size = Vector2(0, 180)
	art.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(art)
	var art_label := Label.new()
	art_label.text = "Место рисунка города"
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.add_child(art_label)
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
		["quests", "Задания"],
		["settings", "Настройки"],
	]:
		grid.add_child(_nav_button(item[0], item[1]))


func _nav_button(page: String, text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
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
	column.add_child(_card("Мечник", "Ближний бой. В расчёте это танк: 120 HP, он подходит к врагу."))
	column.add_child(_card("Жрец", "Дальний бой. В расчёте это стрелок: 90 HP, стоит на месте."))
	column.add_child(_nav_button("preview", "3D в бою"))


func _card(title: String, text: String) -> PanelContainer:
	var panel := PanelContainer.new()
	var column := VBoxContainer.new()
	panel.add_child(column)
	var heading := Label.new()
	heading.text = title
	heading.add_theme_font_size_override("font_size", 28)
	column.add_child(heading)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	var model := str(Roster.slots[index])
	button.text = "Мечник" if model == "swordsman" else "Жрец"
	button.custom_minimum_size = Vector2(150, 88)
	button.pressed.connect(func() -> void:
		var next := "priest" if str(Roster.slots[index]) == "swordsman" else "swordsman"
		Roster.set_slot(index, next)
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
	for page in ["guild", "dungeons", "shop", "quests", "inventory", "settings", "preview", "campaign"]:
		column.add_child(_nav_button(page, PAGES[page][0]))


func _action(text: String, action: Callable) -> void:
	var column := VBoxContainer.new()
	_mount(column)
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(240, 72)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.pressed.connect(action)
	column.add_child(button)
