extends RefCounted
# What the villages order. Colour is the identity — it has to read from 150 m
# up (village flag), on a crate band, and in the HUD.

const INFO := {
	"rot": {"name": "Medizin", "color": Color(0.86, 0.22, 0.20)},
	"blau": {"name": "Briefe", "color": Color(0.20, 0.47, 0.92)},
	"gelb": {"name": "Saatgut", "color": Color(0.96, 0.78, 0.14)},
}
const IDS: Array[String] = ["rot", "blau", "gelb"]


static func label(id: String) -> String:
	return INFO[id].name


static func tint(id: String) -> Color:
	return INFO[id].color
