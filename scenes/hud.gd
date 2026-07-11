extends CanvasLayer

signal game_over

const TOTAL_ENEMIES := 3

@onready var health_label = $Health
@onready var kill_label = $KillCount
@onready var popup = $Popup
@onready var popup_message = $Popup/Message
@onready var restart_btn = $Popup/Restart

var kills := 0
var game_over_state := false


func _ready():
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(node: Node):
	if node.has_signal("killed"):
		if not node.killed.is_connected(_on_enemy_killed):
			node.killed.connect(_on_enemy_killed)


func _on_enemy_killed():
	kills += 1
	kill_label.text = "击败: " + str(kills) + "/" + str(TOTAL_ENEMIES)
	if kills >= TOTAL_ENEMIES:
		_show_popup("成功!")


func _on_health_updated(health: int):
	if health < 0:
		health = 0
	health_label.text = str(health) + "%"
	if health <= 0:
		_show_popup("失败")


func _show_popup(message: String):
	if game_over_state:
		return
	game_over_state = true
	popup_message.text = message
	popup.show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game_over.emit()


func _on_restart():
	get_tree().paused = false
	get_tree().reload_current_scene()
