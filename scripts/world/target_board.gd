class_name TargetBoard
extends StaticBody3D

## 병원 안 연습 과녁.
##
## "멈춰야 쏠 수 있다"는 규칙을 문장으로 읽히는 대신 직접 해보게 만든다.
## 굴리면서 쏘려 하면 조준선이 막히고, 손을 떼면 맞는다 — 두 번만 해보면 안다.
## 맞으면 넘어가고 초록으로 바뀐다. 피드백은 즉시, 말은 없이.

var _face: MeshInstance3D
var _rings: Array[MeshInstance3D] = []
var _down: bool = false
var _stand: Node3D


static func create(at: Vector3) -> TargetBoard:
	var t := TargetBoard.new()
	t.set_script(load("res://scripts/world/target_board.gd"))
	t.name = "TargetBoard"
	t.position = at
	return t


func _ready() -> void:
	add_to_group("target_board")
	collision_layer = Build.LAYER_NPC
	collision_mask = 0

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 1.1, 0.14)
	cs.shape = shape
	cs.position = Vector3(0.0, 1.15, 0.0)
	add_child(cs)

	_stand = Node3D.new()
	add_child(_stand)
	Build.cylinder(_stand, 0.05, 0.62, Vector3(0.0, 0.31, 0.0), Color(0.35, 0.36, 0.40), false)

	var board := Node3D.new()
	board.position = Vector3(0.0, 1.15, 0.0)
	_stand.add_child(board)
	_face = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.1, 1.1, 0.08)
	_face.mesh = mesh
	_face.material_override = Build.material(Color(0.93, 0.92, 0.88))
	board.add_child(_face)
	# 동심원 — 쏘라는 신호는 모양만으로 충분하다.
	var radii := [0.44, 0.30, 0.16]
	var colors := [Color(0.85, 0.20, 0.18), Color(0.95, 0.93, 0.90), Color(0.85, 0.20, 0.18)]
	for i: int in radii.size():
		var ring := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = radii[i]
		cyl.bottom_radius = radii[i]
		cyl.height = 0.02
		ring.mesh = cyl
		ring.material_override = Build.material(colors[i])
		ring.rotation.x = PI * 0.5
		ring.position = Vector3(0.0, 0.0, -0.05 - 0.005 * float(i))
		board.add_child(ring)
		_rings.append(ring)


func take_bullet(_damage: float, point: Vector3) -> void:
	if _down:
		return
	_down = true
	Fx.hit_puff(self, point, Color(1.0, 0.85, 0.3))
	for ring: MeshInstance3D in _rings:
		var mat := ring.material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = Color(0.35, 0.95, 0.45)
	var tween := create_tween()
	tween.tween_property(_stand, "rotation:x", deg_to_rad(-78.0), 0.35).set_trans(Tween.TRANS_BACK)


func reset_board() -> void:
	_down = false
	_stand.rotation.x = 0.0
	var colors := [Color(0.85, 0.20, 0.18), Color(0.95, 0.93, 0.90), Color(0.85, 0.20, 0.18)]
	for i: int in _rings.size():
		var mat := _rings[i].material_override as StandardMaterial3D
		if mat != null:
			mat.albedo_color = colors[i]
