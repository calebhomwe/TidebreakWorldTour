extends Node
## Connects a Godot 4 web build to the arcade SDK (assets/arcade-sdk.js in calebhomwe/arcade).
##
## Add this file as an autoload named `Arcade` (Project > Project Settings > Autoload).
## On desktop and in the editor every call does nothing, so the game runs unchanged there.
##
##   func _ready():
##       Arcade.restart_requested.connect(_restart_run)   # optional: default reloads the scene
##       Arcade.cheat_entered.connect(_apply_code)
##       Arcade.tutorial_requested.connect(_show_tutorial)
##       Arcade.setup({
##           "title_scene": "res://scenes/title.tscn",   # Exit to title goes here
##           "tutorial": true,                           # offer "Replay tutorial"
##           "tricks": [{"name": "Cutback", "input": "A + D"}],
##           "cheats": [{"code": "BIGWAVE", "effect": "Every wave is a double overhead"}],
##       })
##   Arcade.scene("play")                  # "title", "play" or "over"
##   Arcade.scene("over", score)
##   Arcade.set_hint("Pump on the steep part of the wave for speed")
##   if not Arcade.cheated(): save_best(score)
##
## Pausing needs no code: the SDK stops the browser's frame clock, which freezes the whole
## engine, and suspends its audio. A game with its own pause menu can instead call
## setup({"own_pause_ui": true}), handle `pause_requested` / `resume_requested`, and report
## its menu with Arcade.game_paused(true / false).

signal restart_requested
signal exit_requested
signal tutorial_requested
signal pause_requested
signal resume_requested
signal cheat_entered(code: String)

var _sdk: JavaScriptObject = null
var _callbacks: Array = []   # JavaScriptBridge callbacks must stay referenced or they are freed
var _title_scene := ""


func _ready() -> void:
	if OS.has_feature("web"):
		_sdk = JavaScriptBridge.get_interface("ArcadeSDK")


func available() -> bool:
	return _sdk != null


func setup(opts: Dictionary = {}) -> void:
	if _sdk == null:
		return
	_title_scene = opts.get("title_scene", "")
	var o: JavaScriptObject = JavaScriptBridge.create_object("Object")
	o.onRestart = _cb(_on_restart)
	o.onExit = _cb(_on_exit)
	if tutorial_requested.get_connections().size() > 0 or opts.get("tutorial", false):
		o.onTutorial = _cb(func(_a): tutorial_requested.emit())
	if opts.get("own_pause_ui", false):
		o.ownPauseUI = true
		o.onPause = _cb(func(_a): pause_requested.emit())
		o.onResume = _cb(func(_a): resume_requested.emit())
	var cheats: Array = opts.get("cheats", [])
	if cheats.size() > 0:
		o.cheats = _array_of(cheats, ["code", "effect"])
		o.onCheat = _cb(func(a): cheat_entered.emit(str(a[0])))
	var tricks: Array = opts.get("tricks", [])
	if tricks.size() > 0:
		o.tricks = _array_of(tricks, ["name", "input"])
	_sdk.init(o)


func scene(name: String, score: int = -1) -> void:
	if _sdk == null:
		return
	var s: JavaScriptObject = JavaScriptBridge.create_object("Object")
	s.scene = name
	if score >= 0:
		s.score = score
	_sdk.state(s)


func set_hint(text: String) -> void:
	if _sdk != null:
		_sdk.setHint(text)


func event(name: String) -> void:
	if _sdk != null:
		_sdk.event(name)


func game_paused(on: bool) -> void:
	if _sdk != null:
		_sdk.gamePaused(on)


func cheated() -> bool:
	return _sdk != null and bool(_sdk.cheated)


func _cb(f: Callable) -> JavaScriptObject:
	var c := JavaScriptBridge.create_callback(f)
	_callbacks.append(c)
	return c


func _array_of(rows: Array, keys: Array) -> JavaScriptObject:
	var arr: JavaScriptObject = JavaScriptBridge.create_object("Array")
	for row in rows:
		var o: JavaScriptObject = JavaScriptBridge.create_object("Object")
		for k in keys:
			o[k] = str(row.get(k, ""))
		arr.push(o)
	return arr


func _on_restart(_args) -> void:
	if restart_requested.get_connections().size() > 0:
		restart_requested.emit()
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()


func _on_exit(_args) -> void:
	if exit_requested.get_connections().size() > 0:
		exit_requested.emit()
	elif _title_scene != "":
		get_tree().paused = false
		get_tree().change_scene_to_file(_title_scene)
	else:
		get_tree().paused = false
		get_tree().reload_current_scene()
