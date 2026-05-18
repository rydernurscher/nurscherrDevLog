extends CharacterBody2D

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
var current_weapon_key: String = "BareFist"
var damage_tween: Tween
var is_godmode_active: bool = false


@onready var sprite = $PlayerSprite
@onready var wings = $PlayerSprite/Wings if has_node("PlayerSprite/Wings") else null
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
	
	if has_node("Hurtbox"):
		$Hurtbox.damage_taken.connect(_on_hurtbox_damage_taken)

func _setup_ui():
	if ui:
		ui.set_max_stats(max_health, max_mana, max_stamina)
		if not health_changed.is_connected(ui.update_health):
			health_changed.connect(ui.update_health)
		if not mana_changed.is_connected(ui.update_mana):
			mana_changed.connect(ui.update_mana)
		if not stamina_changed.is_connected(ui.update_stamina):
			stamina_changed.connect(ui.update_stamina)
		
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
	
	if dir != 0:
		velocity.x = move_toward(velocity.x, dir * SPEED, ACCELERATION * delta)
		facing_direction = sign(dir)
		if is_on_floor(): current_state = State.MOVE
	else:
		velocity.x = move_toward(velocity.x, 0, FRICTION * delta)
		if is_on_floor(): current_state = State.IDLE

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

	if Input.is_action_just_pressed("roll") and is_on_floor() and current_stamina >= 20:
		_start_roll()
	elif Input.is_action_just_pressed("attack") and current_stamina >= 15:
		_start_attack()
	
	if Input.is_action_pressed("mine"):
		_handle_mining()

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_H:
			take_damage(20.0, 0.0, global_position)
		if event.keycode == KEY_M:
			current_mana = max(0, current_mana - 15)
			mana_changed.emit(current_mana)
		if event.keycode == KEY_0:
			is_godmode_active = !is_godmode_active
			if is_godmode_active:
				max_health = 15000
				current_health = max_health
			else:
				max_health = 100
				current_health = max_health
			
			ui.set_max_stats(max_health, max_mana, max_stamina)
			health_changed.emit(current_health)

func _handle_mining():
	if !generator: return
	
	var m_pos = get_global_mouse_position()
	if global_position.distance_to(m_pos) > 48.0: return
	
	if !generator.can_player_mine_at(m_pos):
		return
	
	var map_pos = generator.base_layer.local_to_map(m_pos)
	
	if generator.world_data.has(map_pos):
		generator.world_data.erase(map_pos)
		for x in range(-1, 2):
			for y in range(-1, 2):
				var target_pos = map_pos + Vector2i(x, y)
				generator.update_tile_at(target_pos)

func _start_roll():
	current_state = State.ROLL
	roll_timer = ROLL_DURATION
	current_stamina -= 20.0
	stamina_changed.emit(current_stamina)
	velocity.x = facing_direction * ROLL_SPEED
	if has_node("Hurtbox"): $Hurtbox.i_frames_active = true

func _process_roll(_delta):
	if roll_timer <= 0: 
		current_state = State.IDLE
		if has_node("Hurtbox"): $Hurtbox.i_frames_active = false

func _start_attack():
	if !equipped_weapon: return
	var data = equipped_weapon.Weapons.get(current_weapon_key)
	if !data: return

	current_state = State.ATTACK
	attack_timer = data.attack_duration
	current_stamina -= data.stamina_cost
	stamina_changed.emit(current_stamina)
	
	if hitbox:
		hitbox.damage = data.damage
		hitbox.knockback_force = data.knockback
		hitbox.poise_damage = data.poise_damage
		hitbox.enabled_hitbox(true)

func _process_attack(delta):
	_apply_gravity(delta)
	velocity.x = move_toward(velocity.x, 0, FRICTION * 0.4 * delta)
	if attack_timer <= 0: 
		current_state = State.IDLE
		if hitbox: hitbox.enabled_hitbox(false)

func _on_hurtbox_damage_taken(amount: float, knockback: float, hitbox_pos: Vector2, _poise_dmg: float):
	take_damage(amount, knockback, hitbox_pos)

func take_damage(amount: float, knockback: float = 0.0, source_pos: Vector2 = Vector2.ZERO):
	# FIX: Added State.HURT to immunity check to prevent rapid-fire damage during hitstun
	if current_state == State.ROLL or current_state == State.HURT or current_health <= 0: return
	
	current_health = clamp(current_health - amount, 0, max_health)
	health_changed.emit(current_health)
	
	if knockback > 0:
		var dir = sign(global_position.x - source_pos.x)
		if dir == 0: dir = 1
		velocity.x = dir * knockback
		velocity.y = -knockback * 0.4
		current_state = State.HURT
		stun_timer = 0.4
	
	if damage_tween and damage_tween.is_running():
		damage_tween.kill()
	
	sprite.modulate = Color(5, 0, 0)
	damage_tween = create_tween()
	damage_tween.tween_property(sprite, "modulate", Color.WHITE, 0.6)
	
	if current_health <= 0: die()

func die():
	generator.spawn_player()
	current_health += max_health
	health_changed.emit(current_health)

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
		if hitbox:
			hitbox.position.x = -21 if is_left else 21

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
	velocity.x = move_toward(velocity.x, 0, FRICTION * 0.5 * delta)
	if stun_timer <= 0: current_state = State.IDLE
