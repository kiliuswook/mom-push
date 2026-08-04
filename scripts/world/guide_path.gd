class_name GuidePath
extends Node3D

## 바닥을 따라 흐르는 화살표와 탈출 지점의 빛기둥.
##
## "어디로 가야 하나"는 문장으로 설명할 게 아니라 바닥이 말해줘야 한다.
## 화살표는 진행 방향으로 흐르는 파동처럼 밝아진다 — 읽는 게 아니라 따라가는 신호.

const SPACING := 6.0
const Z_START := 6.0
const Z_END := 146.0
## 광장 분수를 피해 돌아가는 구간.
const FOUNTAIN_Z := Vector2(123.0, 139.0)
const FOUNTAIN_OFFSET := 5.5

var _materials: Array[StandardMaterial3D] = []
var _beacon: StandardMaterial3D
var _phase: float = 0.0
var _dim: float = 1.0


static func create() -> GuidePath:
	var g := GuidePath.new()
	g.set_script(load("res://scripts/world/guide_path.gd"))
	g.name = "GuidePath"
	return g


func _ready() -> void:
	var z := Z_START
	while z <= Z_END:
		var x := 0.0
		if z >= FOUNTAIN_Z.x and z <= FOUNTAIN_Z.y:
			x = FOUNTAIN_OFFSET
		_chevron(Vector3(x, 0.03, z))
		z += SPACING
	_build_beacon()
	EventBus.loop_started.connect(_on_loop_started)


## +Z 를 가리키는 납작한 갈매기표.
func _chevron(at: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = at
	for side: int in [-1, 1]:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.30, 0.02, 2.1)
		mi.mesh = mesh
		var mat := Build.emissive(Color(0.45, 0.95, 1.0), 1.4)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color.a = 0.85
		mi.material_override = mat
		mi.position = Vector3(0.62 * float(side), 0.0, 0.0)
		mi.rotation.y = deg_to_rad(-34.0 * float(side))
		root.add_child(mi)
		_materials.append(mat)


## 탈출 지점 빛기둥. 건물 너머에서도 보이라고 높게 세운다.
func _build_beacon() -> void:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.55
	mesh.bottom_radius = 0.9
	mesh.height = 46.0
	mi.mesh = mesh
	_beacon = Build.emissive(Color(0.40, 1.0, 0.60), 2.2)
	_beacon.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beacon.albedo_color.a = 0.30
	_beacon.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = _beacon
	mi.position = Town.ESCAPE_POSITION + Vector3(0.0, 23.0, 0.0)
	add_child(mi)


func _on_loop_started(index: int) -> void:
	# 길을 외운 뒤에는 배경으로 물러난다.
	_dim = 1.0 if index <= 3 else 0.45


func _process(delta: float) -> void:
	_phase += delta * 3.2
	var count := _materials.size()
	for i: int in count:
		# 두 개씩 한 쌍이므로 쌍 단위로 위상을 준다.
		var wave := sin(_phase - float(i / 2) * 0.7)
		_materials[i].emission_energy_multiplier = (0.5 + 1.5 * maxf(wave, 0.0)) * _dim
	if _beacon != null:
		# 빛기둥 색이 곧 탈출 가능 여부다. 붉으면 아직 킬러가 남았다는 뜻.
		# "모든 킬러를 제거해야 한다"를 문장 없이 전하는 유일한 신호.
		var ready_to_leave := GameState.all_killers_down()
		var target := Color(0.40, 1.0, 0.60) if ready_to_leave else Color(1.0, 0.34, 0.28)
		_beacon.albedo_color = Color(target.r, target.g, target.b, _beacon.albedo_color.a)
		_beacon.emission = target
		_beacon.emission_energy_multiplier = (1.6 + 0.8 * sin(_phase * 0.5)) * _dim
