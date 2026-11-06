extends Control

const PAGES := [
	["city", "Город", "Рисунок-заглушка. Финального арта города нет."],
	["campaign", "Кампания", "Бой считается на телефоне из отряда. Золото стадии не начисляется: сервер с телефона не вызывается."],
	["heroes", "Герои", "Мечник и жрец уже лежат файлами. Прокачка, редкость и экипировка на этом экране не работают."],
	["preview", "3D-просмотр", "Бой подставляет swordsman.glb и priest.glb. В редакторе Godot импорт ещё не открывали, поэтому масштаб мог остаться сантиметровым."],
	["formation", "Отряд", "Пять мест: два спереди, три сзади. Выбор сохраняется на этом телефоне. Бой считается из этих слотов. На сервер не отправляется и золото не даёт."],
	["inventory", "Инвентарь", "Шесть слотов и артефакт ещё не работают."],
	["summon", "Призыв", "Сервер крутит призыв за своё золото. Этот экран кнопку сервера не вызывает, поэтому ничего не выдаёт."],
	["arena", "Арена", "Это бой отряда против жрецов первой стадии, не PvP и не рейтинг."],
	["guild", "Гильдия", "Раздел есть. Совместной игры нет."],
	["dungeons", "Подземелья", "Раздел есть. Боёв подземелья нет."],
	["shop", "Магазин", "Витрина-заглушка. Покупок нет."],
	["quests", "Задания", "Список пуст. Наград нет."],
	["settings", "Настройки", "Гостевой вход на сервере есть, но аккаунты пока только в памяти процесса и пропадают при перезапуске."],
]

var _title: Label
var _body: RichTextLabel
var _page := "city"
var _slots: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("1c2430")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_title = Label.new()
	_title.position = Vector2(28, 28)
	_title.size = Vector2(660, 64)
	_title.add_theme_font_size_override("font_size", 36)
	add_child(_title)
	_body = RichTextLabel.new()
	_body.position = Vector2(28, 100)
	_body.size = Vector2(664, 980)
	_body.bbcode_enabled = true
	_body.scroll_active = true
	add_child(_body)
	_bar()
	_show("city")


func _bar() -> void:
	var names := [["city", "Город"], ["heroes", "Герои"], ["arena", "Бой"], ["summon", "Призыв"], ["more", "Ещё"]]
	var x := 12.0
	for item in names:
		var button := Button.new()
		button.text = item[1]
		button.position = Vector2(x, 1188)
		button.size = Vector2(136, 72)
		var page := str(item[0])
		button.pressed.connect(func() -> void:
			if page == "more":
				_show_more()
			elif page == "arena":
				get_tree().change_scene_to_file("res://scenes/battle.tscn")
			else:
				_show(page)
		)
		add_child(button)
		x += 142.0


func _show(page: String) -> void:
	_page = page
	var found: Array = []
	for item in PAGES:
		if item[0] == page:
			found = item
			break
	_title.text = found[1]
	_body.clear()
	_body.append_text(found[2] + "\n\n")
	_clear_extra()
	if page == "city":
		_city_buildings()
	elif page == "campaign":
		_add_action("Тестовый бой", func() -> void:
			get_tree().change_scene_to_file("res://scenes/battle.tscn")
		)
	elif page == "heroes":
		_body.append_text("Мечник, слоты ближнего боя. Жрец, дальние слоты. Редкость не показана на экране.\n")
		_add_action("3D-просмотр", func() -> void: _show("preview"))
	elif page == "formation":
		_formation()
	elif page == "settings":
		_body.append_text("Почта для восстановления не подключена. Ручка отвечает 501.\n")


func _city_buildings() -> void:
	var buildings := [
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
	]
	var column := 0
	var row := 0
	for item in buildings:
		var button := Button.new()
		button.text = item[1]
		button.position = Vector2(28 + column * 220, 280 + row * 88)
		button.size = Vector2(200, 72)
		var page := str(item[0])
		button.pressed.connect(func() -> void:
			if page == "arena":
				get_tree().change_scene_to_file("res://scenes/battle.tscn")
			else:
				_show(page)
		)
		button.set_meta("shell_extra", true)
		add_child(button)
		column += 1
		if column == 3:
			column = 0
			row += 1


func _formation() -> void:
	var titles := ["Фронт 1", "Фронт 2", "Тыл 1", "Тыл 2", "Тыл 3"]
	for i in titles.size():
		var button := Button.new()
		button.text = "%s: %s" % [titles[i], Roster.slots[i]]
		button.position = Vector2(28, 430 + i * 78)
		button.size = Vector2(420, 68)
		var index := i
		button.pressed.connect(func() -> void:
			var next := "priest" if str(Roster.slots[index]) == "swordsman" else "swordsman"
			Roster.set_slot(index, next)
			_show("formation")
		)
		button.set_meta("shell_extra", true)
		add_child(button)
		_slots.append(button)
	_body.append_text("Нажатие меняет мечника и жреца. Слева в бою стоит этот отряд.\n")


func _show_more() -> void:
	_title.text = "Разделы"
	_body.clear()
	_body.append_text("Неготовые разделы открываются и честно пишут, что механики нет.\n")
	_clear_extra()
	var names := ["guild", "dungeons", "shop", "quests", "inventory", "settings", "preview"]
	var y := 280
	for page in names:
		for item in PAGES:
			if item[0] != page:
				continue
			var button := Button.new()
			button.text = item[1]
			button.position = Vector2(28, y)
			button.size = Vector2(320, 64)
			var target: String = str(page)
			button.pressed.connect(func() -> void: _show(target))
			button.set_meta("shell_extra", true)
			add_child(button)
			y += 74


func _add_action(text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.position = Vector2(28, 430)
	button.size = Vector2(320, 72)
	button.pressed.connect(action)
	button.set_meta("shell_extra", true)
	add_child(button)


func _clear_extra() -> void:
	for child in get_children():
		if child.has_meta("shell_extra"):
			child.queue_free()
	_slots.clear()
