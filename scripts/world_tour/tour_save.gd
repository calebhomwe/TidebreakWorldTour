class_name TourSave
extends RefCounted

const SAVE_PATH := "user://tidebreak_world_tour.json"


static func load_state(default_state: Dictionary) -> Dictionary:
	var fallback := default_state.duplicate(true)

	if not FileAccess.file_exists(SAVE_PATH):
		return fallback

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("World Tour save could not be opened. Error: %s" % FileAccess.get_open_error())
		return fallback

	var json_text := file.get_as_text()
	file.close()

	var parser := JSON.new()
	var parse_error := parser.parse(json_text)
	if parse_error != OK or typeof(parser.data) != TYPE_DICTIONARY:
		push_warning(
			"World Tour save is invalid. Error: %s, line: %s"
			% [parser.get_error_message(), parser.get_error_line()]
		)
		return fallback

	var loaded: Dictionary = parser.data
	for key in loaded.keys():
		fallback[key] = loaded[key]

	return _sanitize(fallback, default_state)


static func save_state(state: Dictionary) -> bool:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("World Tour save could not be written. Error: %s" % FileAccess.get_open_error())
		return false

	file.store_string(JSON.stringify(state, "\t", true))
	file.flush()
	file.close()
	return true


static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var error := DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		if error != OK:
			push_warning("Could not delete World Tour save. Error: %s" % error)


static func _sanitize(state: Dictionary, defaults: Dictionary) -> Dictionary:
	state["version"] = int(state.get("version", defaults["version"]))
	state["xp"] = maxi(0, int(state.get("xp", defaults["xp"])))
	state["tour_points"] = maxi(0, int(state.get("tour_points", defaults["tour_points"])))
	state["credits"] = maxi(0, int(state.get("credits", defaults["credits"])))
	state["current_stop"] = str(state.get("current_stop", defaults["current_stop"]))

	var completed_value: Variant = state.get("completed", [])
	if typeof(completed_value) != TYPE_ARRAY:
		state["completed"] = []
	else:
		state["completed"] = completed_value

	var medal_value: Variant = state.get("medals", {})
	if typeof(medal_value) != TYPE_DICTIONARY:
		state["medals"] = {}
	else:
		state["medals"] = medal_value

	var scores_value: Variant = state.get("best_scores", {})
	if typeof(scores_value) != TYPE_DICTIONARY:
		state["best_scores"] = {}
	else:
		state["best_scores"] = scores_value

	return state
