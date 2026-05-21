class_name Beyblade 
extends RigidBody3D

const  GRAVITY := Vector3(0, -9.8, 0)

@export var maxSpin: float = 3000.0
@export var spinDecay: float = 50.0
@export var gyroStrength: float = 10.0
@export var coefficientFriction: float = 0.2
@export var drag: float = 0.5
@export var wobble: float = 0.4
@export var collisionForceScale: float = 3.0
@export var spinLossHitCoefficient: float = 80.0
@export var propulsion_strength: float = 5000.0


@onready var groundRay : RayCast3D = $groundRay;
@onready var topRay : RayCast3D = $topRay;
@onready var hitEffects = $"hit effects"
@onready var collisionTimer = $"collision cooldown"
@onready var testRay = $"testRay"

var spin_speed: float = maxSpin
var lost : bool = false
var collisionActive = true

func draw_line(start : Vector3, end : Vector3)-> void: #requires visible collision shapes on
	testRay.global_position = start
	testRay.target_position = end

func get_surface_normal() -> Vector3:
	if groundRay.is_colliding():
		draw_line(global_position,groundRay.get_collision_normal()*10)
		return groundRay.get_collision_normal()
	draw_line(global_position,Vector3.UP *10)
	return Vector3.UP  # fallback if airborne


func apply_gyroscopic_force(delta: float) -> void:
	var spin_axis := basis.y
	var up := get_surface_normal()
	var gyro_torque := (up - spin_axis) * gyroStrength * spin_speed

	apply_torque(gyro_torque * delta)

func decay_spin(delta: float) -> void:
	spin_speed = max(0.0, spin_speed - spinDecay * delta)

	# Map spin_speed tends to angular_velocity
	var target_av := basis.y * deg_to_rad(spin_speed)
	angular_velocity = angular_velocity.lerp(target_av, 0.15)

func apply_wobble_force(delta: float) -> void:
	if not groundRay.is_colliding():
		return
		
	# Wobble grows as spin decreases
	var random_wobble := Vector3(
		randf_range(-1.0, 1.0),
		0.0,
		randf_range(-1.0, 1.0)
	).normalized()

	linear_velocity += random_wobble * wobble
	

func apply_floor_friction(delta: float) -> void:
	if topRay.is_colliding(): #when upsidedown
		spinDecay += 10000 * delta
	
	if not groundRay.is_colliding(): #if not on ground no friction
		return
			
	# friction
	var lateral_vel := linear_velocity
	lateral_vel.y = 0.0
	apply_central_force(-lateral_vel * coefficientFriction * mass)

	spinDecay += drag * delta

func apply_spin_propulsion(delta: float) -> void:
	if not groundRay.is_colliding():
		return

	var spin_ratio := spin_speed / maxSpin
	if spin_ratio < 0.05:
		return

	var tilt := basis.y - Vector3.UP
	tilt.y = 0.0  # only care about horizontal component

	if tilt.length() < 0.001:
		return

	# Push in the direction the tilt is "leaning" — this creates the
	# characteristic erratic speeding-around behaviour
	var thrust := tilt.normalized() * spin_ratio * propulsion_strength * delta
	apply_central_force(thrust)
	
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("beyblade") || spin_speed < 0.5 || !collisionActive:
		return
			
	collisionActive = false
	collisionTimer.start()
		
	var other := body as Beyblade
	var impact = (other.global_position - global_position).normalized()	
	var relative_vel = absf(linear_velocity.length()) - absf(other.linear_velocity.length()) * 0

	# Faster beyblade pushes the other away more
	print(name," ", relative_vel, " ")
	var knockback : Vector3 = impact * collisionForceScale * max(relative_vel, -relative_vel*0.5) * mass
	knockback.y = clamp(knockback.y, -20.0, 0.0)
		
	if other.spin_speed >= 0.5:
		call_deferred("handle_collision", other, knockback) #handles collision on the next frame
	
	hitEffects.activate_effects((global_position + other.global_position)/2) #activate effects at contact point

func handle_collision(other, knockback):
		other.apply_central_impulse(knockback/other.mass)
		other.spin_speed -= spinLossHitCoefficient



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("body_entered", _on_body_entered)
	# Lock Y-position slightly to keep blade on floor plane
	axis_lock_linear_y = false  # let gravity work naturally
	linear_velocity = -10* global_position.normalized() + 20*(Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()) 

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	#print(groundRay.is_colliding())
	#print(touchingFloor.global_position.y)
		
func _physics_process(delta: float) -> void:
	decay_spin(delta)
	apply_floor_friction(delta)
	if spin_speed <= 0.0:
		# Beyblade has stopped let it fall
		if !lost:
			lost = true
			print(name)
	
	else:
		apply_spin_propulsion(delta)	
		decay_spin(delta)
		apply_gyroscopic_force(delta)
		apply_wobble_force(delta)

func _on_collision_cooldown_timeout() -> void:
	collisionActive = true
