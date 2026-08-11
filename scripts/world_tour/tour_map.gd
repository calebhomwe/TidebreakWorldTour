class_name TourMap
extends Control

signal stop_selected(stop_id: String)

const ROUTE_LOCKED := Color(0.20, 0.28, 0.34, 0.70)
const ROUTE_OPEN := Color(0.08, 0.82, 0.88, 0.95)
const ROUTE_COMPLETE := Color(0.96, 0.70, 0.16, 1.0)
const MAP_PADDING := Vector2(70.0, 58.0)

var stops: Array = []
var state: Dictionary = {}
var selected_stop_id: String = ""
var stop_buttons: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	resized.connect(_on_resized)


func configure(new_stops: Array, new_state: Dictionary, initial_selection: String) -> void:
	stops = new_stops
	state = new_state
	selected_stop_id = initial_selection
	_rebuild_stop_buttons()
	queue_redraw()


func refresh(new_state: Dictionary, new_selection: String) -> void:
	state = new_state
	selected_stop_id = new_selection
	_update_button_states()
	queue_redraw()


func focus_selected() -> void:
	var button: Button = stop_buttons.get(selected_stop_id)
	if is_instance_valid(button) and not button.disabled:
		button.grab_focus()


func _draw() -> void:
	var map_rect := Rect2(MAP_PADDING, size - MAP_PADDING * 2.0)
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return

	_draw_grid(map_rect)
	_draw_route(map_rect)


func _draw_grid(map_rect: Rect2) -> void:
	var grid_color := Color(0.16, 0.32, 0.39, 0.20)
	for index in range(1, 8):
		var x := map_rect.position.x + map_rect.size.x * (float(index) / 8.0)
		draw_line(
			Vector2(x, map_rect.position.y),
			Vector2(x, map_rect.end.y),
			grid_color,
			1.0
		)

	for index in range(1, 5):
		var y := map_rect.position.y + map_rect.size.y * (float(index) / 5.0)
		draw_line(
			Vector2(map_rect.position.x, y),
			Vector2(map_rect.end.x, y),
			grid_color,
			1.0
		)

	# Soft continent-like silhouettes to make the placeholder map feel intentional.
	draw_circle(map_rect.position + map_rect.size * Vector2(0.18, 0.43), 74.0, Color(0.13, 0.25, 0.30, 0.34))
	draw_circle(map_rect.position + map_rect.size * Vector2(0.42, 0.34), 86.0, Color(0.13, 0.25, 0.30, 0.28))
	draw_circle(map_rect.position + map_rect.size * Vector2(0.67, 0.47), 104.0, Color(0.13, 0.25, 0.30, 0.31))
	draw_circle(map_rect.position + map_rect.size * Vector2(0.83, 0.63), 58.0, Color(0.13, 0.25, 0.30, 0.28))


func _draw_route(map_rect: Rect2) -> void:
	for index in range(stops.size() - 1):
		var current: TourStop = stops[index]
		var next: TourStop = stops[index + 1]
		var from := _map_point(current.map_position, map_rect)
		var to := _map_point(next.map_position, map_rect)
		var color := ROUTE_LOCKED

		if _is_completed(current.id):
			color = ROUTE_COMPLETE
		elif _is_unlocked(current.id):
			color = ROUTE_OPEN

		_draw_dashed_line(from, to, color, 3.0, 11.0, 7.0)

	for stop in stops:
		var position := _map_point(stop.map_position, map_rect)
		var ring_color := ROUTE_LOCKED
		if _is_completed(stop.id):
			ring_color = ROUTE_COMPLETE
		elif _is_unlocked(stop.id):
			ring_color = ROUTE_OPEN

		draw_circle(position, 12.0, Color(0.025, 0.06, 0.08, 0.96))
		draw_arc(position, 17.0, 0.0, TAU, 40, ring_color, 3.0, true)

		if stop.id == selected_stop_id:
			draw_arc(position, 25.0, 0.0, TAU, 40, Color(1.0, 1.0, 1.0, 0.82), 2.0, true)


func _draw_dashed_line(
		from: Vector2,
		to: Vector2,
		color: Color,
		width: float,
		dash_length: float,
		gap_length: float
	) -> void:
	var distance := from.distance_to(to)
	if distance <= 0.01:
		return

	var direction := from.direction_to(to)
	var cursor := 0.0
	while cursor < distance:
		var segment_end := minf(cursor + dash_length, distance)
		draw_line(from + direction * cursor, from + direction * segment_end, color, width, true)
		cursor += dash_length + gap_length


func _rebuild_stop_buttons() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	stop_buttons.clear()

	for stop in stops:
		var button := Button.new()
		button.name = "Stop_%s" % stop.id
		button.text = "%02d  %s\n%s" % [stops.find(stop) + 1, stop.display_name, stop.country]
		button.custom_minimum_size = Vector2(164.0, 58.0)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.pressed.connect(_on_stop_button_pressed.bind(stop.id))
		add_child(button)
		stop_buttons[stop.id] = button

	_update_button_states()
	call_deferred("_layout_stop_buttons")


func _update_button_states() -> void:
	for stop in stops:
		var button: Button = stop_buttons.get(stop.id)
		if not is_instance_valid(button):
			continue

		var unlocked := _is_unlocked(stop.id)
		var completed := _is_completed(stop.id)
		button.disabled = not unlocked
		button.modulate = Color.WHITE if unlocked else Color(0.50, 0.56, 0.60, 0.62)

		var normal := _make_button_style(
			Color(0.035, 0.08, 0.105, 0.94),
			Color(0.18, 0.38, 0.44, 0.80)
		)
		var hover := _make_button_style(
			Color(0.05, 0.15, 0.18, 0.98),
			ROUTE_OPEN
		)
		var selected_border := ROUTE_COMPLETE if completed else ROUTE_OPEN
		var selected := _make_button_style(
			Color(0.05, 0.13, 0.16, 0.98),
			selected_border,
			3
		)
		var disabled := _make_button_style(
			Color(0.025, 0.045, 0.055, 0.88),
			Color(0.14, 0.19, 0.22, 0.70)
		)

		button.add_theme_stylebox_override("normal", selected if stop.id == selected_stop_id else normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", selected)
		button.add_theme_stylebox_override("focus", selected)
		button.add_theme_stylebox_override("disabled", disabled)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_disabled_color", Color(0.55, 0.60, 0.64))
		button.add_theme_font_size_override("font_size", 14)


func _layout_stop_buttons() -> void:
	var map_rect := Rect2(MAP_PADDING, size - MAP_PADDING * 2.0)
	for stop in stops:
		var button: Button = stop_buttons.get(stop.id)
		if not is_instance_valid(button):
			continue

		var point := _map_point(stop.map_position, map_rect)
		button.position = point + Vector2(-82.0, 24.0)


func _map_point(normalized: Vector2, map_rect: Rect2) -> Vector2:
	return map_rect.position + Vector2(
		map_rect.size.x * normalized.x,
		map_rect.size.y * normalized.y
	)


func _is_completed(stop_id: String) -> bool:
	var completed: Array = state.get("completed", [])
	return completed.has(stop_id)


func _is_unlocked(stop_id: String) -> bool:
	var index := _find_stop_index(stop_id)
	if index <= 0:
		return true

	var previous: TourStop = stops[index - 1]
	return _is_completed(previous.id)


func _find_stop_index(stop_id: String) -> int:
	for index in range(stops.size()):
		var stop: TourStop = stops[index]
		if stop.id == stop_id:
			return index
	return -1


func _on_stop_button_pressed(stop_id: String) -> void:
	selected_stop_id = stop_id
	_update_button_states()
	queue_redraw()
	stop_selected.emit(stop_id)


func _on_resized() -> void:
	_layout_stop_buttons()
	queue_redraw()


func _make_button_style(background: Color, border: Color, border_width: int = 1) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_left = 7
	style.corner_radius_bottom_right = 7
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style
