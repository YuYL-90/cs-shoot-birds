extends CharacterBody3D

@export var player: Node3D
@export var move_speed: float = 1.5

@onready var raycast = $RayCast
@onready var muzzle_a = $MuzzleA
@onready var muzzle_b = $MuzzleB
@onready var hurt_sound = $HurtSound
@onready var destroy_sound = $DestroySound

var health := 100
var time := 0.0
var base_y: float
var wander_target: Vector3
var destroyed := false
var locked_on := false

func _ready():
	base_y = position.y
	pick_wander_target()
	if not player:
		player = get_tree().root.find_child("Player", true, false)

func _physics_process(delta):
	if destroyed:
		return
	
	time += delta
	
	if locked_on:
		if player:
			self.look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP, true)
	elif velocity.length() > 0.1:
		var look_pos = position + Vector3(velocity.x, 0, velocity.z).normalized()
		self.look_at(look_pos, Vector3.UP, true)
	
	var dir = wander_target - position
	dir.y = 0
	if dir.length() > 0.5:
		velocity.x = dir.normalized().x * move_speed
		velocity.z = dir.normalized().z * move_speed
	else:
		velocity.x = 0
		velocity.z = 0
		pick_wander_target()
	
	velocity.y = cos(time * 5) * 2.0
	move_and_slide()

func pick_wander_target():
	wander_target = Vector3(randf_range(-6, 6), base_y, randf_range(-2, 6))

func damage(amount):
	health -= amount
	hurt_sound.play()
	
	if health <= 0 and !destroyed:
		destroy()
	elif player:
		locked_on = true
		shoot_at_player()

func destroy():
	destroyed = true
	destroy_sound.play()
	hide()
	
	var respawn_timer = Timer.new()
	respawn_timer.wait_time = 2.0
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_respawn)
	add_child(respawn_timer)
	respawn_timer.start()

func _respawn():
	health = 100
	time = 0.0
	destroyed = false
	locked_on = false
	var spawn_pos = Vector3(randf_range(-6, 6), base_y, randf_range(-2, 6))
	position = spawn_pos
	wander_target = Vector3(randf_range(-6, 6), base_y, randf_range(-2, 6))
	show()

func shoot_at_player():
	if not player or destroyed:
		return
	
	if global_position.distance_squared_to(player.global_position) > 400:
		return
	
	muzzle_a.frame = 0
	muzzle_a.play("default")
	muzzle_a.rotation_degrees.z = randf_range(-45, 45)
	
	muzzle_b.frame = 0
	muzzle_b.play("default")
	muzzle_b.rotation_degrees.z = randf_range(-45, 45)
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		if collider == player and player.has_method("damage"):
			player.damage(5)

func _on_timer_timeout():
	if not player or destroyed or not locked_on:
		return
	
	shoot_at_player()
