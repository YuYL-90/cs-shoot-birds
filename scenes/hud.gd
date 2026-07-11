extends CanvasLayer

@onready var health_label = $Health

func _on_health_updated(health: int):
	health_label.text = str(health) + "%"
