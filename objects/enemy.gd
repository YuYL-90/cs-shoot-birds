extends Node3D

@export var player: Node3D

@onready var raycast = $RayCast
@onready var muzzle_a = $MuzzleA
@onready var muzzle_b = $MuzzleB

var health := 100
var time := 0.0
var target_position: Vector3
var destroyed := false

func _ready():
	target_position = position

func _process(delta):
	if player == null or destroyed:
		return
	
	self.look_at(player.position + Vector3(0, 0.5, 0), Vector3.UP, true)
	target_position.y += (cos(time * 5) * 1) * delta
	
	time += delta
	
	position = target_position

func damage(amount):
	health -= amount
	
	if health <= 0 and !destroyed:
		destroy()

func destroy():
	destroyed = true
	queue_free()

func _on_timer_timeout():
	if player == null or destroyed:
		return
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		if collider.has_method("damage"):
			muzzle_a.frame = 0
			muzzle_a.play("default")
			muzzle_a.rotation_degrees.z = randf_range(-45, 45)
			
			muzzle_b.frame = 0
			muzzle_b.play("default")
			muzzle_b.rotation_degrees.z = randf_range(-45, 45)
			
			collider.damage(5)
