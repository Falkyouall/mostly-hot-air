class_name StationBallast
extends Station
## Ballast — one-shot sandbag drop. Press "secondary" to dump weight; the
## balloon receives an instant upward velocity kick and one bag is consumed.

signal ballast_requested


func _ready() -> void:
	station_name = &"Ballast"
	free_color = Color(0.32, 0.28, 0.22)
	occupied_color = Color(0.86, 0.78, 0.45)
	super()


func on_secondary(_by: Player) -> void:
	ballast_requested.emit()
