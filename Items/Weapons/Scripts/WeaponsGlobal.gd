extends Resource
class_name WeaponData

@export var weapon_name: String = "New Weapon"
@export var damage: float = 10.0
@export var stamina_cost: float = 15.0
@export var attack_duration: float = 0.4
@export var sprite: Texture2D # The item icon
@export var animation_name: String = "attack" # e.g., "swing_sword", "thrust_spear"
