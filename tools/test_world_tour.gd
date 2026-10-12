extends SceneTree
## Headless logic tests for the World Tour screen. Run from the project root:
##   godot --headless --path . -s tools/test_world_tour.gd
## Exits 0 when every check passes, 1 otherwise. The user:// save is backed up before the
## tests run and restored afterwards, so running this does not lose demo progress.

const SAVE_PATH := "user://tidebreak_world_tour.json"

var _failures: int = 0
var _checks: int = 0
var _ran: bool = false


# The tests run on the first frame rather than in _initialize(): SceneTree attaches `root` to the
# tree only after MainLoop.initialize(), so a node added during _initialize() would not get _ready().
func _process(_delta: float) -> bool:
	if _ran:
		return true
	_ran = true
	_run_all()
	return true


func _run_all() -> void:
	var backup := _read_save()
	TourSave.delete_save()

	var screen: WorldTourScreen = load("res://scripts/world_tour/world_tour_screen.gd").new()
	root.add_child(screen)

	_test_fresh_state(screen)
	_test_medal_thresholds(screen)
	_test_first_completion_and_unlock(screen)
	_test_upgrade_and_replay(screen)
	_test_wipeout_and_unknown_stop(screen)
	_test_save_round_trip_and_corruption(screen)
	_test_rank_and_formatting(screen)
	_test_full_season(screen)
	_test_result_dialog_flow(screen)

	screen.queue_free()
	_restore_save(backup)

	print("test_world_tour: %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _test_fresh_state(screen: WorldTourScreen) -> void:
	_check(screen.stops.size() == 7, "seven tour stops")
	_check(screen.state["xp"] == 0 and screen.state["tour_points"] == 0 and screen.state["credits"] == 2500, "default state xp 0 / points 0 / credits 2500")
	_check(screen._is_stop_unlocked("pipeline"), "pipeline unlocked at start")
	for stop_id in ["trestles", "snapper", "jbay", "teahupoo", "cloud9", "finals"]:
		_check(not screen._is_stop_unlocked(stop_id), "%s locked at start" % stop_id)
	_check(screen.progress_label.text == "0%", "progress label 0%% at start (got %s)" % screen.progress_label.text)
	_check(screen.rank_value_label.text == "250TH", "rank label 250TH at 0 points (got %s)" % screen.rank_value_label.text)
	_check(screen.start_button.text == "START EVENT", "start button says START EVENT")


func _test_medal_thresholds(screen: WorldTourScreen) -> void:
	_check(screen._medal_for_score(13199, 22000) == "none", "59.99% of target is none")
	_check(screen._medal_for_score(13200, 22000) == "bronze", "60% of target is bronze")
	_check(screen._medal_for_score(17599, 22000) == "bronze", "79.99% of target is bronze")
	_check(screen._medal_for_score(17600, 22000) == "silver", "80% of target is silver")
	_check(screen._medal_for_score(22000, 22000) == "gold", "100% of target is gold")
	_check(screen._medal_for_score(5, 0) == "gold", "target 0 does not divide by zero")


func _test_first_completion_and_unlock(screen: WorldTourScreen) -> void:
	var result := screen.complete_event("pipeline", 14300)  # 65% -> bronze
	_check(result["success"] == true and result["medal"] == "bronze", "65% at pipeline is a bronze success")
	_check(result["xp_earned"] == 840, "bronze xp = round(1200 * 0.70) = 840 (got %s)" % result["xp_earned"])
	_check(result["points_earned"] == 1120, "bronze points = round(1600 * 0.70) = 1120 (got %s)" % result["points_earned"])
	_check(screen.state["credits"] == 2500 + 504, "credits += round(1120 * 0.45) = 504 (got %s)" % screen.state["credits"])
	_check(result["unlocked_stop"] == "trestles", "first completion unlocks trestles")
	_check(screen._is_stop_unlocked("trestles"), "trestles unlocked after pipeline")
	_check(not screen._is_stop_unlocked("snapper"), "snapper still locked")
	_check(screen.progress_label.text == "14%", "progress label 14%% after one stop (got %s)" % screen.progress_label.text)
	_check(screen.start_button.text == "REPLAY EVENT", "start button says REPLAY EVENT on a completed stop")


func _test_upgrade_and_replay(screen: WorldTourScreen) -> void:
	var xp_before: int = screen.state["xp"]
	var result := screen.complete_event("pipeline", 18700)  # 85% -> silver upgrade
	_check(result["medal"] == "silver" and result["xp_earned"] == 1056, "silver upgrade pays round(1200 * 0.88) = 1056 (got %s)" % result["xp_earned"])
	_check(result["unlocked_stop"] == "", "replay does not report a new unlock")
	_check(screen.state["xp"] == xp_before + 1056, "upgrade adds xp on top of the bronze award")
	_check(screen.state["medals"]["pipeline"] == "silver", "medal stored as silver")
	_check(screen.state["completed"].size() == 1, "completed list holds pipeline once")

	xp_before = screen.state["xp"]
	result = screen.complete_event("pipeline", 14300)  # bronze again: no award
	_check(result["success"] == true and result["xp_earned"] == 0 and screen.state["xp"] == xp_before, "replaying below the stored medal awards nothing")
	_check(screen.state["medals"]["pipeline"] == "silver", "medal never downgrades")
	_check(screen.state["best_scores"]["pipeline"] == 18700, "best score keeps the higher heat")


func _test_wipeout_and_unknown_stop(screen: WorldTourScreen) -> void:
	var completed_before: int = screen.state["completed"].size()
	var result := screen.complete_event("trestles", 11200)  # 40% -> wipeout
	_check(result["success"] == false and result["medal"] == "none", "40% is a wipeout")
	_check(screen.state["completed"].size() == completed_before, "wipeout does not complete the stop")
	_check(screen.state["best_scores"]["trestles"] == 11200, "wipeout still records the best score")
	_check(not screen._is_stop_unlocked("snapper"), "wipeout does not unlock the next stop")
	result = screen.complete_event("nowhere", 99999)
	_check(result["success"] == false and result["reason"] == "unknown_stop", "unknown stop id is rejected")


func _test_save_round_trip_and_corruption(screen: WorldTourScreen) -> void:
	var saved: Dictionary = screen.state.duplicate(true)
	var loaded := TourSave.load_state(screen._default_state())
	_check(loaded["xp"] == saved["xp"] and loaded["tour_points"] == saved["tour_points"], "save round trip keeps xp and points")
	_check(loaded["completed"] == saved["completed"] and loaded["medals"] == saved["medals"], "save round trip keeps completed list and medals")

	_write_save("this is not json {")
	loaded = TourSave.load_state(screen._default_state())
	_check(loaded["xp"] == 0 and loaded["completed"].size() == 0, "unparseable save falls back to defaults")

	_write_save('{"xp": -50, "tour_points": "abc", "completed": "nope", "medals": 3, "best_scores": [], "current_stop": 7}')
	loaded = TourSave.load_state(screen._default_state())
	_check(loaded["xp"] == 0, "negative xp is clamped to 0")
	_check(loaded["tour_points"] == 0, "non-numeric tour_points become 0")
	_check(typeof(loaded["completed"]) == TYPE_ARRAY and loaded["completed"].is_empty(), "non-array completed becomes []")
	_check(typeof(loaded["medals"]) == TYPE_DICTIONARY and typeof(loaded["best_scores"]) == TYPE_DICTIONARY, "non-dictionary medals/best_scores become {}")
	_check(typeof(loaded["current_stop"]) == TYPE_STRING, "current_stop is coerced to a string")

	# Restore the in-memory state to disk so later tests continue from it.
	TourSave.save_state(saved)


func _test_rank_and_formatting(screen: WorldTourScreen) -> void:
	_check(screen._calculate_rank(0) == 250, "0 points ranks 250th")
	_check(screen._calculate_rank(20600) == 63, "a perfect season (20,600 points) ranks 63rd, never 1st")
	_check(screen._calculate_rank(1000000) == 1, "rank clamps at 1")
	_check(screen._format_number(1234567) == "1,234,567", "thousands separators")
	_check(screen._format_number(-1200) == "-1,200", "negative numbers keep the sign")
	_check(screen._ordinal_suffix(11) == "TH" and screen._ordinal_suffix(22) == "ND" and screen._ordinal_suffix(103) == "RD", "ordinal suffixes")


func _test_full_season(screen: WorldTourScreen) -> void:
	screen._reset_progress()
	_check(screen.state["completed"].is_empty() and screen.state["xp"] == 0, "reset clears progress")
	for stop in screen.stops:
		var result := screen.complete_event(stop.id, int(float(stop.target_score) * 1.10))
		_check(result["medal"] == "gold", "gold at %s" % stop.id)
	_check(screen.state["completed"].size() == 7, "all seven stops completed")
	_check(screen.state["xp"] == 15750, "all-gold season xp = 15,750 (got %s)" % screen.state["xp"])
	_check(screen.state["tour_points"] == 20600, "all-gold season points = 20,600 (got %s)" % screen.state["tour_points"])
	_check(screen.progress_label.text == "100%", "progress label 100%% (got %s)" % screen.progress_label.text)
	_check(screen.rank_value_label.text == "63RD", "best reachable rank label is 63RD (got %s)" % screen.rank_value_label.text)
	_check(screen.sponsor_name_label.text == "TIDEBREAK PRO", "15,750 xp lands in the TIDEBREAK PRO tier (got %s)" % screen.sponsor_name_label.text)
	_check(screen.xp_value_label.text == "15,750 / 24,000 XP", "header xp label (got %s)" % screen.xp_value_label.text)


func _test_result_dialog_flow(screen: WorldTourScreen) -> void:
	screen._reset_progress()
	screen._select_stop("pipeline")
	_check(not screen.result_overlay.visible, "result overlay hidden before START EVENT")
	screen._start_selected_event()
	_check(screen.result_overlay.visible, "START EVENT shows the result overlay")
	_check(screen.result_dialog_title.text == "PIPELINE  •  TARGET 22,000", "dialog title names the stop and target (got %s)" % screen.result_dialog_title.text)
	screen._simulate_result(1.10)
	_check(screen.state["completed"].has("pipeline"), "GOLD 110% button completes pipeline")
	_check(screen._is_stop_unlocked("trestles"), "trestles unlocked through the dialog path")
	screen._select_stop("finals")
	_check(screen.selected_stop_id == "pipeline", "selecting a locked stop is ignored")


func _check(condition: bool, label: String) -> void:
	_checks += 1
	if condition:
		print("  PASS  %s" % label)
	else:
		_failures += 1
		printerr("  FAIL  %s" % label)


func _read_save() -> String:
	if not FileAccess.file_exists(SAVE_PATH):
		return ""
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _write_save(text: String) -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _restore_save(text: String) -> void:
	if text.is_empty():
		TourSave.delete_save()
	else:
		_write_save(text)
