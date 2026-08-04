class_name Fx
extends RefCounted

## 가벼운 일회성 이펙트. 전부 코드로 만들고 스스로 소멸한다.


## 총알 궤적. 짧게 번쩍이고 사라진다.
static func tracer(host: Node, from: Vector3, to: Vector3, color: Color = Color(1.0, 0.9, 0.6)) -> void:
	if host == null or not host.is_inside_tree():
		return
	var length := from.distance_to(to)
	if length < 0.05:
		return
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035, 0.035, length)
	mi.mesh = mesh
	var mat := Build.emissive(color, 4.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	host.get_tree().current_scene.add_child(mi)
	mi.global_position = from.lerp(to, 0.5)
	mi.look_at(to, Vector3.UP)
	var tween := mi.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.12)
	tween.tween_callback(mi.queue_free)


## 붉은 레이저 조준선. 스나이퍼의 예고 텔.
static func laser(host: Node, from: Vector3, to: Vector3, duration: float) -> MeshInstance3D:
	if host == null or not host.is_inside_tree():
		return null
	var length := from.distance_to(to)
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.02, 0.02, length)
	mi.mesh = mesh
	var mat := Build.emissive(Color(1.0, 0.15, 0.12), 5.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color.a = 0.75
	mi.material_override = mat
	host.get_tree().current_scene.add_child(mi)
	mi.global_position = from.lerp(to, 0.5)
	mi.look_at(to, Vector3.UP)
	var tween := mi.create_tween()
	tween.tween_interval(duration)
	tween.tween_callback(mi.queue_free)
	return mi


## 피격 스플래시.
static func hit_puff(host: Node, at: Vector3, color: Color = Color(0.7, 0.1, 0.12)) -> void:
	if host == null or not host.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mi.mesh = mesh
	var mat := Build.material(color)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	host.get_tree().current_scene.add_child(mi)
	mi.global_position = at
	var tween := mi.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mi, "scale", Vector3.ONE * 2.4, 0.25)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.chain().tween_callback(mi.queue_free)


## 발밑에서 퍼지는 붉은 파문. 시야 밖에서도 바닥 빛으로 위치를 알린다.
static func ground_ring(host: Node, at: Vector3, color: Color) -> void:
	if host == null or not host.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.62
	mesh.outer_radius = 0.80
	mi.mesh = mesh
	var mat := Build.emissive(color, 4.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	host.get_tree().current_scene.add_child(mi)
	mi.global_position = at + Vector3.UP * 0.06
	var tween := mi.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mi, "scale", Vector3(4.5, 1.0, 4.5), 0.75)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.75)
	tween.chain().tween_callback(mi.queue_free)


## 첫 정체 노출 때만 시간을 잠깐 늦춘다.
## 이 순간이 곧 게임의 규칙 설명이라, 놓치면 배울 기회 자체가 사라진다.
static func reveal_slowmo(host: Node) -> void:
	if host == null or not host.is_inside_tree():
		return
	if GameState.known_count() > 0 or Engine.time_scale < 0.99:
		return
	Engine.time_scale = 0.35
	var tree := host.get_tree()
	var timer := tree.create_timer(0.45, true, false, true)
	timer.timeout.connect(func() -> void: Engine.time_scale = 1.0)


## 폭발. 배달 킬러의 폭탄과 전투기 미사일에 쓴다.
static func explosion(host: Node, at: Vector3, radius: float) -> void:
	if host == null or not host.is_inside_tree():
		return
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius * 0.35
	mesh.height = radius * 0.7
	mi.mesh = mesh
	var mat := Build.emissive(Color(1.0, 0.55, 0.15), 5.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = mat
	host.get_tree().current_scene.add_child(mi)
	mi.global_position = at
	var tween := mi.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mi, "scale", Vector3.ONE * 2.6, 0.4)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.4)
	tween.chain().tween_callback(mi.queue_free)
