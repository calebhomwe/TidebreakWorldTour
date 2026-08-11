class_name WorldTourScreen
extends Control

## Connect this signal to your real surfing event/level loader.
## Example:
## world_tour.event_requested.connect(GameFlow.start_world_tour_event)
signal event_requested(stop_id: String, target_score: int)

const TourMapScript := preload("res://scripts/world_tour/tour_map.gd")
const SAVE_VERSION := 1

const COLOR_BACKGROUND := Color(0.012, 0.030, 0.041)
const COLOR_PANEL := Color(0.025, 0.066, 0.086, 0.94)
const COLOR_PANEL_ALT := Color(0.038, 0.095, 0.116, 0.94)
const COLOR_TEAL := Color(0.06, 0.84, 0.89)
const COLOR_GOLD := Color(0.96, 0.69, 0.15)
const COLOR_TEXT := Color(0.94, 0.97, 0.98)
const COLOR_MUTED := Color(0.59, 0.68, 0.72)
const COLOR_LOCKED := Color(0.35, 0.42, 0.45)

var stops: Array = []
var state: Dictionary = {}
var selected_stop_id: String = "pipeline"

var tour_map: TourMap
var stop_cards_row: HBoxContainer
var ranking_list: VBoxContainer
var stop_detail_title: Label
var stop_detail_meta: Label
var stop_detail_description: Label
var stop_detail_requirements: Label
var stop_detail_reward: Label
var start_button: Button
var progress_bar: ProgressBar
var progress_label: Label
var rank_value_label: Label
var points_value_label: Label
var xp_value_label: Label
var sponsor_name_label: Label
var sponsor_progress_bar: ProgressBar
var result_overlay: Control
var result_dialog_title: Label
var selected_card_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stops = _create_tour_stops()
	state = TourSave.load_state(_default_state())
	selected_stop_id = str(state.get("current_stop", "pipeline"))

	_build_ui()
	_refresh_all()
	call_deferred("_focus_initial_control")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and result_overlay.visible:
		_close_result_dialog()
		get_viewport().set_input_as_handled()


func _create_tour_stops() -> Array:
	return [
		TourStop.create(
			"pipeline", "PIPELINE", "HAWAII", "JAN 12 – JAN 23",
			Vector2(0.08, 0.34), 22000, 1200, 1600, "6–8 FT", "PERFECT",
			"Open the season in heavy, hollow surf. Build flow early and commit to the barrel.",
			Color(0.10, 0.88, 0.91)
		),
		TourStop.create(
			"trestles", "TRESTLES", "CALIFORNIA", "FEB 15 – FEB 26",
			Vector2(0.20, 0.19), 28000, 1450, 1900, "3–5 FT", "CLEAN",
			"Fast performance walls reward linked turns, aerial variety, and clean landings.",
			Color(0.25, 0.75, 1.00)
		),
		TourStop.create(
			"snapper", "SNAPPER ROCKS", "AUSTRALIA", "MAR 10 – MAR 21",
			Vector2(0.43, 0.64), 35000, 1750, 2200, "4–6 FT", "FIRING",
			"Use the long point break to maintain a single high-value combo from takeoff to shore.",
			Color(0.15, 0.92, 0.66)
		),
		TourStop.create(
			"jbay", "JEFFREYS BAY", "SOUTH AFRICA", "APR 14 – APR 25",
			Vector2(0.55, 0.27), 43000, 2050, 2600, "5–7 FT", "FAST",
			"Read the racing sections, hold a high line, and convert speed into precision carves.",
			Color(0.36, 0.80, 1.00)
		),
		TourStop.create(
			"teahupoo", "TEAHUPO'O", "TAHITI", "MAY 12 – MAY 23",
			Vector2(0.69, 0.54), 52000, 2450, 3100, "8–12 FT", "CRITICAL",
			"Late drops and deep barrels. Safety matters, but commitment earns the biggest scores.",
			Color(0.78, 0.40, 1.00)
		),
		TourStop.create(
			"cloud9", "CLOUD 9", "PHILIPPINES", "JUN 16 – JUN 27",
			Vector2(0.82, 0.36), 62000, 2850, 3700, "5–8 FT", "EPIC",
			"Mix barrels with explosive aerials in a technical semifinal that rewards versatility.",
			Color(1.00, 0.43, 0.31)
		),
		TourStop.create(
			"finals", "TIDEBREAK FINALS", "FIJI", "JUL 14 – JUL 25",
			Vector2(0.93, 0.62), 78000, 4000, 5500, "8–14 FT", "LEGENDARY",
			"The championship heat. Master every scoring system and claim the World Tour crown.",
			Color(0.96, 0.69, 0.15),
			true
		),
	]


func _default_state() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"xp": 0,
		"tour_points": 0,
		"credits": 2500,
		"completed": [],
		"medals": {},
		"best_scores": {},
		"current_stop": "pipeline",
	}


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var glow := ColorRect.new()
	glow.color = Color(0.02, 0.20, 0.24, 0.23)
	glow.anchor_left = 0.0
	glow.anchor_top = 0.0
	glow.anchor_right = 1.0
	glow.anchor_bottom = 0.42
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var root_margin := MarginContainer.new()
	root_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_margin.add_theme_constant_override("margin_left", 30)
	root_margin.add_theme_constant_override("margin_top", 22)
	root_margin.add_theme_constant_override("margin_right", 30)
	root_margin.add_theme_constant_override("margin_bottom", 22)
	add_child(root_margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 16)
	root_margin.add_child(root_vbox)

	root_vbox.add_child(_build_header())

	var main_row := HBoxContainer.new()
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 16)
	root_vbox.add_child(main_row)

	main_row.add_child(_build_left_panel())

	var center_column := VBoxContainer.new()
	center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_column.add_theme_constant_override("separation", 14)
	main_row.add_child(center_column)

	center_column.add_child(_build_map_panel())
	center_column.add_child(_build_stop_cards())

	main_row.add_child(_build_right_panel())
	root_vbox.add_child(_build_footer())

	_build_result_overlay()


func _build_header() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 74.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.042, 0.055, 0.95), Color(0.10, 0.28, 0.32, 0.8), 1, 10))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	margin.add_child(row)

	var brand := _label("TIDEBREAK", 28, COLOR_TEXT, true)
	brand.custom_minimum_size.x = 255.0
	row.add_child(brand)

	var nav := _label("HOME     SURFER     GEAR     WORLD TOUR     SPONSORS     PROFILE", 15, COLOR_MUTED)
	nav.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(nav)

	var profile_box := VBoxContainer.new()
	profile_box.custom_minimum_size.x = 260.0
	var name_label := _label("KAI LANI  •  RANK 24", 16, COLOR_TEXT, true)
	xp_value_label = _label("0 / 24,000 XP", 13, COLOR_TEAL)
	profile_box.add_child(name_label)
	profile_box.add_child(xp_value_label)
	row.add_child(profile_box)

	var currency := _label("◉  12,650     ★  3,250", 16, COLOR_GOLD, true)
	currency.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(currency)

	return panel


func _build_left_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 310.0
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(0.09, 0.27, 0.32, 0.9), 1, 10))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	column.add_child(_label("CAREER", 13, COLOR_TEAL, true))
	column.add_child(_label("WORLD TOUR", 35, COLOR_TEXT, true))
	column.add_child(_label("SEASON 1  •  ELITE DIVISION", 14, COLOR_GOLD, true))

	var description := _label(
		"Compete across the globe, earn tour points, climb the rankings, and qualify for the TIDEBREAK Finals.",
		14,
		COLOR_MUTED
	)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.y = 78.0
	column.add_child(description)

	column.add_child(_divider())

	column.add_child(_label("YOUR RANK", 12, COLOR_MUTED, true))
	rank_value_label = _label("24TH", 56, COLOR_TEXT, true)
	column.add_child(rank_value_label)
	points_value_label = _label("0 TOUR POINTS", 15, COLOR_TEAL, true)
	column.add_child(points_value_label)

	column.add_child(_divider())
	column.add_child(_label("LEADERBOARD", 13, COLOR_TEXT, true))

	ranking_list = VBoxContainer.new()
	ranking_list.add_theme_constant_override("separation", 7)
	column.add_child(ranking_list)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	var reset_button := _button("RESET DEMO SAVE", false)
	reset_button.pressed.connect(_reset_progress)
	column.add_child(reset_button)

	return panel


func _build_map_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.custom_minimum_size.y = 470.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.018, 0.054, 0.070, 0.96), Color(0.08, 0.30, 0.34, 0.9), 1, 10))

	tour_map = TourMapScript.new()
	tour_map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tour_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tour_map.stop_selected.connect(_select_stop)
	panel.add_child(tour_map)
	return panel


func _build_stop_cards() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 188.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.044, 0.058, 0.96), Color(0.08, 0.25, 0.30, 0.9), 1, 10))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(scroll)

	stop_cards_row = HBoxContainer.new()
	stop_cards_row.add_theme_constant_override("separation", 10)
	stop_cards_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(stop_cards_row)

	for index in range(stops.size()):
		var stop: TourStop = stops[index]
		var card := Button.new()
		card.custom_minimum_size = Vector2(198.0, 150.0)
		card.text = "%02d\n%s\n%s\n%s" % [
			index + 1,
			stop.display_name,
			stop.country,
			stop.date_label
		]
		card.focus_mode = Control.FOCUS_ALL
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		card.pressed.connect(_select_stop.bind(stop.id))
		stop_cards_row.add_child(card)
		selected_card_buttons[stop.id] = card

	return panel


func _build_right_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = 330.0
	panel.add_theme_stylebox_override("panel", _panel_style(COLOR_PANEL, Color(0.09, 0.27, 0.32, 0.9), 1, 10))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)

	var progress_header := HBoxContainer.new()
	progress_header.add_child(_label("SEASON PROGRESS", 13, COLOR_TEXT, true))
	progress_header.add_spacer(false)
	progress_label = _label("0%", 24, COLOR_TEAL, true)
	progress_header.add_child(progress_label)
	column.add_child(progress_header)

	progress_bar = ProgressBar.new()
	progress_bar.custom_minimum_size.y = 12.0
	progress_bar.show_percentage = false
	progress_bar.add_theme_stylebox_override("background", _panel_style(Color(0.08, 0.13, 0.15), Color.TRANSPARENT, 0, 6))
	progress_bar.add_theme_stylebox_override("fill", _panel_style(COLOR_TEAL, Color.TRANSPARENT, 0, 6))
	column.add_child(progress_bar)

	column.add_child(_divider())

	stop_detail_title = _label("PIPELINE", 26, COLOR_TEXT, true)
	column.add_child(stop_detail_title)
	stop_detail_meta = _label("HAWAII  •  6–8 FT  •  PERFECT", 13, COLOR_GOLD, true)
	column.add_child(stop_detail_meta)

	stop_detail_description = _label("", 14, COLOR_MUTED)
	stop_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stop_detail_description.custom_minimum_size.y = 100.0
	column.add_child(stop_detail_description)

	column.add_child(_label("EVENT TARGET", 12, COLOR_MUTED, true))
	stop_detail_requirements = _label("", 16, COLOR_TEXT, true)
	column.add_child(stop_detail_requirements)

	column.add_child(_label("REWARDS", 12, COLOR_MUTED, true))
	stop_detail_reward = _label("", 15, COLOR_TEAL, true)
	column.add_child(stop_detail_reward)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	start_button = _button("START EVENT", true)
	start_button.pressed.connect(_start_selected_event)
	column.add_child(start_button)

	var test_note := _label(
		"Demo mode: choose a result after starting. In your game, connect event_requested to the real surf level.",
		12,
		COLOR_MUTED
	)
	test_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(test_note)

	return panel


func _build_footer() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.y = 88.0
	panel.add_theme_stylebox_override("panel", _panel_style(Color(0.015, 0.043, 0.055, 0.97), Color(0.08, 0.24, 0.28, 0.9), 1, 10))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 20)
	margin.add_theme_constant_override("margin_right", 20)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	margin.add_child(row)

	var sponsor_column := VBoxContainer.new()
	sponsor_column.custom_minimum_size.x = 280.0
	sponsor_column.add_child(_label("SPONSOR PROGRESSION", 12, COLOR_MUTED, true))
	sponsor_name_label = _label("TIDEBREAK CORE", 18, COLOR_TEXT, true)
	sponsor_column.add_child(sponsor_name_label)
	row.add_child(sponsor_column)

	sponsor_progress_bar = ProgressBar.new()
	sponsor_progress_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sponsor_progress_bar.custom_minimum_size.y = 14.0
	sponsor_progress_bar.show_percentage = false
	sponsor_progress_bar.add_theme_stylebox_override("background", _panel_style(Color(0.08, 0.13, 0.15), Color.TRANSPARENT, 0, 7))
	sponsor_progress_bar.add_theme_stylebox_override("fill", _panel_style(COLOR_GOLD, Color.TRANSPARENT, 0, 7))
	row.add_child(sponsor_progress_bar)

	var controls := _label("D-PAD / MOUSE  SELECT     A / ENTER  CONFIRM     B / ESC  BACK", 13, COLOR_MUTED)
	controls.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(controls)

	return panel


func _build_result_overlay() -> void:
	result_overlay = Control.new()
	result_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.visible = false
	result_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(result_overlay)

	var dimmer := ColorRect.new()
	dimmer.color = Color(0.0, 0.0, 0.0, 0.76)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(dimmer)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	result_overlay.add_child(center)

	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(620.0, 390.0)
	dialog.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.075, 0.095, 0.99), COLOR_TEAL, 2, 14))
	center.add_child(dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	dialog.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)

	column.add_child(_label("EVENT TEST HARNESS", 12, COLOR_TEAL, true))
	result_dialog_title = _label("PIPELINE", 30, COLOR_TEXT, true)
	column.add_child(result_dialog_title)

	var helper := _label(
		"Your real surf scene should report the final heat score back to complete_event(stop_id, score). Use these buttons to test progression now.",
		14,
		COLOR_MUTED
	)
	helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	helper.custom_minimum_size.y = 68.0
	column.add_child(helper)

	var result_row := HBoxContainer.new()
	result_row.add_theme_constant_override("separation", 12)
	column.add_child(result_row)

	var bronze := _button("BRONZE\n65% SCORE", false)
	bronze.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bronze.pressed.connect(_simulate_result.bind(0.65))
	result_row.add_child(bronze)

	var silver := _button("SILVER\n85% SCORE", false)
	silver.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	silver.pressed.connect(_simulate_result.bind(0.85))
	result_row.add_child(silver)

	var gold := _button("GOLD\n110% SCORE", true)
	gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gold.pressed.connect(_simulate_result.bind(1.10))
	result_row.add_child(gold)

	var fail := _button("WIPEOUT\n40% SCORE", false)
	fail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fail.pressed.connect(_simulate_result.bind(0.40))
	result_row.add_child(fail)

	var close := _button("CANCEL", false)
	close.pressed.connect(_close_result_dialog)
	column.add_child(close)


func _refresh_all() -> void:
	if not _has_stop(selected_stop_id):
		selected_stop_id = "pipeline"

	state["current_stop"] = selected_stop_id
	tour_map.configure(stops, state, selected_stop_id)
	_refresh_stop_cards()
	_refresh_stop_details()
	_refresh_rankings()
	_refresh_progress()
	_refresh_header_and_sponsors()
	TourSave.save_state(state)


func _refresh_stop_cards() -> void:
	for index in range(stops.size()):
		var stop: TourStop = stops[index]
		var button: Button = selected_card_buttons.get(stop.id)
		if not is_instance_valid(button):
			continue

		var unlocked := _is_stop_unlocked(stop.id)
		var completed := _is_stop_completed(stop.id)
		var medal := str(state.get("medals", {}).get(stop.id, ""))
		var status := "LOCKED"
		if completed:
			status = medal.to_upper()
		elif unlocked:
			status = "AVAILABLE"

		button.text = "%02d\n%s\n%s\n%s\n%s" % [
			index + 1,
			stop.display_name,
			stop.country,
			stop.date_label,
			status
		]
		button.disabled = not unlocked

		var border := Color(0.13, 0.30, 0.34)
		if completed:
			border = COLOR_GOLD
		elif unlocked:
			border = COLOR_TEAL

		var normal := _panel_style(Color(0.025, 0.070, 0.088, 0.98), border, 1, 8)
		var selected := _panel_style(Color(0.045, 0.135, 0.155, 0.99), border, 3, 8)
		var disabled := _panel_style(Color(0.02, 0.035, 0.043, 0.95), Color(0.12, 0.16, 0.18), 1, 8)

		button.add_theme_stylebox_override("normal", selected if stop.id == selected_stop_id else normal)
		button.add_theme_stylebox_override("hover", selected)
		button.add_theme_stylebox_override("pressed", selected)
		button.add_theme_stylebox_override("focus", selected)
		button.add_theme_stylebox_override("disabled", disabled)
		button.add_theme_color_override("font_color", COLOR_TEXT)
		button.add_theme_color_override("font_disabled_color", COLOR_LOCKED)
		button.add_theme_font_size_override("font_size", 13)


func _refresh_stop_details() -> void:
	var stop := _get_stop(selected_stop_id)
	if stop == null:
		return

	stop_detail_title.text = stop.display_name
	stop_detail_meta.text = "%s  •  %s  •  %s" % [
		stop.country,
		stop.wave_height,
		stop.condition_label
	]
	stop_detail_description.text = stop.description
	stop_detail_requirements.text = "SCORE %s+" % _format_number(stop.target_score)
	stop_detail_reward.text = "+%s XP     +%s TOUR PTS" % [
		_format_number(stop.xp_reward),
		_format_number(stop.points_reward)
	]

	var unlocked := _is_stop_unlocked(stop.id)
	var completed := _is_stop_completed(stop.id)
	start_button.disabled = not unlocked
	start_button.text = "REPLAY EVENT" if completed else "START EVENT"
	if not unlocked:
		start_button.text = "LOCKED — COMPLETE PREVIOUS STOP"


func _refresh_rankings() -> void:
	for child in ranking_list.get_children():
		child.queue_free()

	var player_points := int(state.get("tour_points", 0))
	var player_rank := _calculate_rank(player_points)
	var entries := [
		{"rank": 1, "name": "J. FLORES", "points": 58200},
		{"rank": 2, "name": "M. TAKAHASHI", "points": 52100},
		{"rank": 3, "name": "E. HARRISON", "points": 48750},
		{"rank": player_rank, "name": "KAI LANI", "points": player_points},
		{"rank": mini(player_rank + 1, 250), "name": "L. FERREIRA", "points": maxi(0, player_points - 250)},
	]

	for entry in entries:
		var row := HBoxContainer.new()
		var is_player := entry["name"] == "KAI LANI"
		var rank_label := _label(str(entry["rank"]), 14, COLOR_TEAL if is_player else COLOR_MUTED, is_player)
		rank_label.custom_minimum_size.x = 32.0
		row.add_child(rank_label)

		var name_label := _label(entry["name"], 14, COLOR_TEXT if is_player else COLOR_MUTED, is_player)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		row.add_child(_label(_format_number(entry["points"]), 14, COLOR_TEAL if is_player else COLOR_MUTED, is_player))
		ranking_list.add_child(row)

	rank_value_label.text = "%d%s" % [player_rank, _ordinal_suffix(player_rank)]
	points_value_label.text = "%s TOUR POINTS" % _format_number(player_points)


func _refresh_progress() -> void:
	var completed_count := state.get("completed", []).size()
	var progress := float(completed_count) / float(stops.size()) * 100.0
	progress_bar.value = progress
	progress_label.text = "%d%%" % roundi(progress)


func _refresh_header_and_sponsors() -> void:
	var xp := int(state.get("xp", 0))
	xp_value_label.text = "%s / 24,000 XP" % _format_number(xp)

	var tiers := [
		{"name": "TIDEBREAK CORE", "min": 0, "max": 6000},
		{"name": "TIDEBREAK RISING", "min": 6000, "max": 14000},
		{"name": "TIDEBREAK PRO", "min": 14000, "max": 24000},
		{"name": "TIDEBREAK ELITE", "min": 24000, "max": 36000},
	]

	var active_tier: Dictionary = tiers[0]
	for tier in tiers:
		if xp >= int(tier["min"]):
			active_tier = tier

	sponsor_name_label.text = active_tier["name"]
	var tier_min := int(active_tier["min"])
	var tier_max := int(active_tier["max"])
	sponsor_progress_bar.min_value = tier_min
	sponsor_progress_bar.max_value = tier_max
	sponsor_progress_bar.value = clampi(xp, tier_min, tier_max)


func _select_stop(stop_id: String) -> void:
	if not _is_stop_unlocked(stop_id):
		return

	selected_stop_id = stop_id
	state["current_stop"] = stop_id
	tour_map.refresh(state, selected_stop_id)
	_refresh_stop_cards()
	_refresh_stop_details()
	TourSave.save_state(state)


func _start_selected_event() -> void:
	var stop := _get_stop(selected_stop_id)
	if stop == null or not _is_stop_unlocked(stop.id):
		return

	event_requested.emit(stop.id, stop.target_score)
	result_dialog_title.text = "%s  •  TARGET %s" % [stop.display_name, _format_number(stop.target_score)]
	result_overlay.visible = true

	var tween := create_tween()
	result_overlay.modulate.a = 0.0
	tween.tween_property(result_overlay, "modulate:a", 1.0, 0.18)

	var first_button := _find_first_enabled_button(result_overlay)
	if first_button != null:
		first_button.grab_focus()


func complete_event(stop_id: String, score: int) -> Dictionary:
	## Call this from your real surf gameplay result screen.
	## Returns a result dictionary for your own presentation layer.
	var stop := _get_stop(stop_id)
	if stop == null:
		return {"success": false, "reason": "unknown_stop"}

	var medal := _medal_for_score(score, stop.target_score)
	var result := {
		"success": medal != "none",
		"stop_id": stop.id,
		"score": score,
		"medal": medal,
		"unlocked_stop": "",
		"xp_earned": 0,
		"points_earned": 0,
	}

	var best_scores: Dictionary = state.get("best_scores", {})
	var previous_best := int(best_scores.get(stop.id, 0))
	best_scores[stop.id] = maxi(previous_best, score)
	state["best_scores"] = best_scores

	if medal == "none":
		TourSave.save_state(state)
		return result

	var medal_multiplier := {
		"bronze": 0.70,
		"silver": 0.88,
		"gold": 1.00,
	}.get(medal, 0.0)

	var previous_medal := str(state.get("medals", {}).get(stop.id, "none"))
	var is_first_completion := not _is_stop_completed(stop.id)
	var is_upgrade := _medal_value(medal) > _medal_value(previous_medal)

	if is_first_completion:
		var completed: Array = state.get("completed", [])
		completed.append(stop.id)
		state["completed"] = completed

	var medals: Dictionary = state.get("medals", {})
	if is_upgrade:
		medals[stop.id] = medal
	state["medals"] = medals

	if is_first_completion or is_upgrade:
		var xp_earned := roundi(float(stop.xp_reward) * medal_multiplier)
		var points_earned := roundi(float(stop.points_reward) * medal_multiplier)
		state["xp"] = int(state.get("xp", 0)) + xp_earned
		state["tour_points"] = int(state.get("tour_points", 0)) + points_earned
		state["credits"] = int(state.get("credits", 0)) + roundi(float(points_earned) * 0.45)
		result["xp_earned"] = xp_earned
		result["points_earned"] = points_earned

	var stop_index := _get_stop_index(stop.id)
	if stop_index >= 0 and stop_index < stops.size() - 1 and is_first_completion:
		var next_stop: TourStop = stops[stop_index + 1]
		result["unlocked_stop"] = next_stop.id

	TourSave.save_state(state)
	_refresh_all()
	return result


func _simulate_result(score_ratio: float) -> void:
	var stop := _get_stop(selected_stop_id)
	if stop == null:
		return

	var score := roundi(float(stop.target_score) * score_ratio)
	var result := complete_event(stop.id, score)
	_close_result_dialog()

	var message := "Score %s — %s" % [
		_format_number(score),
		str(result.get("medal", "none")).to_upper()
	]
	if not result.get("success", false):
		message += "\nTarget missed. Replay the heat."
	else:
		message += "\n+%s XP  +%s Tour Points" % [
			_format_number(result.get("xp_earned", 0)),
			_format_number(result.get("points_earned", 0))
		]
		if str(result.get("unlocked_stop", "")) != "":
			var unlocked := _get_stop(str(result["unlocked_stop"]))
			if unlocked != null:
				message += "\nUnlocked: %s" % unlocked.display_name

	_show_toast(message)


func _show_toast(message: String) -> void:
	var toast := PanelContainer.new()
	toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast.custom_minimum_size = Vector2(420.0, 90.0)
	toast.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.10, 0.12, 0.98), COLOR_TEAL, 2, 10))
	toast.anchor_left = 0.5
	toast.anchor_top = 0.08
	toast.anchor_right = 0.5
	toast.anchor_bottom = 0.08
	toast.offset_left = -210.0
	toast.offset_top = 0.0
	toast.offset_right = 210.0
	toast.offset_bottom = 90.0
	add_child(toast)

	var label := _label(message, 16, COLOR_TEXT, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	toast.add_child(label)

	toast.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(toast, "modulate:a", 1.0, 0.18)
	tween.tween_interval(2.4)
	tween.tween_property(toast, "modulate:a", 0.0, 0.25)
	tween.tween_callback(toast.queue_free)


func _close_result_dialog() -> void:
	if not result_overlay.visible:
		return

	var tween := create_tween()
	tween.tween_property(result_overlay, "modulate:a", 0.0, 0.14)
	await tween.finished
	result_overlay.visible = false
	result_overlay.modulate.a = 1.0
	start_button.grab_focus()


func _reset_progress() -> void:
	TourSave.delete_save()
	state = _default_state()
	selected_stop_id = "pipeline"
	_refresh_all()
	_show_toast("World Tour progress reset.")


func _is_stop_completed(stop_id: String) -> bool:
	var completed: Array = state.get("completed", [])
	return completed.has(stop_id)


func _is_stop_unlocked(stop_id: String) -> bool:
	var index := _get_stop_index(stop_id)
	if index <= 0:
		return true
	var previous: TourStop = stops[index - 1]
	return _is_stop_completed(previous.id)


func _has_stop(stop_id: String) -> bool:
	return _get_stop(stop_id) != null


func _get_stop(stop_id: String) -> TourStop:
	for stop in stops:
		if stop.id == stop_id:
			return stop
	return null


func _get_stop_index(stop_id: String) -> int:
	for index in range(stops.size()):
		var stop: TourStop = stops[index]
		if stop.id == stop_id:
			return index
	return -1


func _medal_for_score(score: int, target: int) -> String:
	var ratio := float(score) / maxf(1.0, float(target))
	if ratio >= 1.0:
		return "gold"
	if ratio >= 0.80:
		return "silver"
	if ratio >= 0.60:
		return "bronze"
	return "none"


func _medal_value(medal: String) -> int:
	return {
		"none": 0,
		"bronze": 1,
		"silver": 2,
		"gold": 3,
	}.get(medal, 0)


func _calculate_rank(points: int) -> int:
	# Replace this with server/online rankings later.
	return clampi(250 - int(floor(float(points) / 110.0)), 1, 250)


func _ordinal_suffix(value: int) -> String:
	var mod_100 := value % 100
	if mod_100 >= 11 and mod_100 <= 13:
		return "TH"
	match value % 10:
		1:
			return "ST"
		2:
			return "ND"
		3:
			return "RD"
		_:
			return "TH"


func _format_number(value: Variant) -> String:
	var number := int(value)
	var negative := number < 0
	var digits := str(absi(number))
	var output := ""
	while digits.length() > 3:
		output = "," + digits.right(3) + output
		digits = digits.left(digits.length() - 3)
	output = digits + output
	return "-" + output if negative else output


func _focus_initial_control() -> void:
	tour_map.focus_selected()


func _find_first_enabled_button(root: Node) -> Button:
	for child in root.get_children():
		if child is Button and not child.disabled:
			return child
		var nested := _find_first_enabled_button(child)
		if nested != null:
			return nested
	return null


func _label(text_value: String, size_value: int, color_value: Color, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color_value)
	if bold:
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.38))
	return label


func _button(text_value: String, primary: bool) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 48.0
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 14)

	var accent := COLOR_TEAL if primary else Color(0.18, 0.38, 0.43)
	var background := Color(0.04, 0.14, 0.17) if primary else Color(0.03, 0.075, 0.095)
	var hover_background := Color(0.06, 0.22, 0.25)

	button.add_theme_stylebox_override("normal", _panel_style(background, accent, 1, 8))
	button.add_theme_stylebox_override("hover", _panel_style(hover_background, COLOR_TEAL, 2, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(Color(0.02, 0.11, 0.13), COLOR_GOLD, 2, 8))
	button.add_theme_stylebox_override("focus", _panel_style(background, COLOR_GOLD, 2, 8))
	button.add_theme_stylebox_override("disabled", _panel_style(Color(0.02, 0.035, 0.04), Color(0.12, 0.16, 0.17), 1, 8))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_disabled_color", COLOR_LOCKED)
	return button


func _divider() -> HSeparator:
	var divider := HSeparator.new()
	divider.add_theme_constant_override("separation", 12)
	divider.add_theme_stylebox_override("separator", _panel_style(Color(0.11, 0.25, 0.28, 0.65), Color.TRANSPARENT, 0, 1))
	return divider


func _panel_style(
		background: Color,
		border: Color,
		border_width: int = 1,
		radius: int = 8
	) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
