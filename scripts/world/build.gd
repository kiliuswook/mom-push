class_name Build
extends RefCounted

## 절차적 지오메트리 헬퍼.
##
## 이 프로젝트는 외부 3D 에셋을 쓰지 않고 프리미티브로 마을을 조립한다.
## 문서 13절의 "리얼한 공간 위의 병맛 액션" 톤은 색/비례로만 잡는다.

const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_NPC := 4
const LAYER_TRIGGER := 8


static func material(color: Color, roughness: float = 0.94, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m


static func emissive(color: Color, energy: float = 1.6) -> StandardMaterial3D:
	var m := material(color)
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## 충돌하는 상자. solid=false 면 장식용(충돌 없음).
static func box(
	parent: Node,
	size: Vector3,
	pos: Vector3,
	color: Color,
	solid: bool = true,
	rot: Vector3 = Vector3.ZERO,
	node_name: String = ""
) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_WORLD
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		cs.shape = shape
		body.add_child(cs)
		root = body
	else:
		root = Node3D.new()
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = material(color)
	root.add_child(mi)
	if node_name != "":
		root.name = node_name
	parent.add_child(root)
	root.position = pos
	root.rotation = rot
	return root


static func cylinder(
	parent: Node,
	radius: float,
	height: float,
	pos: Vector3,
	color: Color,
	solid: bool = true,
	rot: Vector3 = Vector3.ZERO
) -> Node3D:
	var root: Node3D
	if solid:
		var body := StaticBody3D.new()
		body.collision_layer = LAYER_WORLD
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		body.add_child(cs)
		root = body
	else:
		root = Node3D.new()
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mi.mesh = mesh
	mi.material_override = material(color)
	root.add_child(mi)
	parent.add_child(root)
	root.position = pos
	root.rotation = rot
	return root


## 계단. 한 칸씩 실제 충돌 상자를 쌓는다.
## 휠체어는 직접 오를 수 없고 (문서 10절) 엄마가 들어올려야 한다.
static func stairs(
	parent: Node,
	steps: int,
	step_rise: float,
	step_run: float,
	width: float,
	base_pos: Vector3,
	color: Color,
	yaw: float = 0.0
) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = base_pos
	root.rotation.y = yaw
	for i: int in steps:
		var h := step_rise * float(i + 1)
		box(
			root,
			Vector3(width, h, step_run),
			Vector3(0.0, h * 0.5, step_run * (float(i) + 0.5)),
			color.lerp(Color.BLACK, 0.04 * float(i % 2))
		)
	return root


## 경사로. 휠체어가 스스로 오를 수 있는 유일한 수직 이동 수단.
static func ramp(
	parent: Node,
	length: float,
	width: float,
	rise: float,
	base_pos: Vector3,
	color: Color,
	yaw: float = 0.0
) -> Node3D:
	var angle := atan2(rise, length)
	var span := sqrt(length * length + rise * rise)
	var root := Node3D.new()
	parent.add_child(root)
	root.position = base_pos
	root.rotation.y = yaw
	box(
		root,
		Vector3(width, 0.35, span),
		Vector3(0.0, rise * 0.5, length * 0.5),
		color,
		true,
		Vector3(-angle, 0.0, 0.0)
	)
	return root


## 3D 텍스트 라벨. 안내 표지판과 NPC 이름표에 쓴다.
static func label(
	parent: Node,
	text: String,
	pos: Vector3,
	size: float = 0.5,
	color: Color = Color.WHITE,
	billboard: bool = true
) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = size / 64.0
	l.modulate = color
	l.outline_size = 12
	l.outline_modulate = Color(0.0, 0.0, 0.0, 0.85)
	if billboard:
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.double_sided = true
	parent.add_child(l)
	l.position = pos
	return l


## 월드에 떠 있는 키캡. 문장 대신 "이 키를 눌러라"만 전한다.
## 위아래로 살짝 떠다녀서 배경과 구분된다.
static func key_prompt(parent: Node, key_label: String, pos: Vector3) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = pos
	var cap := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.52, 0.52, 0.10)
	cap.mesh = mesh
	cap.material_override = emissive(Color(0.14, 0.16, 0.20), 0.6)
	root.add_child(cap)
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(0.62, 0.62, 0.06)
	frame.mesh = frame_mesh
	frame.material_override = emissive(Color(1.0, 0.86, 0.45), 2.2)
	frame.position = Vector3(0.0, 0.0, -0.03)
	root.add_child(frame)
	var glyph := label(root, key_label, Vector3(0.0, 0.0, 0.09), 0.42, Color(1.0, 0.95, 0.75))
	glyph.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	# 라벨과 캡이 항상 플레이어를 향하도록 루트만 빌보드처럼 돌린다.
	root.set_script(load("res://scripts/world/billboard_bob.gd"))
	return root


## 원기둥형 트리거 영역.
static func trigger(parent: Node, radius: float, height: float, pos: Vector3, node_name: String) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.collision_layer = LAYER_TRIGGER
	area.collision_mask = LAYER_PLAYER
	area.monitoring = true
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	cs.shape = shape
	area.add_child(cs)
	parent.add_child(area)
	area.position = pos
	return area


## 상자형 트리거 영역.
static func trigger_box(parent: Node, size: Vector3, pos: Vector3, node_name: String) -> Area3D:
	var area := Area3D.new()
	area.name = node_name
	area.collision_layer = LAYER_TRIGGER
	area.collision_mask = LAYER_PLAYER
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	area.add_child(cs)
	parent.add_child(area)
	area.position = pos
	return area
