extends Resource
class_name WeaponData

@export var weapon_name: String = "Basic Weapon"
@export var base_damage: float = 10.0
@export var knockback_force: float = 100.0
@export var attack_duration: float = 0.3
@export var stamina_cost: float = 15.0
@export var poise_damage: float = 5.0
@export var attack_cooldown: float = 0.5

# Visual/Audio properties
@export var attack_animation: String = "attack"
@export var hit_sound: AudioStream
@export var swish_sound: AudioStream
