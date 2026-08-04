class_name Bomb
extends Node3D

## 피자 배달부의 폭탄 상자. 포물선으로 날아와 반경 피해를 준다.
## 날아오는 동안 피할 시간이 있다 — 그래서 배달 킬러는 "먼저 보면 살 수 있는" 킬러다.

const FLIGHT_TIME := 1.15
const ARC_HEIGHT := 3.2
const BLAST_RADIUS := 4.5

var _from: Vector3
var _to: Vector3
var _damage: float = 0.0
var _t: float = 0.0
var _source: Npc = null
var _armed: bool = false


static func create() -> Bomb:
	var b := Bomb.new()
	b.set_script(load("res://scripts/npc/bomb.gd"))
	b.name = "Bomb"
	return b


func launch(from: Vector3, to: Vector3, damage: float, source: Npc) -> void:
	_from = from
	_to = to
	_damage = damage
	_source = source
	_armed = true
	global_position = from
	Build.box(self, Vector3(0.5, 0.18, 0.5), Vector3.ZERO, Color(0.92, 0.88, 0.78), false)
	var blink := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.08
	mesh.height = 0.16
	blink.mesh = mesh
	blink.material_override = Build.emissive(Color(1.0, 0.2, 0.15), 4.0)
	blink.position = Vector3(0.0, 0.16, 0.0)
	add_child(blink)


func _process(delta: float) -> void:
	if not _armed:
		return
	_t += delta / FLIGHT_TIME
	if _t >= 1.0:
		_detonate()
		return
	var flat := _from.lerp(_to, _t)
	flat.y += sin(_t * PI) * ARC_HEIGHT
	global_position = flat
	rotate_x(6.0 * delta)
	rotate_y(4.0 * delta)


func _detonate() -> void:
	_armed = false
	Fx.explosion(self, global_position, BLAST_RADIUS)
	var scene_root := get_tree().current_scene
	if scene_root != null:
		for node: Node in get_tree().get_nodes_in_group("blast_target"):
			var body := node as Node3D
			if body == null:
				continue
			var dist := body.global_position.distance_to(global_position)
			if dist > BLAST_RADIUS:
				continue
			var falloff := 1.0 - (dist / BLAST_RADIUS)
			if body.has_method("take_damage"):
				var slot: String = _source.slot_id if _source != null and is_instance_valid(_source) else ""
				body.take_damage(_damage * falloff, global_position, "배달 킬러의 폭탄", slot)
	queue_free()
