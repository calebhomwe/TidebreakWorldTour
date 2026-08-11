# TIDEBREAK World Tour — Godot 4.7

A standalone, data-driven World Tour screen for the TIDEBREAK surf game concept.

## Included

- Seven-stop world tour route
- Sequential stop unlocking
- Premium dark sports-game UI generated entirely in code
- Keyboard, mouse, and controller focus support
- Bronze, silver, and gold event results
- XP, tour points, credits, sponsor tiers, and simulated rankings
- Persistent JSON save at `user://tidebreak_world_tour.json`
- A custom-drawn map route with stop buttons
- Event card carousel and selected-event details
- Test harness for simulating heat results
- Clean integration signal for loading your real surf gameplay scene

## Run the demo

1. Open this folder in Godot 4.7.
2. Run the project.
3. Select Pipeline.
4. Press **Start Event**.
5. Choose a simulated result.
6. Achieve at least bronze to unlock the next stop.

No textures, fonts, plugins, or third-party assets are required.

## Drop it into your existing game

Copy:

```text
scripts/world_tour/
world_tour_demo.tscn
```

You can rename `world_tour_demo.tscn` or instance it inside your own menu flow.

## Connect it to real surfing gameplay

The screen emits:

```gdscript
signal event_requested(stop_id: String, target_score: int)
```

Connect it from your menu/game-flow script:

```gdscript
@onready var world_tour: WorldTourScreen = $WorldTourScreen

func _ready() -> void:
	world_tour.event_requested.connect(_on_world_tour_event_requested)

func _on_world_tour_event_requested(stop_id: String, target_score: int) -> void:
	GameSession.world_tour_stop_id = stop_id
	GameSession.target_score = target_score
	get_tree().change_scene_to_file("res://gameplay/surf_heat.tscn")
```

After the heat, return the score to the World Tour screen:

```gdscript
var result := world_tour.complete_event(
	GameSession.world_tour_stop_id,
	final_heat_score
)

print(result)
```

Returned result example:

```gdscript
{
	"success": true,
	"stop_id": "pipeline",
	"score": 25300,
	"medal": "gold",
	"unlocked_stop": "trestles",
	"xp_earned": 1200,
	"points_earned": 1600
}
```

For scene changes, store the World Tour state manager in an Autoload or call the same progression logic from your GameSession singleton. The included screen saves automatically after every meaningful state change.

## Important files

- `tour_stop.gd` — event data model
- `tour_save.gd` — JSON save/load service
- `tour_map.gd` — route drawing and map node selection
- `world_tour_screen.gd` — UI, progression, rankings, rewards, and integration API

## Replace placeholder map art

The route is drawn inside `TourMap._draw()`. For the final visual:

1. Put a world-map texture behind `TourMap`.
2. Keep the stop coordinates normalized from `0.0` to `1.0`.
3. Remove or soften the placeholder continent circles in `_draw_grid()`.
4. Replace generated stop buttons with a reusable `.tscn` node if desired.

## Suggested next production step

Move the tour stop definitions out of `_create_tour_stops()` and into `.tres` resources. Godot custom Resources are ideal for editable game data and can be maintained directly in the Inspector.
