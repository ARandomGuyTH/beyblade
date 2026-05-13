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

@onready var groundRay : RayCast3D = $groundRay;
@onready var topRay : RayCast3D = $topRay;

var isFlipped : bool = false
var spin_speed: float = maxSpin

func apply_gyroscopic_torque(delta: float) -> void:
	var spin_axis := basis.y  # local up = spin axis
	# Gyroscopic torque = angular_momentum × gravity_direction
	var angular_momentum := spin_axis * spin_speed * inertiaTensor
	var gyro_torque := angular_momentum.cross(GRAVITY) * gyroStrength

	apply_torque(gyro_torque * delta)

func decay_spin(delta: float) -> void:
	spin_speed = max(0.0, spin_speed - spinDecay * delta)

	# Map spin_speed → actual angular_velocity on local Y
	var target_av := basis.y * deg_to_rad(spin_speed)
	angular_velocity = angular_velocity.lerp(target_av, 0.15)

func apply_wobble_torque(delta: float) -> void:
	if spin_speed < 1.0 || not groundRay.is_colliding():
		return
		
	# Wobble grows as spin weakens
	var wobble_factor : float = clamp(1.0 - (spin_speed / maxSpin), 0.0, 1.0)
	var random_perturb := Vector3(
		randf_range(-1.0, 1.0),
		0.0,
		randf_range(-1.0, 1.0)
	).normalized()

	apply_torque(random_perturb * wobble_factor * wobble)
	linear_velocity += random_perturb
	

func apply_floor_friction(delta: float) -> void:
	if topRay.is_colliding() && !isFlipped:
		spinDecay += 100
		
	if !topRay.is_colliding() && isFlipped:
		spinDecay -= 100
	
	if not groundRay.is_colliding():
		return
			
	# Lateral friction (slows sliding)
	var lateral_vel := linear_velocity
	lateral_vel.y = 0.0
	apply_central_force(-lateral_vel * coefficientFriction * mass)

	# Extra spin drag when contacting floor
	spinDecay += drag * delta
	
func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("beyblade"):
		return
		
	var other := body as Beyblade
	var impact = (other.global_position - global_position).normalized()
	var relative_spin = spin_speed - other.spin_speed

	# Faster spinner transfers momentum and pushes the other away
	var knockback : Vector3 = impact * relative_spin * collisionForceScale
	other.apply_central_impulse(knockback/other.mass)
	other.spin_speed -= spinLossHitCoefficient


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("body_entered", _on_body_entered)
	# Lock Y-position slightly to keep blade on floor plane
	axis_lock_linear_y = false  # let gravity work naturally
	linear_velocity = 10*(Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized() - global_position.normalized())

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	#print(groundRay.is_colliding())
	#print(touchingFloor.global_position.y)
		
func _physics_process(delta: float) -> void:
	if spin_speed <= 0.0:
		# Blade has stopped — let it fall over naturally
		pass
	
	linear_velocity -= global_position.normalized() * delta * 3 #apply small force to the centre of the stadium

		
	decay_spin(delta)
	apply_gyroscopic_torque(delta)
	apply_wobble_torque(delta)
	apply_floor_friction(delta)
