class_name TourStop
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var country: String = ""
@export var date_label: String = ""
@export var map_position: Vector2 = Vector2.ZERO
@export var target_score: int = 25000
@export var entry_cost: int = 0
@export var xp_reward: int = 1000
@export var points_reward: int = 1500
@export var wave_height: String = "4–6 FT"
@export var condition_label: String = "GOOD"
@export var description: String = ""
@export var accent_color: Color = Color(0.10, 0.85, 0.90)
@export var final_event: bool = false


static func create(
		stop_id: String,
		stop_name: String,
		stop_country: String,
		stop_dates: String,
		stop_map_position: Vector2,
		stop_target_score: int,
		stop_xp_reward: int,
		stop_points_reward: int,
		stop_wave_height: String,
		stop_condition: String,
		stop_description: String,
		stop_accent: Color,
		is_final: bool = false
	) -> TourStop:
	var stop := TourStop.new()
	stop.id = stop_id
	stop.display_name = stop_name
	stop.country = stop_country
	stop.date_label = stop_dates
	stop.map_position = stop_map_position
	stop.target_score = stop_target_score
	stop.xp_reward = stop_xp_reward
	stop.points_reward = stop_points_reward
	stop.wave_height = stop_wave_height
	stop.condition_label = stop_condition
	stop.description = stop_description
	stop.accent_color = stop_accent
	stop.final_event = is_final
	return stop
