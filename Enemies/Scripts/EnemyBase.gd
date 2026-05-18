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
@export var jump_velocity: float = -280.0 # Standard jump force for 1-2 blocks

@export_group("AI")
@export var aggro_range: float = 200.0
@export var attack_range: float = 40.0
@export var patrol_distance: float = 100.0
@export var attack_cooldown: float = 3 # Time in seconds between attacks
@export var attack_windup_time: float = 0.35 # Time player has to react before hitbox activates
@export var attack_lunge_force: float = 180.0 # Small dash forward when striking

var current_health: float
var current_poise: float
var current_state: State = State.IDLE
var is_invincible: bool = false
var is_winding_up: bool = false

var poise_recover_timer: float = 0.0
var stun_timer: float = 0.0
var target: Node2D = null
var attack_cooldown_timer: float = 0.0


@onready var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# Node References for Autojump
@onready var wall_check: RayCast2D = $WallCheck
@onready var ledge_check: RayCast2D = $LedgeCheck

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
	
	# Attack cooldown tick relevant to delta time
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta
			
	match current_state:
		State.IDLE: _process_idle(delta)
		State.CHASE: _process_chase(delta)
		State.ATTACK: _process_attack(delta)
		State.HURT: _process_hurt(delta)
		State.DEAD: _process_dead(delta)
	
	# Run autojump check if moving horizontally and on the floor
	if is_on_floor() and abs(velocity.x) > 0:
		_update_raycast_directions()
		_check_autojump()
	
	if is_on_floor() and get_slide_collision_count() > 0:
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			# Check if the object we landed on is the player
			if collider and collider.is_in_group("player"):
				# Push the enemy slightly left or right depending on which side of the player's center they are on
				var push_dir = sign(global_position.x - collider.global_position.x)
				if push_dir == 0: push_dir = 1 # Fallback if perfectly centered
				velocity.x += push_dir * 150.0
			
	move_and_slide()
	_update_animations()

func _process_idle(delta):
	velocity.x = move_toward(velocity.x, 0, 500 * delta)
	if target and global_position.distance_to(target.global_position) <= aggro_range:
		current_state = State.CHASE

func _process_chase(delta):
	if not target: 
		current_state = State.IDLE
		return
		
	var dist = global_position.distance_to(target.global_position)
	var dir = sign(target.global_position.x - global_position.x)
	if dir == 0: dir = 1
	
	# CONDITION 1: In range and ready to strike
	if dist <= attack_range and attack_cooldown_timer <= 0:
		current_state = State.ATTACK
		is_winding_up = true
		stun_timer = attack_windup_time
		return
		
	# CONDITION 2: Too far away, give up
	if dist > aggro_range * 1.5:
		current_state = State.IDLE
		return
		
	# CONDITION 3: Smart Spacing (On Cooldown)
	# Instead of hugging the player awkwardly, back off or slow down
	if attack_cooldown_timer > 0 and dist < attack_range * 1.5:
		# Pace back and forth or just slow down to maintain combat spacing
		velocity.x = move_toward(velocity.x, -dir * (speed * 0.5), 300 * delta)
	else:
		# Standard chase
		velocity.x = move_toward(velocity.x, dir * chase_speed, 600 * delta)

func _process_attack(delta):
	# Decelerate naturally unless lunging
	if not is_winding_up and stun_timer > 0.2: 
		# We are mid-strike/lunge, let velocity carry them
		pass
	else:
		velocity.x = move_toward(velocity.x, 0, 400 * delta)
	
	stun_timer -= delta
	
	# Phase 1: Winding up (Telegraphing the attack)
	if is_winding_up:
		if stun_timer <= 0:
			# Wind-up finished! Unleash the attack & lunge forward
			is_winding_up = false
			stun_timer = 0.3 # Duration the hitbox stays active
			
			var dir = sign(target.global_position.x - global_position.x)
			if dir == 0: dir = 1
			velocity.x = dir * attack_lunge_force # LUNGE!
			
			if has_node("Hitbox"):
				# 1. Turn on BOTH Godot area flags just to be completely safe
				$Hitbox.set_deferred("monitoring", true)
				$Hitbox.set_deferred("monitorable", true)
				
				# 2. Call your custom script setup if it exists
				if $Hitbox.has_method("enabled_hitbox"):
					$Hitbox.call_deferred("enabled_hitbox", true)
	
	# Phase 2: Hitbox is active / Recovering from swing
	else:
		if stun_timer <= 0:
			# Attack completely finished, turn everything off safely
			if has_node("Hitbox"):
				$Hitbox.set_deferred("monitoring", false)
				$Hitbox.set_deferred("monitorable", false)
				if $Hitbox.has_method("enabled_hitbox"):
					$Hitbox.call_deferred("enabled_hitbox", false)
					
			attack_cooldown_timer = attack_cooldown
			current_state = State.CHASE

func _process_hurt(delta):
	velocity.x = move_toward(velocity.x, 0, 500 * delta)
	stun_timer -= delta
	if stun_timer <= 0:
		current_state = State.CHASE

# --- AUTOJUMP MECHANICS ---

func _update_raycast_directions():
	# Dynamically flip raycasts depending on horizontal movement direction
	var move_dir = sign(velocity.x)
	if move_dir != 0:
		wall_check.target_position.x = abs(wall_check.target_position.x) * move_dir
		ledge_check.target_position.x = abs(ledge_check.target_position.x) * move_dir

func _check_autojump():
	# If the lower ray hits a wall, but the upper ray is clear -> jump!
	if ledge_check.is_colliding() and not wall_check.is_colliding():
		velocity.y = jump_velocity
		
func _trigger_hitstop(duration: float = 0.15) -> void:
	# Instead of freezing Engine.time_scale (which ruins multi-enemy fights),
	# temporarily freeze just this enemy's animations and logic processing.
	if has_node("EnemySprite"):
		$EnemySprite.pause()
	set_physics_process(false)
	
	await get_tree().create_timer(duration, false).timeout # false = ignores engine pause
	
	set_physics_process(true)
	if has_node("EnemySprite"):
		$EnemySprite.play()


# --------------------------

func _process_dead(delta):
	# Slowly decelerate horizontal movement to a stop while falling/dying
	velocity.x = move_toward(velocity.x, 0, 500 * delta)

func _on_hurtbox_damage_taken(amount: float, knockback: float, hitbox_pos: Vector2, p_damage: float):
	if current_state == State.DEAD or current_state == State.HURT: 
		return
	
	current_health -= amount
	current_poise -= p_damage
	poise_recover_timer = 3.0 
	
	if current_health <= 0:
		current_state = State.DEAD
		
		# Heavy impact shake on death!
		SignalBus.shake_requested.emit(1.0, 0.75)
		_trigger_hitstop(0.1) # Quicker hitstop for snappy feel
		
		modulate = Color(10,10,10) # Brighter flash for impact
		var t = create_tween()
		t.tween_property(self, "modulate", Color.WHITE, 0.8)

		# --- OPTIMIZATION/CLEANUP ON DEATH ---
		if has_node("Hurtbox"): $Hurtbox.queue_free()
		if has_node("Hitbox"): $Hitbox.queue_free()
		set_collision_layer_value(2, false)
		
		if has_node("EnemySprite"):
			$EnemySprite.play("death")
			$EnemySprite.animation_finished.connect(_on_death_animation_finished)
		else:
			queue_free()
		return
		
	if current_poise <= 0:
		current_poise = max_poise 
		current_state = State.HURT
		stun_timer = 0.8 
		
		
		var dir = sign(global_position.x - hitbox_pos.x)
		if dir == 0: dir = 1
		velocity.x = dir * knockback
		velocity.y = -150.0 
		
		
		modulate = Color(5,0,0)
		var t = create_tween()
		t.tween_property(self, "modulate", Color.WHITE, 0.4)
		
		SignalBus.shake_requested.emit(0.8, 0.50)

	
	await get_tree().create_timer(0.05).timeout
	is_invincible = false

func _update_animations():
	if has_node("EnemySprite") and velocity.x != 0:
		var is_left = velocity.x < 0
		# Fixed a minor bug here: changed $Sprite2D to $EnemySprite based on your script context
		$EnemySprite.flip_h = is_left
		if has_node("Hitbox"):
			$Hitbox.position.x = -21 if is_left else 21
			
	# Fixing the animation state conditions (swapped raw enum queries to true conditions)
	if has_node("EnemySprite"):
		match current_state:
			State.IDLE: $EnemySprite.play("idle")
			State.CHASE, State.PATROL: $EnemySprite.play("walk")
			State.ATTACK: $EnemySprite.play("attack")
			State.DEAD: $EnemySprite.play("death")
			
func _on_death_animation_finished():
	if $EnemySprite.animation == "death":
		queue_free() # Safely removes the enemy instance from the scene tree and memory
