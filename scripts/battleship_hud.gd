extends CanvasLayer

signal replay_pressed
signal restart_pressed
signal subtitle_toggled(enabled: bool)
signal vocab_started
signal vocab_hear_pressed

const SHIP_ICON_PATH := "res://assets/kenney_pirate-pack/PNG/Default size/Ships/ship (1).png"

var root_control: Control
var panel: PanelContainer
var status_label: Label
var prompt_label: Label
var hull_label: Label
var ships_label: Label
var accuracy_label: Label
var compass_label: Label
var voice_label: Label
var replay_button: Button
var restart_button: Button
var subtitle_check: CheckButton
var hull_icons: Array = []
var prompt_text := ""
var subtitle_visible := false

var vocab_overlay: Control
var vocab_words: Label
var result_overlay: Control
var result_title: Label
var result_stars: Label
var result_accuracy: Label


func _ready() -> void:
	layer = 10
	_build_main_panel()
	_build_vocab_overlay()
	_build_result_overlay()


func _build_main_panel() -> void:
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root_control)

	panel = PanelContainer.new()
	panel.position = Vector2(1480, 80)
	panel.size = Vector2(400, 960)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_panel(panel, Color(0.035, 0.08, 0.14, 0.93), Color(0.85, 0.65, 0.25, 0.85))
	root_control.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	var title := _make_label("Pirate Listening", 30, Color(0.98, 0.82, 0.40))
	vbox.add_child(title)

	var level_label := _make_label("Level 1: Where is it?", 18, Color(0.78, 0.88, 1.0))
	vbox.add_child(level_label)

	vbox.add_child(HSeparator.new())

	status_label = _make_label("Loading...", 20, Color(0.92, 0.97, 1.0))
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(0, 64)
	vbox.add_child(status_label)

	prompt_label = _make_label("", 21, Color(1.0, 0.94, 0.72))
	prompt_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt_label.custom_minimum_size = Vector2(0, 80)
	prompt_label.visible = false
	vbox.add_child(prompt_label)

	compass_label = _make_label("N = up    E = right    S = down    W = left", 15, Color(0.62, 0.80, 0.92))
	compass_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(compass_label)

	vbox.add_child(HSeparator.new())

	hull_label = _make_label("Your hull: 3 / 3", 18, Color(0.92, 0.97, 1.0))
	vbox.add_child(hull_label)

	var hull_box := HBoxContainer.new()
	hull_box.add_theme_constant_override("separation", 8)
	vbox.add_child(hull_box)
	var ship_texture := load(SHIP_ICON_PATH) as Texture2D
	for index in range(3):
		var icon := TextureRect.new()
		icon.texture = ship_texture
		icon.custom_minimum_size = Vector2(54, 86)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		hull_box.add_child(icon)
		hull_icons.append(icon)

	ships_label = _make_label("Enemy ships: 3", 18, Color(0.92, 0.97, 1.0))
	vbox.add_child(ships_label)

	accuracy_label = _make_label("Accuracy: 0%", 18, Color(0.92, 0.97, 1.0))
	vbox.add_child(accuracy_label)

	voice_label = _make_label("Voice: checking...", 13, Color(0.60, 0.72, 0.82))
	voice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(voice_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	replay_button = _make_button("Hear again")
	replay_button.pressed.connect(_on_replay_pressed)
	vbox.add_child(replay_button)

	var subtitle_row := HBoxContainer.new()
	subtitle_row.add_theme_constant_override("separation", 8)
	vbox.add_child(subtitle_row)
	subtitle_check = CheckButton.new()
	subtitle_check.text = "Show prompt text"
	subtitle_check.add_theme_font_size_override("font_size", 16)
	subtitle_check.toggled.connect(_on_subtitle_toggled)
	subtitle_row.add_child(subtitle_check)

	restart_button = _make_button("New round")
	restart_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(restart_button)


func _build_vocab_overlay() -> void:
	vocab_overlay = Control.new()
	vocab_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vocab_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	vocab_overlay.visible = false
	root_control.add_child(vocab_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.03, 0.06, 0.72)
	vocab_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vocab_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(820, 560)
	_style_panel(card, Color(0.04, 0.09, 0.16, 0.98), Color(0.85, 0.65, 0.25, 0.95))
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	vbox.add_child(_make_label("Words to know", 32, Color(0.98, 0.82, 0.40)))
	vbox.add_child(_make_label("Listen and repeat before you start.", 18, Color(0.78, 0.88, 1.0)))

	vocab_words = _make_label("", 22, Color(0.94, 0.97, 1.0))
	vocab_words.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vocab_words.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(vocab_words)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	vbox.add_child(buttons)

	var hear_button := _make_button("Hear the words")
	hear_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hear_button.pressed.connect(_on_vocab_hear_pressed)
	buttons.add_child(hear_button)

	var start_button := _make_button("Start level 1")
	start_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	start_button.pressed.connect(_on_vocab_start_pressed)
	buttons.add_child(start_button)


func _build_result_overlay() -> void:
	result_overlay = Control.new()
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	result_overlay.visible = false
	root_control.add_child(result_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.01, 0.03, 0.06, 0.72)
	result_overlay.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(680, 380)
	_style_panel(card, Color(0.04, 0.09, 0.16, 0.98), Color(0.85, 0.65, 0.25, 0.95))
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	result_title = _make_label("", 32, Color(0.98, 0.82, 0.40))
	result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(result_title)

	result_stars = _make_label("", 28, Color(0.95, 0.96, 1.0))
	result_stars.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(result_stars)

	result_accuracy = _make_label("", 20, Color(0.78, 0.88, 1.0))
	result_accuracy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(result_accuracy)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	var again_button := _make_button("Play again")
	again_button.pressed.connect(_on_restart_pressed)
	vbox.add_child(again_button)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 19)
	return button


func _style_panel(target: PanelContainer, background: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	target.add_theme_stylebox_override("panel", style)


func set_status(text: String) -> void:
	status_label.text = text


func set_prompt(text: String) -> void:
	prompt_text = text
	prompt_label.text = text
	prompt_label.visible = subtitle_visible and not text.is_empty()


func set_subtitle_visible(enabled: bool) -> void:
	subtitle_visible = enabled
	if subtitle_check.button_pressed != enabled:
		subtitle_check.set_pressed_no_signal(enabled)
	prompt_label.visible = enabled and not prompt_text.is_empty()


func force_subtitle_visible() -> void:
	set_subtitle_visible(true)


func set_hulls(current: int, total: int) -> void:
	hull_label.text = "Your hull: %d / %d" % [current, total]
	for index in range(hull_icons.size()):
		var icon: TextureRect = hull_icons[index]
		if index < current:
			icon.modulate = Color(1, 1, 1, 1)
		else:
			icon.modulate = Color(0.28, 0.30, 0.33, 0.35)


func set_ships_remaining(count: int) -> void:
	ships_label.text = "Enemy ships: %d" % count


func set_accuracy(value: float) -> void:
	accuracy_label.text = "Accuracy: %d%%" % int(round(value * 100.0))


func set_voice(name: String, is_available: bool) -> void:
	if is_available:
		voice_label.text = "Voice: %s" % name
		voice_label.add_theme_color_override("font_color", Color(0.60, 0.82, 0.70))
	else:
		voice_label.text = "Audio unavailable. Text is shown."
		voice_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.45))


func show_vocab(words: Array) -> void:
	var text := ""
	for item in words:
		text += "%s  -  %s\n" % [String(item.get("word", "")), String(item.get("meaning", ""))]
	vocab_words.text = text.strip_edges()
	vocab_overlay.visible = true
	result_overlay.visible = false


func hide_vocab() -> void:
	vocab_overlay.visible = false


func show_result(won: bool, stars: int, accuracy: float, hulls_lost: int) -> void:
	if won:
		result_title.text = "You sank the fleet!"
	else:
		result_title.text = "Your ship was sunk."
	result_stars.text = "Stars: %d / 3" % stars
	result_accuracy.text = "Accuracy: %d%%    Hulls lost: %d" % [
		int(round(accuracy * 100.0)),
		hulls_lost
	]
	result_overlay.visible = true


func hide_result() -> void:
	result_overlay.visible = false


func _on_replay_pressed() -> void:
	replay_pressed.emit()


func _on_restart_pressed() -> void:
	restart_pressed.emit()


func _on_subtitle_toggled(enabled: bool) -> void:
	subtitle_visible = enabled
	prompt_label.visible = enabled and not prompt_text.is_empty()
	subtitle_toggled.emit(enabled)


func _on_vocab_hear_pressed() -> void:
	vocab_hear_pressed.emit()


func _on_vocab_start_pressed() -> void:
	vocab_overlay.visible = false
	vocab_started.emit()
