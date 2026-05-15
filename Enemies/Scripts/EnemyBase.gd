extends CharacterBody2D
class_name EnemyBase

enum State { IDLE, PATROL, CHASE, ATTACK, HURT, DEAD }

@export_group("Stats")
@export var max_health: float = 50.0
@export var max_poise: float = 30.0 # Elden Ring poise mechanic!
@export var speed: float = 60.0
@export var chase_speed: float = 110.0
@export var damage: float = 15.0
@export var knockback_dealt: float = 250.0
@export var poise_damage_dealt: float = 15.0

@export_group("AI")
@export var aggro_range: float = 200.0
@export var attack_range: float = 40.0
@export var patrol_distance: float = 100.0

var current_health: float
var current_poise: float
var current_state: State = State.IDLE
var is_invincible: bool = false

var poise_recover_timer: float = 0.0
var stun_timer: float = 0.0
var target: Node2D = null

@onready var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready():
	current_health = max_health
	current_poise = max_poise
	
	if has_node("Hurtbox"):
		$Hurtbox.damage_taken.connect(_on_hurtbox_damage_taken)
	if has_node("Hitbox"):
		$Hitbox.damage = damage
		$Hitbox.knockback_force = knockback_dealt
		$Hitbox.poise_damage = poise_damage_dealt
		
	target = get_tree().get_first_node_in_group("player")

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
		
	# Poise resets if left alone for a few seconds
	if poise_recover_timer > 0:
		poise_recover_timer -= delta
		if poise_recover_timer <= 0:
			current_poise = max_poise
			
	match current_state:
		State.IDLE: _process_idle(delta)
		State.CHASE: _process_chase(delta)
		State.ATTACK: _process_attack(delta)
		State.HURT: _process_hurt(delta)
			
	move_and_slide()
	_update_animations()

func _process_idle(delta):
	velocity.x = move_toward(velocity.x, 0, 500 * delta)
	if target and global_position.distance_to(target.global_position) <= aggro_range:
		current_state = State.CHASE

func _process_chase(_delta):
	if not target: 
		current_state = State.IDLE
		return
		
	var dist = global_position.distance_to(target.global_position)
	if dist <= attack_range:
		current_state = State.ATTACK
	elif dist > aggro_range * 1.5:
		current_state = State.IDLE
	else:
		var dir = sign(target.global_position.x - global_position.x)
		velocity.x = dir * chase_speed

func _process_attack(delta):
	velocity.x = move_toward(velocity.x, 0, 500 * delta)
	
	if not $Hitbox.monitorable:
		$Hitbox.enabled_hitbox(true)
	
	# Instead of await, use a state timer
	if stun_timer <= 0: # Reusing stun_timer as a general action timer
		if has_node("Hitbox"):
			$Hitbox.set_deferred("monitorable", true)
		stun_timer = 0.5 # Attack duration
	
	if stun_timer > 0:
		stun_timer -= delta
		if stun_timer <= 0:
			if has_node("Hitbox"):
				$Hitbox.set_deferred("monitorable", false)
			current_state = State.CHASE

func _process_hurt(delta):
	velocity.x = move_toward(velocity.x, 0, 500 * delta)
	stun_timer -= delta
	if stun_timer <= 0:
		current_state = State.CHASE

func _on_hurtbox_damage_taken(amount: float, knockback: float, hitbox_pos: Vector2, p_damage: float):
	# If we are already hurt, ignore new damage until the stun is over
	if current_state == State.DEAD or current_state == State.HURT: 
		return
	
	current_health -= amount
	current_poise -= p_damage
	poise_recover_timer = 3.0 
	
	if current_health <= 0:
		current_state = State.DEAD
		$CollisionShape2D.set_deferred("disabled", true) # Stop blocking player
		$Hitbox/CollisionShape2D.set_deferred("disabled", true) # Stop hurting player
	
		# Fake a death animation with a timer for now:
		var t = create_tween()
		t.tween_property(self, "modulate:a", 0.0, 0.5)
		t.tween_callback(queue_free)
		return
		
	if current_poise <= 0:
		current_poise = max_poise 
		current_state = State.HURT
		stun_timer = 0.8 # Now this timer will actually reach 0
		
		# Knockback
		var dir = sign(global_position.x - hitbox_pos.x)
		if dir == 0: dir = 1
		velocity.x = dir * knockback
		velocity.y = -150.0 
		
		# Visual flash
		modulate = Color(5,0,0)
		var t = create_tween()
		t.tween_property(self, "modulate", Color.WHITE, 0.4)
	
	# Reset invincibility after a short delay
	await get_tree().create_timer(0.05).timeout
	is_invincible = false

func _update_animations():
	if has_node("Sprite2D") and velocity.x != 0:
		var is_left = velocity.x < 0
		$Sprite2D.flip_h = is_left
		# ADD THIS: Move the enemy hitbox too
		if has_node("Hitbox"):
			$Hitbox.position.x = -21 if is_left else 21
