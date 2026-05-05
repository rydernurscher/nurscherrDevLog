extends CharacterBody2D
class_name Player

# --- SIGNALS ---
signal health_changed(new_health)
signal mana_changed(new_mana)
signal stamina_changed(new_stamina)

# --- CONFIGURATION ---
@export_group("Movement")
@export var SPEED = 160.0
@export var ACCELERATION_GROUND = 800.0
@export var FRICTION_GROUND = 1000.0
@export var ACCELERATION_AIR = 400.0
@export var FRICTION_AIR = 200.0
@export var ROLL_SPEED = 280.0

@export_group("Jumping & Gravity")
@export var JUMP_VELOCITY = -320.0
@export var JUMP_RELEASE_MULTIPLIER = 0.5 
@export var GRAVITY_SCALE = 1.0
@export var FALL_GRAVITY_SCALE = 1.5      
@export var JUMP_BUFFER_TIME = 0.1
@export var COYOTE_TIME = 0.1

@export_group("Souls Stats")
@export var max_health: float = 100.0
@export var health_regen_rate: float = 2.0
@export var max_mana: float = 50.0
@export var mana_regen_rate: float = 5.0
@export var max_stamina: float = 100.0
@export var stamina_regen_rate: float = 25.0

@export_group("Inventory & World")
@export var equipped_weapon: WeaponData
@export var chunk_width: int = 100
@export var WING_ACCELERATION = 25.0 
@export var MAX_FLIGHT_ASCENT_SPEED = -400.0 

# --- INTERNAL VARIABLES ---
var current_health: float = 100.0
var current_mana: float = 50.0
var current_stamina: float = 100.0

var inventory: Array[WeaponData] = [] 
var block_inventory: Dictionary = {} 
var chunks: Dictionary = {}
var surface_heights: Dictionary = {}

var is_hurting: bool = false
var is_rolling: bool = false
var is_attacking: bool = false
var i_frames_active: bool = false
var is_flying: bool = false 
var facing_direction: int = 1 

var roll_duration: float = 0.4
var roll_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0

@onready var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var sprite = $AnimatedSprite2D
@onready var hurt_anim = $HurtAnim
@onready var wings = $AnimatedSprite2D/Wings if has_node("AnimatedSprite2D/Wings") else null
@onready var hitbox = $Hitbox
@onready var terrain_layer = get_tree().get_first_node_in_group("terrain")

# --- INITIALIZATION ---
func _ready():
	current_health = max_health
	current_mana = max_mana
	current_stamina = max_stamina
	
	if wings: wings.visible = false
	hurt_anim.visible = false
	hurt_anim.animation_finished.connect(_on_hurt_finished)
	
	_setup_ui()

func _setup_ui():
	var ui = get_node_or_null("PlayerUI")
	if ui:
		ui.set_max_stats(max_health, max_mana, max_stamina)
		health_changed.connect(ui.update_health)
		mana_changed.connect(ui.update_mana)
		stamina_changed.connect(ui.update_stamina)
		health_changed.emit(current_health)
		mana_changed.emit(current_mana)
		stamina_changed.emit(current_stamina)

func _on_hurt_finished():
	# Note: Only resetting if the hurt animation specifically finished
	is_hurting = false
	hurt_anim.visible = false

# --- PHYSICS & INPUT ---
func _physics_process(delta):
	_update_timers(delta)
	_regen_stats(delta)
	
	if is_rolling:
		_process_roll(delta)
	elif is_attacking:
		velocity.x = move_toward(velocity.x, 0, FRICTION_GROUND * delta)
		_apply_gravity(delta)
	else:
		_handle_movement(delta)
		_apply_gravity(delta)
		_handle_mouse_flip()
	
	move_and_slide()
	_update_animations()

func _update_timers(delta):
	coyote_timer = COYOTE_TIME if is_on_floor() else coyote_timer - delta
	jump_buffer_timer -= delta

func _handle_mouse_flip():
	var mouse_pos = get_global_mouse_position()
	var is_left = mouse_pos.x < global_position.x
	sprite.flip_h = is_left
	if wings: wings.flip_h = is_left

func _apply_gravity(delta):
	if is_flying: return
	var active_scale = FALL_GRAVITY_SCALE if velocity.y > 0 else GRAVITY_SCALE
	velocity.y += gravity * active_scale * delta

func _handle_movement(delta):
	# Jump Logic
	if Input.is_action_just_pressed("jump"): jump_buffer_timer = JUMP_BUFFER_TIME
	
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
	elif Input.is_action_pressed("jump") and not is_on_floor():
		is_flying = true
		velocity.y = max(velocity.y - WING_ACCELERATION, MAX_FLIGHT_ASCENT_SPEED)
	else:
		is_flying = false
		if Input.is_action_just_released("jump") and velocity.y < 0:
			velocity.y *= JUMP_RELEASE_MULTIPLIER

	# Combat/Roll Triggers
	if Input.is_action_just_pressed("roll") and current_stamina >= 25.0 and is_on_floor():
		_start_roll()
		return
	if Input.is_action_just_pressed("attack") and current_stamina >= 15.0:
		_attack()
		return

	# Horizontal Movement
	var dir = Input.get_axis("left", "right")
	var accel = ACCELERATION_GROUND if is_on_floor() else ACCELERATION_AIR
	var frict = FRICTION_GROUND if is_on_floor() else FRICTION_AIR
	
	if dir != 0:
		facing_direction = sign(dir)
		velocity.x = move_toward(velocity.x, dir * SPEED, accel * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, frict * delta)

# --- ANIMATION CONTROLLER ---
func _update_animations():
	if is_hurting: return # Lock animations while flinching
	
	
	if is_attacking:
		if sprite.sprite_frames.has_animation("attack"): sprite.play("attack")
	elif is_on_floor():
		if wings: wings.visible = false	
		sprite.play("run" if velocity.x != 0 else "idle")
	elif is_flying and wings:
		wings.visible = true
		wings.play("fly")
		sprite.play("jump")
	else:
		sprite.play("jump")

# --- MECHANICS ---
func _start_roll():
	is_rolling = true
	i_frames_active = true
	current_stamina -= 25.0
	stamina_changed.emit(current_stamina)
	roll_timer = roll_duration
	velocity.x = facing_direction * ROLL_SPEED

func _process_roll(delta):
	roll_timer -= delta
	if roll_timer <= 0:
		is_rolling = false
		i_frames_active = false

func _attack():
	if !equipped_weapon or current_stamina < equipped_weapon.stamina_cost: return
	is_attacking = true
	current_stamina -= equipped_weapon.stamina_cost
	stamina_changed.emit(current_stamina)
	
	if hitbox: hitbox.damage = equipped_weapon.damage 
	if sprite.sprite_frames.has_animation(equipped_weapon.animation_name):
		sprite.play(equipped_weapon.animation_name)
	
	await get_tree().create_timer(equipped_weapon.attack_duration).timeout
	is_attacking = false

func _regen_stats(delta):
	if !is_rolling and !is_attacking:
		current_stamina = min(current_stamina + (stamina_regen_rate * delta), max_stamina)
		stamina_changed.emit(current_stamina)
	
	if current_health > 0:
		current_health = min(current_health + (health_regen_rate * delta), max_health)
		health_changed.emit(current_health)
		
	current_mana = min(current_mana + (mana_regen_rate * delta), max_mana)
	mana_changed.emit(current_mana)

func take_damage(amount: float):
	if i_frames_active or current_health <= 0: return
	
	current_health = clamp(current_health - amount, 0.0, max_health)
	health_changed.emit(current_health)
	
	is_hurting = true
	hurt_anim.visible = true
	hurt_anim.play_backwards("hurt")
	
	if current_health <= 0: die()

func die():
	print("YOU DIED")

# --- WORLD INTERACTION ---
func mine_block(world_pos: Vector2):
	var map_pos = terrain_layer.local_to_map(world_pos)
	var chunk_id = floor(map_pos.x / float(chunk_width))
	
	if not chunks.has(chunk_id): return
	var target_chunk = chunks[chunk_id]
	var mined_id = target_chunk.get_cell_source_id(map_pos)
	
	if mined_id != -1:
		add_block("dirt" if mined_id == 0 else "stone")
		target_chunk.set_cell(map_pos, -1) # Using set_cell for performance in chunks
		
		if surface_heights.get(map_pos.x) == map_pos.y:
			var new_y = map_pos.y + 1
			while target_chunk.get_cell_source_id(Vector2i(map_pos.x, new_y)) == -1 and new_y < 1000:
				new_y += 1
			surface_heights[map_pos.x] = new_y
			target_chunk.notify_runtime_tile_data_update()

func add_block(block_name: String, amount: int = 1):
	block_inventory[block_name] = block_inventory.get(block_name, 0) + amount

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H: take_damage(20.0) 
		if event.keycode == KEY_M: 
			current_mana = max(current_mana - 15.0, 0.0)
			mana_changed.emit(current_mana)

	if event.is_action_pressed("mine"):
		var m_pos = get_global_mouse_position()
		if terrain_layer and global_position.distance_to(m_pos) < 80.0:
			mine_block(m_pos)
