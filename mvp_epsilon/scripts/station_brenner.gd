class_name StationBrenner
extends Station
## Brenner — continuous-load station. While occupied, the burner is on.
## Balloon polls is_burning() each physics tick instead of using a signal,
## because the state is per-frame, not event-shaped.

func _ready() -> void:
	station_name = &"Brenner"
	free_color = Color(0.35, 0.30, 0.24)
	occupied_color = Color(1.00, 0.55, 0.18)
	super()


func is_burning() -> bool:
	return not is_free()
