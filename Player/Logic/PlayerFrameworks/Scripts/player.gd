extends CharacterBody2D
class_name Player

# --- SIGNALS ---
signal health_changed(new_health)
signal mana_changed(new_mana)
signal stamina_changed(new_stamina)

# --- ENUMS & STATES ---
enum State { IDLE, MOVE, ROLL, ATTACK, FLY, HURT }
var current_state: State = State.IDLE

# --- CONFIGURATION ---
@export_group("Movement")
@export var SPEED: float = 165.0
@export var ACCELERATION: float = 1100.0
@export var FRICTION: float = 1300.0
@export var ROLL_SPEED: float = 310.0
@export var ROLL_DURATION: float = 0.25

@export_group("Jumping & Flight")
@export var JUMP_VELOCITY: float = -330.0
@export var COYOTE_TIME: float = 0.15
@export var JUMP_BUFFER: float = 0.15
@export var FLIGHT_POWER: float = 35.0 

@export_group("Stats & Combat")
@export var max_health: float = 100.0
@export var health_regen: float = 1.5
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 30.0
@export var max_mana: float = 50.0
@export var mana_regen: float = 5.0
@export var equipped_weapon: WeaponData

# --- INTERNAL VARIABLES ---
var current_health: float
var current_stamina: float
var current_mana: float

var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var roll_timer: float = 0.0
var attack_timer: float = 0.0
var stun_timer: float = 0.0
var facing_direction: int = 1

@onready var sprite = $AnimatedSprite2D
@onready var wings = $AnimatedSprite2D/Wings if has_node("AnimatedSprite2D/Wings") else null
@onready var hitbox = $Hitbox if has_node("Hitbox") else null
@onready var ui = $PlayerUI
@onready var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# References assigned by WorldGenerator
var generator: WorldGenerator 

# --- INITIALIZATION ---
func _ready():
	current_health = max_health
	current_stamina = max_stamina
	current_mana = max_mana
	
	add_to_group("player")
	_setup_ui()

func _setup_ui():
	if ui:
		ui.set_max_stats(max_health, max_mana, max_stamina)
		# Ensure signals are connected to the UI script methods
		if not health_changed.is_connected(ui.update_health):
			health_changed.connect(ui.update_health)
		if not mana_changed.is_connected(ui.update_mana):
			mana_changed.connect(ui.update_mana)
		if not stamina_changed.is_connected(ui.update_stamina):
			stamina_changed.connect(ui.update_stamina)
		
		# Set initial values
		health_changed.emit(current_health)
		mana_changed.emit(current_mana)
		stamina_changed.emit(current_stamina)

# --- MAIN LOOP ---
func _physics_process(delta):
	_update_timers(delta)
	_regen_stats(delta)
	
	match current_state:
		State.ROLL:
			_process_roll(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HURT:
			_process_hurt(delta)
		_: # IDLE, MOVE, FLY
			_process_standard_movement(delta)
	
	move_and_slide()
	_update_animations()
	_handle_mouse_flip()

# --- INPUT & MOVEMENT ---
func _process_standard_movement(delta):
	var dir = Input.get_axis("left", "right")
	
	# Horizontal
	if dir != 0:
		velocity.x = move_toward(velocity.x, dir * SPEED, ACCELERATION * delta)
		facing_direction = sign(dir)
		if is_on_floor(): current_state = State.MOVE
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		if is_on_floor(): current_state = State.IDLE

	# Jump logic
	if Input.is_action_just_pressed("jump"): jump_buffer_timer = JUMP_BUFFER
	
	if jump_buffer_timer > 0 and coyote_timer > 0:
		velocity.y = JUMP_VELOCITY
		jump_buffer_timer = 0
		coyote_timer = 0
	elif Input.is_action_pressed("jump") and not is_on_floor():
		velocity.y = max(velocity.y - FLIGHT_POWER, -220.0)
		current_state = State.FLY
	else:
		_apply_gravity(delta)

	# Action Triggers
	if Input.is_action_just_pressed("roll") and is_on_floor() and current_stamina >= 20:
		_start_roll()
	elif Input.is_action_just_pressed("attack") and current_stamina >= 15:
		_start_attack()
	
	if Input.is_action_pressed("mine"):
		_handle_mining()

func _input(event):
	# Debug Keys
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H:
			take_damage(20.0)
		if event.keycode == KEY_M:
			current_mana = max(0, current_mana - 15)
			mana_changed.emit(current_mana)

# --- MECHANICS ---
func _handle_mining():
	if !generator: return
	
	var m_pos = get_global_mouse_position()
	if global_position.distance_to(m_pos) > 80.0: return
	
	# Use the generator's base layer to find the map coordinate
	var map_pos = generator.base_layer.local_to_map(m_pos)
	
	if generator.world_data.has(map_pos):
		# 1. Erase from the logic dictionary
		generator.world_data.erase(map_pos)
		
		# 2. Update the visual TileMapLayer and neighbors
		generator.update_tile_at(map_pos)
		generator.update_tile_at(map_pos + Vector2i.UP)
		generator.update_tile_at(map_pos + Vector2i.DOWN)
		generator.update_tile_at(map_pos + Vector2i.LEFT)
		generator.update_tile_at(map_pos + Vector2i.RIGHT)
		
		# 3. Recalculate lighting for the column
		generator._update_shading_for_column(map_pos.x, generator.world_data)

func _start_roll():
	current_state = State.ROLL
	roll_timer = ROLL_DURATION
	current_stamina -= 20.0
	stamina_changed.emit(current_stamina)
	velocity.x = facing_direction * ROLL_SPEED

func _process_roll(_delta):
	if roll_timer <= 0: current_state = State.IDLE

func _start_attack():
	if !equipped_weapon: return
	current_state = State.ATTACK
	attack_timer = equipped_weapon.attack_duration
	current_stamina -= equipped_weapon.stamina_cost
	stamina_changed.emit(current_stamina)
	if hitbox: hitbox.damage = equipped_weapon.damage

func _process_attack(delta):
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0, FRICTION * 0.4 * delta)
	if attack_timer <= 0: current_state = State.IDLE

func take_damage(amount: float):
	if current_state == State.ROLL or current_health <= 0: return
	
	current_health = clamp(current_health - amount, 0, max_health)
	health_changed.emit(current_health)
	
	# Flash sprite red
	var tw = create_tween()
	sprite.modulate = Color(5, 0.5, 0.5)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	
	if current_health <= 0: die()

func die():
	get_tree().reload_current_scene()

# --- UTILS ---
func _update_timers(delta):
	coyote_timer = COYOTE_TIME if is_on_floor() else coyote_timer - delta
	jump_buffer_timer -= delta
	if roll_timer > 0: roll_timer -= delta
	if attack_timer > 0: attack_timer -= delta
	if stun_timer > 0: stun_timer -= delta

func _regen_stats(delta):
	if current_state != State.ROLL and current_state != State.ATTACK:
		current_stamina = move_toward(current_stamina, max_stamina, stamina_regen * delta)
		stamina_changed.emit(current_stamina)
	
	current_health = move_toward(current_health, max_health, health_regen * delta)
	health_changed.emit(current_health)
	
	current_mana = move_toward(current_mana, max_mana, mana_regen * delta)
	mana_changed.emit(current_mana)

func _handle_mouse_flip():
	if current_state != State.ROLL and current_state != State.HURT:
		var is_left = get_global_mouse_position().x < global_position.x
		sprite.flip_h = is_left
		if wings: wings.flip_h = is_left

func _apply_gravity(delta):
	var mult = 1.6 if velocity.y > 0 else 1.0
	velocity.y += gravity * mult * delta

func _update_animations():
	match current_state:
		State.IDLE: sprite.play("idle")
		State.MOVE: sprite.play("run")
		State.ATTACK: sprite.play("attack")
		State.ROLL: sprite.play("roll")
		State.FLY:
			sprite.play("jump")
			if wings:
				wings.visible = true
				wings.play("fly")
	
	if current_state != State.FLY and wings:
		wings.visible = false

func _process_hurt(delta):
	_apply_gravity(delta)
	if stun_timer <= 0: current_state = State.IDLE
