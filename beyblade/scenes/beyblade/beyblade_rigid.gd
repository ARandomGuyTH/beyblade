class_name Beyblade 
extends RigidBody3D

const  GRAVITY := Vector3(0, -9.8, 0)

@export var maxSpin: float = 3000.0
@export var spinDecay: float = 1.0
@export var gyroStrength: float = 0.6
@export var inertiaTensor: float = 0.4
@export var coefficientFriction: float = 0.2
@export var drag: float = 0.5
@export var wobble: float = 0.4
@export var collisionForceScale: float = 1
@export var spinLossHitCoefficient: float = 80.0
@export var propulsion_strength: float = 2500.0


@onready var groundRay : RayCast3D = $groundRay;
@onready var topRay : RayCast3D = $topRay;
@onready var hitEffects = $"hit effects"
@onready var collisionTimer = $"collision cooldown"

var spin_speed: float = maxSpin
var lost : bool = false
var collisionActive = true

func apply_gyroscopic_torque(delta: float) -> void:
	var spin_axis := basis.y
	var angular_momentum := spin_axis * spin_speed * inertiaTensor
	var gyro_torque := angular_momentum.cross(GRAVITY) * gyroStrength

	apply_torque(gyro_torque * delta)

func decay_spin(delta: float) -> void:
	spin_speed = max(0.0, spin_speed - spinDecay * delta)

	# Map spin_speed tends to angular_velocity
	var target_av := basis.y * deg_to_rad(spin_speed)
	angular_velocity = angular_velocity.lerp(target_av, 0.15)

func apply_wobble_torque(delta: float) -> void:
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
	linear_velocity = 30*(Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() - global_position.normalized())

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
		apply_force(-global_position.normalized() * delta * 0) #apply small force to the centre of the stadium
		apply_spin_propulsion(delta)	
		decay_spin(delta)
		apply_gyroscopic_torque(delta)
		apply_wobble_torque(delta)

func _on_collision_cooldown_timeout() -> void:
	collisionActive = true
