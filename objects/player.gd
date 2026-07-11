extends CharacterBody3D

@export_subgroup("Properties")
@export var movement_speed = 5
@export_range(0, 100) var number_of_jumps: int = 2
@export var jump_strength = 8

@export_subgroup("Weapons")
@export var weapons: Array[Weapon] = []

var weapon: Weapon
var weapon_index := 0

var mouse_sensitivity = 700
var gamepad_sensitivity := 0.075

var mouse_captured := true

var movement_velocity: Vector3
var rotation_target: Vector3 = Vector3(0, PI, 0)

var input_mouse: Vector2

var health: int = 100
var gravity := 0.0

var previously_floored := false

var jumps_remaining: int

var container_offset = Vector3(1.2, -1.1, -2.75)

var tween: Tween

signal health_updated

@onready var camera = $Head/Camera
@onready var raycast = $Head/Camera/RayCast
@onready var muzzle = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Muzzle
@onready var container = $Head/Camera/SubViewportContainer/SubViewport/CameraItem/Container
@onready var blaster_cooldown = $Cooldown
@onready var shoot_sound = $ShootSound

@export var crosshair_path: NodePath
var crosshair: TextureRect

func _ready():
	if crosshair_path:
		crosshair = get_node(crosshair_path)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	if weapons.size() > 0:
		weapon = weapons[weapon_index]
		initiate_change_weapon(weapon_index)

func _process(delta):
	handle_controls(delta)
	handle_gravity(delta)
	
	var applied_velocity: Vector3
	
	movement_velocity = transform.basis * movement_velocity
	
	applied_velocity = velocity.lerp(movement_velocity, delta * 10)
	applied_velocity.y = - gravity
	
	velocity = applied_velocity
	move_and_slide()
	
	container.position = lerp(container.position, container_offset - (basis.inverse() * applied_velocity / 30), delta * 10)
	
	camera.position.y = lerp(camera.position.y, 0.0, delta * 5)
	
	if is_on_floor() and gravity > 1 and !previously_floored:
		camera.position.y = -0.1
	
	previously_floored = is_on_floor()
	
	if position.y < -10:
		health = 0
		health_updated.emit(0)

func _input(event):
	if event is InputEventMouseMotion and mouse_captured:
		input_mouse = event.relative / mouse_sensitivity
		handle_rotation(event.relative.x, event.relative.y, false)

func _unhandled_input(event):
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if mouse_captured:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			mouse_captured = false
			input_mouse = Vector2.ZERO
			get_viewport().set_input_as_handled()
		else:
			get_tree().quit()

func handle_controls(delta):
	if Input.is_action_just_pressed("mouse_capture"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		mouse_captured = true
	
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	movement_velocity = Vector3(input.x, 0, input.y).normalized() * movement_speed
	
	var rotation_input := Input.get_vector("camera_right", "camera_left", "camera_down", "camera_up")
	if rotation_input:
		handle_rotation(rotation_input.x, rotation_input.y, true, delta)
	
	action_shoot()
	
	if Input.is_action_just_pressed("jump"):
		if jumps_remaining:
			action_jump()
	
	action_weapon_toggle()

func handle_rotation(xRot: float, yRot: float, isController: bool, delta: float = 0.0):
	if isController:
		rotation_target -= Vector3(-yRot, -xRot, 0).limit_length(1.0) * gamepad_sensitivity
		rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))
		camera.rotation.x = lerp_angle(camera.rotation.x, rotation_target.x, delta * 25)
		rotation.y = lerp_angle(rotation.y, rotation_target.y, delta * 25)
	else:
		rotation_target += (Vector3(-yRot, -xRot, 0) / mouse_sensitivity)
		rotation_target.x = clamp(rotation_target.x, deg_to_rad(-90), deg_to_rad(90))
		camera.rotation.x = rotation_target.x
		rotation.y = rotation_target.y

func handle_gravity(delta):
	gravity += 20 * delta

	if gravity < 0 and is_on_ceiling():
		gravity = 0
	
	if gravity > 0 and is_on_floor():
		jumps_remaining = number_of_jumps
		gravity = 0

func action_jump():
	gravity = - jump_strength
	jumps_remaining -= 1

func action_shoot():
	if Input.is_action_pressed("shoot"):
		if !blaster_cooldown.is_stopped(): return
		
		muzzle.play("default")
		muzzle.rotation_degrees.z = randf_range(-45, 45)
		muzzle.scale = Vector3.ONE * randf_range(0.40, 0.75)
		muzzle.position = container.position - weapon.muzzle_position
		
		blaster_cooldown.start(weapon.cooldown)
		
		if weapon.sound_shoot:
			shoot_sound.stream = weapon.sound_shoot
			shoot_sound.play()
		
		for n in weapon.shot_count:
			raycast.target_position.x = randf_range(-weapon.spread, weapon.spread)
			raycast.target_position.y = randf_range(-weapon.spread, weapon.spread)
			
			raycast.force_raycast_update()
			
			if !raycast.is_colliding(): continue
			
			var collider = raycast.get_collider()
			
			if collider.has_method("damage"):
				collider.damage(weapon.damage)
			
			var impact = preload("res://objects/impact.tscn")
			var impact_instance = impact.instantiate()
			
			impact_instance.play("shot")
			
			get_tree().root.add_child(impact_instance)
			
			impact_instance.position = raycast.get_collision_point() + (raycast.get_collision_normal() / 10)
			impact_instance.look_at(camera.global_transform.origin, Vector3.UP, true)
		 
		var knockback = random_vec2(weapon.min_knockback, weapon.max_knockback)
		container.position.z += 0.25
		camera.rotation.x += knockback.x
		rotation.y += knockback.y
		rotation_target.x += knockback.x
		rotation_target.y += knockback.y
		movement_velocity += Vector3(0, 0, weapon.knockback)

func action_weapon_toggle():
	if Input.is_action_just_pressed("weapon_toggle"):
		if weapons.size() > 0:
			weapon_index = wrap(weapon_index + 1, 0, weapons.size())
			initiate_change_weapon(weapon_index)

func initiate_change_weapon(index):
	weapon_index = index
	
	tween = get_tree().create_tween()
	tween.set_ease(Tween.EASE_OUT_IN)
	tween.tween_property(container, "position", container_offset - Vector3(0, 1, 0), 0.1)
	tween.tween_callback(change_weapon)

func change_weapon():
	weapon = weapons[weapon_index]
	
	for n in container.get_children():
		container.remove_child(n)
	
	var weapon_model = weapon.model.instantiate()
	container.add_child(weapon_model)
	
	weapon_model.position = weapon.position
	weapon_model.rotation_degrees = weapon.rotation
	
	for child in weapon_model.find_children("*", "MeshInstance3D"):
		child.layers = 2
	
	raycast.target_position = Vector3(0, 0, -1) * weapon.max_distance
	if crosshair:
		crosshair.texture = weapon.crosshair

func damage(amount):
	health -= amount
	if health < 0:
		health = 0
	health_updated.emit(health)

static func random_vec2(_min: Vector2, _max: Vector2) -> Vector2:
	var _sign = -1 if randi() % 2 == 0 else 1
	return Vector2(randf_range(_min.x, _max.x), randf_range(_min.y, _max.y) * _sign)
