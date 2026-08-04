class_name Helicopter
extends Node3D

## 수배 4단계에서 뜨는 경찰 헬기 (문서 7절).
##
## 격추할 수는 있다. 하지만 격추하면 전투기가 오고, 그때는 끝이다.
## 플레이어에게 "이길 수 있지만 이기면 안 되는" 선택지를 하나 준다.

const MAX_HP := 260.0
const HOVER_HEIGHT := 16.0
const FOLLOW_SPEED := 7.0
const FIRE_INTERVAL := 1.15
const DAMAGE := 12.0

var hp: float = MAX_HP
var player: WheelchairPlayer = null
var alive: bool = true

var _fire_timer: float = 1.8
var _rotor: Node3D
var _body_area: Area3D


static func create(target: WheelchairPlayer, spawn: Vector3) -> Helicopter:
	var h := Helicopter.new()
	h.set_script(load("res://scripts/npc/helicopter.gd"))
	h.name = "Helicopter"
	h.player = target
	h.position = spawn
	return h


func _ready() -> void:
	var hull := Color(0.16, 0.20, 0.34)
	Build.box(self, Vector3(2.2, 1.6, 5.4), Vector3.ZERO, hull, false)
	# look_at 은 -Z 를 표적으로 향하게 하므로 꼬리는 +Z 쪽이다.
	Build.box(self, Vector3(0.5, 0.9, 3.0), Vector3(0.0, 0.4, 3.8), hull, false)
	Build.box(self, Vector3(0.25, 0.25, 3.4), Vector3(0.0, 1.3, 0.0), Color(0.1, 0.1, 0.12), false)
	_rotor = Node3D.new()
	_rotor.position = Vector3(0.0, 1.5, 0.0)
	add_child(_rotor)
	Build.box(_rotor, Vector3(9.5, 0.1, 0.5), Vector3.ZERO, Color(0.13, 0.13, 0.15), false)
	Build.box(_rotor, Vector3(0.5, 0.1, 9.5), Vector3.ZERO, Color(0.13, 0.13, 0.15), false)
	var beam := SpotLight3D.new()
	beam.light_color = Color(1.0, 0.95, 0.8)
	beam.light_energy = 6.0
	beam.spot_range = 40.0
	beam.spot_angle = 22.0
	beam.rotation.x = -PI * 0.5
	add_child(beam)

	# 총알 판정을 받기 위한 물리 바디.
	var body := StaticBody3D.new()
	body.collision_layer = Build.LAYER_NPC
	body.collision_mask = 0
	body.set_script(load("res://scripts/npc/heli_hitbox.gd"))
	body.set("owner_heli", self)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(3.0, 2.4, 6.0)
	cs.shape = shape
	body.add_child(cs)
	add_child(body)

	EventBus.notify("경찰 헬기가 떴다. 격추하면 더 나빠진다.", Color(1.0, 0.45, 0.3))


func _process(delta: float) -> void:
	if not alive or player == null or not GameState.loop_active:
		return
	_rotor.rotate_y(28.0 * delta)
	var target := player.global_position + Vector3(0.0, HOVER_HEIGHT, -4.0)
	global_position = global_position.move_toward(target, FOLLOW_SPEED * delta)
	look_at(player.global_position, Vector3.UP, true)
	rotation.x = 0.0
	rotation.z = 0.0

	_fire_timer -= delta
	if _fire_timer <= 0.0:
		_fire_timer = FIRE_INTERVAL
		Fx.tracer(self, global_position, player.eye_position(), Color(0.7, 0.85, 1.0))
		player.take_damage(DAMAGE, global_position, "경찰 헬기", "")


func take_bullet(damage: float, point: Vector3) -> void:
	if not alive:
		return
	hp -= damage
	Fx.hit_puff(self, point, Color(0.9, 0.8, 0.3))
	if hp <= 0.0:
		_destroy()


func _destroy() -> void:
	alive = false
	Fx.explosion(self, global_position, 8.0)
	EventBus.notify("헬기 격추 — 전투기가 온다", Color(1.0, 0.2, 0.2))
	LoopManager.report_heli_destroyed()
	queue_free()
