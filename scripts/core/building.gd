class_name Building
extends Node2D

signal building_destroyed(building: Building)

enum BuildingType {
	BASE,
	BARRACKS
}

var building_type: int = BuildingType.BASE
var team: int = 0
var grid_pos: Vector2i = Vector2i.ZERO
var health: int = 500
var max_health: int = 500
var team_color: Color = Color(0.2, 0.6, 1.0)

func _ready():
	queue_redraw()

func take_damage(amount: int, attacker: UnitBase):
	health -= amount
	if health <= 0:
		health = 0
		building_destroyed.emit(self)
		queue_free()
	queue_redraw()

func _draw():
	var size = Vector2(48, 48)
	var rect = Rect2(-size / 2, size)
	var body_color = team_color if team == 0 else Color(1.0, 0.3, 0.3)
	draw_rect(rect, body_color)
	draw_rect(rect, Color(0.1, 0.1, 0.2), false, 2.0)
	var type_icon = "H" if building_type == BuildingType.BASE else "B"
	draw_string(
		ThemeDB.fallback_font,
		Vector2(-8, 5),
		type_icon,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		18,
		Color.WHITE
	)
	var health_bar_width = 52
	var health_percent = float(health) / max_health
	draw_rect(Rect2(-health_bar_width / 2, -36, health_bar_width, 5), Color(0.3, 0.3, 0.3))
	draw_rect(Rect2(-health_bar_width / 2, -36, health_bar_width * health_percent, 5), Color(0.2, 0.8, 0.2))
