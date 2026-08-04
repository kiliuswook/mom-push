class_name Rail
extends Area3D

## 난간. 밀리는 중에 올라타면 마찰이 사라지고 레일 방향으로 미끄러진다 (문서 10절).
## 스케이트보드 트릭처럼 고지대에서 단숨에 내려오는 지름길.

@export var direction: Vector3 = Vector3.FORWARD


static func create(size: Vector3, pos: Vector3, rot: Vector3, dir: Vector3) -> Rail:
	var r := Rail.new()
	r.set_script(load("res://scripts/world/rail.gd"))
	r.name = "Rail"
	r.direction = dir.normalized()
	r.collision_layer = Build.LAYER_TRIGGER
	r.collision_mask = Build.LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	r.add_child(cs)
	r.position = pos
	r.rotation = rot
	return r


func _ready() -> void:
	body_entered.connect(_on_entered)
	body_exited.connect(_on_exited)


func _on_entered(body: Node3D) -> void:
	var p := body as WheelchairPlayer
	if p == null:
		return
	if p.drive != Enums.Drive.PUSHED and p.drive != Enums.Drive.COAST:
		return
	p.enter_rail(direction)


func _on_exited(body: Node3D) -> void:
	var p := body as WheelchairPlayer
	if p != null:
		p.exit_rail()
