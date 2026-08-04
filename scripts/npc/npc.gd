class_name Npc
extends CharacterBody3D

## 마을에 서 있는 모든 사람. 민간인도, 킬러도, 경찰도 같은 클래스다.
##
## 문서 12절: "킬러는 단순 적이 아니라 정체를 알아내야 하는 함정이다."
## 그래서 외형(disguise)과 정체(kind/killer_type)는 완전히 분리되어 있고,
## 같은 위장을 쓴 민간인이 반드시 함께 존재한다.
##
## 정체를 알아내는 경로는 셋뿐이다.
##   1) 텔을 관찰한다 — 힐끗 보기, 코스 이탈
##   2) 무기를 꺼내는 순간(reveal)을 본다 — 살아서 알아내는 정공법
##   3) 죽는다 — 가장 확실하지만 루프를 하나 태운다

enum State { PATROL, IDLE, ENGAGE, ATTACK, FLEE, DEAD }

const EYE_HEIGHT := 1.6
const VEHICLE_EYE := 1.1

var slot_id: String = ""
var disguise: String = "resident"
var kind: Enums.NpcKind = Enums.NpcKind.CIVILIAN
var killer_type: Enums.KillerType = Enums.KillerType.NONE
var zone: Enums.Zone = Enums.Zone.HOSPITAL
var route: Array[Vector3] = []
var home: Vector3 = Vector3.ZERO
var is_vehicle: bool = false
var elevated: bool = false

var hp: float = Balance.NPC_MAX_HP
var state: State = State.PATROL
var revealed: bool = false
var player: WheelchairPlayer = null

var _route_index: int = 0
var _idle_timer: float = 0.0
var _attack_timer: float = 0.0
var _windup: float = 0.0
var _glance_timer: float = 0.0
var _glance_left: float = 0.0
var _laser: MeshInstance3D = null
var _visual: Node3D
var _weapon_visual: Node3D
var _marker: Node3D
var _label: Label3D
var _facing: float = 0.0
var _ambushing: bool = false


static func create() -> Npc:
	var n := Npc.new()
	n.set_script(load("res://scripts/npc/npc.gd"))
	return n


# --- 셋업 -------------------------------------------------------------------


## 카탈로그 슬롯에서 만든다. 킬러 여부는 GameState 가 정한다.
func setup_from_slot(slot: Dictionary, target: WheelchairPlayer) -> void:
	slot_id = String(slot["id"])
	disguise = String(slot["disguise"])
	zone = slot["zone"]
	home = slot["pos"]
	player = target
	is_vehicle = NpcCatalog.VEHICLE_SLOTS.has(slot_id)
	elevated = home.y > 1.0
	route.clear()
	for point: Vector3 in slot.get("route", []):
		route.append(point)
	killer_type = GameState.killer_type_of(slot_id)
	kind = Enums.NpcKind.KILLER if killer_type != Enums.KillerType.NONE else Enums.NpcKind.CIVILIAN
	name = "Npc_%s" % slot_id
	_glance_timer = randf_range(1.0, Balance.TELL_GLANCE_INTERVAL)


## 수배 단계에 따라 출동하는 경찰 / SWAT.
func setup_responder(responder_kind: Enums.NpcKind, spawn: Vector3, target: WheelchairPlayer) -> void:
	kind = responder_kind
	killer_type = Enums.KillerType.NONE
	slot_id = ""
	disguise = "police" if responder_kind == Enums.NpcKind.POLICE else "swat"
	home = spawn
	player = target
	hp = Balance.POLICE_HP if responder_kind == Enums.NpcKind.POLICE else Balance.SWAT_HP
	revealed = true
	state = State.ENGAGE
	name = "Responder"


func _ready() -> void:
	collision_layer = Build.LAYER_NPC
	collision_mask = Build.LAYER_WORLD
	floor_max_angle = deg_to_rad(50.0)
	global_position = home
	_facing = rotation.y
	_build_visual()
	_refresh_marker()
	EventBus.knowledge_gained.connect(_on_knowledge_gained)


func _build_visual() -> void:
	var cs := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	if is_vehicle:
		shape.radius = 1.0
		shape.height = 1.6
		cs.position = Vector3(0.0, 0.8, 0.0)
	else:
		shape.radius = 0.32
		shape.height = 1.55
		cs.position = Vector3(0.0, 0.85, 0.0)
	cs.shape = shape
	add_child(cs)

	_visual = Node3D.new()
	add_child(_visual)

	var data: Dictionary = NpcCatalog.DISGUISES.get(disguise, NpcCatalog.DISGUISES["resident"])
	var body: Color = data["body"]
	var accent: Color = data["accent"]

	if is_vehicle:
		Build.box(_visual, Vector3(2.0, 0.75, 4.4), Vector3(0.0, 0.62, 0.0), body, false)
		Build.box(_visual, Vector3(1.75, 0.65, 2.1), Vector3(0.0, 1.28, -0.25), accent, false)
		Build.cylinder(_visual, 0.36, 0.24, Vector3(-1.0, 0.36, 1.5), Color(0.08, 0.08, 0.09), false, Vector3(0, 0, PI * 0.5))
		Build.cylinder(_visual, 0.36, 0.24, Vector3(1.0, 0.36, 1.5), Color(0.08, 0.08, 0.09), false, Vector3(0, 0, PI * 0.5))
		Build.cylinder(_visual, 0.36, 0.24, Vector3(-1.0, 0.36, -1.5), Color(0.08, 0.08, 0.09), false, Vector3(0, 0, PI * 0.5))
		Build.cylinder(_visual, 0.36, 0.24, Vector3(1.0, 0.36, -1.5), Color(0.08, 0.08, 0.09), false, Vector3(0, 0, PI * 0.5))
		if disguise == "taxi":
			Build.box(_visual, Vector3(0.7, 0.22, 0.3), Vector3(0.0, 1.7, -0.2), Color(0.95, 0.95, 0.95), false)
	else:
		Build.box(_visual, Vector3(0.48, 0.78, 0.28), Vector3(0.0, 1.05, 0.0), body, false)
		Build.box(_visual, Vector3(0.40, 0.48, 0.26), Vector3(0.0, 0.40, 0.0), accent.darkened(0.35), false)
		Build.cylinder(_visual, 0.16, 0.28, Vector3(0.0, 1.6, 0.0), Color(0.92, 0.78, 0.68), false)
		Build.box(_visual, Vector3(0.11, 0.11, 0.5), Vector3(-0.29, 1.12, 0.12), body.lightened(0.1), false)
		Build.box(_visual, Vector3(0.11, 0.11, 0.5), Vector3(0.29, 1.12, 0.12), body.lightened(0.1), false)
		_build_prop(String(data.get("prop", "none")), accent)

	# 무기는 정체를 드러내기 전까지 숨어 있다.
	_weapon_visual = Node3D.new()
	_weapon_visual.visible = false
	_visual.add_child(_weapon_visual)
	var muzzle_y := VEHICLE_EYE if is_vehicle else 1.15
	Build.box(_weapon_visual, Vector3(0.09, 0.09, 0.42), Vector3(0.30, muzzle_y, 0.34), Color(0.12, 0.12, 0.14), false)

	_label = Build.label(
		self,
		NpcCatalog.disguise_name(disguise),
		Vector3(0.0, 2.15 if not is_vehicle else 2.0, 0.0),
		0.22,
		Color(0.92, 0.92, 0.95)
	)

	_marker = Node3D.new()
	_marker.visible = false
	add_child(_marker)
	var diamond := MeshInstance3D.new()
	var dm := SphereMesh.new()
	dm.radius = 0.18
	dm.height = 0.36
	dm.radial_segments = 4
	dm.rings = 2
	diamond.mesh = dm
	diamond.material_override = Build.emissive(Color(1.0, 0.2, 0.2), 3.0)
	diamond.position = Vector3(0.0, 2.5, 0.0)
	_marker.add_child(diamond)


func _build_prop(prop: String, accent: Color) -> void:
	match prop:
		"broom":
			Build.cylinder(_visual, 0.03, 1.3, Vector3(0.34, 0.75, 0.30), Color(0.55, 0.40, 0.24), false)
			Build.box(_visual, Vector3(0.34, 0.12, 0.12), Vector3(0.34, 0.12, 0.30), Color(0.75, 0.62, 0.30), false)
		"box":
			Build.box(_visual, Vector3(0.46, 0.16, 0.46), Vector3(0.0, 1.12, 0.42), accent, false)
		"bag":
			Build.box(_visual, Vector3(0.24, 0.30, 0.16), Vector3(0.34, 0.85, 0.14), accent, false)
		"clipboard":
			Build.box(_visual, Vector3(0.22, 0.30, 0.03), Vector3(0.26, 1.05, 0.24), accent, false)
		_:
			pass


# --- 루프 -------------------------------------------------------------------


func _physics_process(delta: float) -> void:
	if state == State.DEAD or player == null:
		return
	if not GameState.loop_active:
		return

	if not elevated and not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity", 22.0) * delta
	elif not elevated:
		velocity.y = 0.0

	match kind:
		Enums.NpcKind.KILLER:
			_tick_killer(delta)
		Enums.NpcKind.CIVILIAN:
			_tick_civilian(delta)
		_:
			_tick_responder(delta)

	if not elevated:
		move_and_slide()
	if is_vehicle and not _ambushing:
		_confine_to_road()
	rotation.y = _facing


## 차량은 도로를 벗어나지 않는다. 인도로 올라오면 대응할 방법이 없어진다.
## 단 탈출 지점 매복 때는 예외 — 그때는 어차피 규칙이 무너지는 장면이다.
func _confine_to_road() -> void:
	global_position.x = clampf(
		global_position.x, -Balance.ROAD_HALF_WIDTH, Balance.ROAD_HALF_WIDTH
	)
	global_position.z = clampf(global_position.z, Balance.ROAD_Z_MIN, Balance.ROAD_Z_MAX)


# --- 민간인 -----------------------------------------------------------------


func _tick_civilian(delta: float) -> void:
	if state == State.FLEE:
		_move_away_from(player.global_position, Balance.NPC_FLEE_SPEED)
		return
	_patrol(delta, Balance.NPC_WALK_SPEED)


func _patrol(delta: float, speed: float) -> void:
	if elevated or route.is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
		_idle_timer -= delta
		return
	if _idle_timer > 0.0:
		_idle_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var target: Vector3 = route[_route_index]
	var to_target := target - global_position
	to_target.y = 0.0
	if to_target.length() <= Balance.NPC_WAYPOINT_TOLERANCE:
		_route_index = (_route_index + 1) % route.size()
		_idle_timer = randf_range(0.4, Balance.NPC_IDLE_TIME)
		return
	var dir := to_target.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(dir, delta)


func _move_toward_point(point: Vector3, speed: float, delta: float) -> void:
	var to_target := point - global_position
	to_target.y = 0.0
	if to_target.length() < 0.3:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var dir := to_target.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_face(dir, delta)


func _move_away_from(point: Vector3, speed: float) -> void:
	var dir := global_position - point
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	_facing = atan2(dir.x, dir.z)


# --- 킬러 -------------------------------------------------------------------


func _tick_killer(delta: float) -> void:
	var def: Dictionary = NpcCatalog.KILLER_DEFS[killer_type]
	var dist := global_position.distance_to(player.global_position)
	_attack_timer = maxf(0.0, _attack_timer - delta)

	if state == State.PATROL or state == State.IDLE:
		_tick_tell(delta, dist)
		_patrol(delta, float(def["speed"]) * 0.35 if is_vehicle else Balance.NPC_WALK_SPEED)
		# 눈뜨자마자 죽는 것은 억울한 죽음이 아니라 조작 불능이다.
		if LoopManager.grace_active():
			return
		if dist <= float(def["aggro"]) and _has_line_of_sight():
			_engage(def)
		return

	if state == State.ENGAGE or state == State.ATTACK:
		_tick_combat(delta, def, dist)


func _engage(def: Dictionary) -> void:
	state = State.ENGAGE
	_reveal()
	EventBus.npc_alerted.emit(slot_id)
	EventBus.tell_observed.emit(slot_id, String(def.get("tell", "")))
	# 정체를 드러낸 순간 지식이 된다. 죽지 않고도 배울 수 있는 유일한 경로.
	GameState.learn(slot_id, "정체를 드러내는 순간을 목격했다")


func _tick_combat(delta: float, def: Dictionary, dist: float) -> void:
	var attack_range := float(def["attack_range"])
	var speed := float(def["speed"])

	if killer_type == Enums.KillerType.SNIPER:
		_face_point(player.global_position, delta)
		if _has_line_of_sight():
			_charge_attack(delta, def)
		else:
			_windup = 0.0
			_clear_laser()
		return

	var approach := player.global_position
	if killer_type == Enums.KillerType.RUNNER:
		# 뒤에서 접근한다 (문서 12절).
		approach = player.global_position + player.back_direction() * 2.2

	if dist > attack_range:
		_move_toward_point(approach, speed, delta)
		_windup = 0.0
		_clear_laser()
	else:
		velocity.x = move_toward(velocity.x, 0.0, 26.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 26.0 * delta)
		_face_point(player.global_position, delta)
		if killer_type == Enums.KillerType.DRIVER:
			_ram_hit(def)
		elif _has_line_of_sight():
			_charge_attack(delta, def)

	# 드라이버는 사거리와 무관하게 부딪히면 친다.
	if killer_type == Enums.KillerType.DRIVER and dist <= 3.2:
		_ram_hit(def)


func _charge_attack(delta: float, def: Dictionary) -> void:
	if _attack_timer > 0.0:
		return
	_windup += delta
	var windup_time := float(def["windup"])
	if killer_type == Enums.KillerType.SNIPER and _laser == null and _windup > 0.05:
		_laser = Fx.laser(self, _eye(), player.eye_position(), windup_time)
	if _windup < windup_time:
		return
	_windup = 0.0
	_attack_timer = float(def["interval"])
	_clear_laser()
	_fire_at_player(def)


func _fire_at_player(def: Dictionary) -> void:
	var damage := float(def["damage"])
	if killer_type == Enums.KillerType.DELIVERY:
		_throw_bomb(damage)
		return
	if bool(def.get("ranged", true)):
		Fx.tracer(self, _eye(), player.eye_position(), Color(1.0, 0.6, 0.35))
	else:
		Fx.hit_puff(self, player.global_position + Vector3.UP, Color(0.85, 0.2, 0.2))
	player.take_damage(damage, global_position, _threat_name(), slot_id)


func _ram_hit(def: Dictionary) -> void:
	if _attack_timer > 0.0:
		return
	_attack_timer = float(def["interval"])
	Fx.hit_puff(self, player.global_position + Vector3.UP, Color(0.9, 0.4, 0.1))
	player.take_damage(float(def["damage"]), global_position, _threat_name(), slot_id)


func _throw_bomb(damage: float) -> void:
	var bomb := preload("res://scripts/npc/bomb.gd").create()
	get_tree().current_scene.add_child(bomb)
	bomb.launch(_eye(), player.global_position + Vector3.UP * 0.5, damage, self)


## 킬러가 정체를 드러낸다 — 이 게임에서 가장 중요한 0.5초.
## 여기서 무슨 일이 일어났는지 못 읽으면 게임 전체가 불공정해 보인다.
## 그래서 글자가 아니라 몸으로 알린다: 붉은 느낌표 + 발밑 파문 + 잠깐의 슬로우모션.
func _reveal() -> void:
	if revealed:
		return
	revealed = true
	if _weapon_visual != null:
		_weapon_visual.visible = true
	if _label != null:
		# 이름표는 "누구였는지" 기억용으로 남기고, 경보는 느낌표가 맡는다.
		_label.modulate = Color(1.0, 0.35, 0.30)
	_spawn_alert_mark()
	Fx.ground_ring(self, global_position, Color(1.0, 0.30, 0.25))
	Fx.reveal_slowmo(self)


## 머리 위 붉은 느낌표. 박스 두 개로 만든다.
func _spawn_alert_mark() -> void:
	var mark := Node3D.new()
	add_child(mark)
	mark.position = Vector3(0.0, 2.45 if not is_vehicle else 2.25, 0.0)
	mark.set_script(load("res://scripts/world/billboard_bob.gd"))
	var mat := Build.emissive(Color(1.0, 0.25, 0.20), 4.0)
	for part: Array in [[Vector3(0.17, 0.50, 0.06), Vector3(0.0, 0.42, 0.0)], [Vector3(0.17, 0.17, 0.06), Vector3(0.0, 0.0, 0.0)]]:
		var mi := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = part[1]
		mark.add_child(mi)


# --- 텔 (판별 단서) -----------------------------------------------------------


## 킬러는 무심코 표적을 확인한다. 관찰력 있는 플레이어에게만 보이는 단서.
func _tick_tell(delta: float, dist: float) -> void:
	if elevated:
		return
	if _glance_left > 0.0:
		_glance_left -= delta
		_face_point(player.global_position, delta * 2.0)
		return
	if dist > Balance.TELL_GLANCE_RANGE:
		return
	_glance_timer -= delta
	if _glance_timer <= 0.0:
		_glance_timer = Balance.TELL_GLANCE_INTERVAL + randf_range(-0.6, 1.2)
		_glance_left = Balance.TELL_GLANCE_TIME


# --- 경찰 / SWAT -------------------------------------------------------------


func _tick_responder(delta: float) -> void:
	_attack_timer = maxf(0.0, _attack_timer - delta)
	var dist := global_position.distance_to(player.global_position)
	var attack_range := 18.0
	var speed := 4.2 if kind == Enums.NpcKind.SWAT else 3.6
	var damage := 22.0 if kind == Enums.NpcKind.SWAT else 15.0
	if dist > attack_range or not _has_line_of_sight():
		_move_toward_point(player.global_position, speed, delta)
		return
	velocity.x = 0.0
	velocity.z = 0.0
	_face_point(player.global_position, delta)
	if _attack_timer <= 0.0:
		_attack_timer = 0.9
		Fx.tracer(self, _eye(), player.eye_position(), Color(0.6, 0.8, 1.0))
		player.take_damage(damage, global_position, "SWAT" if kind == Enums.NpcKind.SWAT else "경찰", "")


# --- 피격 / 사망 -------------------------------------------------------------


func take_bullet(damage: float, point: Vector3) -> void:
	if state == State.DEAD:
		return
	hp -= damage
	Fx.hit_puff(self, point)
	if hp <= 0.0:
		_die()
		return
	# 맞고도 살아남으면 즉시 반응한다.
	if kind == Enums.NpcKind.KILLER and state == State.PATROL:
		_engage(NpcCatalog.KILLER_DEFS[killer_type])
	elif kind == Enums.NpcKind.CIVILIAN:
		state = State.FLEE
		LoopManager.report_threat("민간인 피격")


func _die() -> void:
	state = State.DEAD
	velocity = Vector3.ZERO
	_clear_laser()
	set_physics_process(false)
	collision_layer = 0
	if _visual != null:
		_visual.rotation.x = -PI * 0.5
		_visual.position.y = 0.25
	if _marker != null:
		_marker.visible = false

	match kind:
		Enums.NpcKind.KILLER:
			GameState.register_killer_down(slot_id)
			if _label != null:
				_label.text = "%s ✕" % NpcCatalog.killer_name(killer_type)
				_label.modulate = Color(0.45, 1.0, 0.5)
			EventBus.notify(
				"킬러 제거 — %s (%s)" % [NpcCatalog.killer_name(killer_type), NpcCatalog.disguise_name(disguise)],
				Color(0.5, 1.0, 0.55)
			)
		Enums.NpcKind.CIVILIAN:
			if _label != null:
				_label.text = "민간인 ✕"
				_label.modulate = Color(1.0, 0.35, 0.35)
			EventBus.notify("민간인을 죽였다. 신고가 들어간다.", Color(1.0, 0.3, 0.3))
			LoopManager.report_kill(Enums.NpcKind.CIVILIAN)
		_:
			LoopManager.report_kill(kind)

	EventBus.npc_killed.emit(
		{"slot_id": slot_id, "kind": kind, "killer_type": killer_type, "disguise": disguise}
	)


## 총성을 들었다. 민간인은 도망치고 신고한다 (문서 7절).
func hear_gunshot(from: Vector3) -> void:
	if state == State.DEAD:
		return
	if global_position.distance_to(from) > Balance.WITNESS_RANGE:
		return
	if kind == Enums.NpcKind.CIVILIAN:
		state = State.FLEE
		LoopManager.report_threat("목격자 신고")


# --- 탈출 지점 매복 (문서 4절) ------------------------------------------------


## 남은 킬러를 탈출 지점 주위에 원형으로 재배치한다. 360도 총격이 쏟아진다.
func ambush_at(center: Vector3, angle: float, radius: float) -> void:
	if state == State.DEAD:
		return
	global_position = center + Vector3(sin(angle), 0.0, cos(angle)) * radius
	elevated = false
	_ambushing = true
	state = State.ENGAGE
	_reveal()


# --- 보조 -------------------------------------------------------------------


func _eye() -> Vector3:
	return global_position + Vector3.UP * (VEHICLE_EYE if is_vehicle else EYE_HEIGHT)


func _has_line_of_sight() -> bool:
	if player == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(_eye(), player.eye_position(), Build.LAYER_WORLD)
	query.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _face(direction: Vector3, delta: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	if flat.length() < 0.05:
		return
	_facing = lerp_angle(_facing, atan2(flat.x, flat.z), clampf(Balance.NPC_TURN_SPEED * delta, 0.0, 1.0))


func _face_point(point: Vector3, delta: float) -> void:
	_face(point - global_position, delta)


func _clear_laser() -> void:
	if _laser != null and is_instance_valid(_laser):
		_laser.queue_free()
	_laser = null


func _threat_name() -> String:
	return "%s(%s)" % [NpcCatalog.killer_name(killer_type), NpcCatalog.disguise_name(disguise)]


func _on_knowledge_gained(learned_slot: String, _note: String) -> void:
	if learned_slot == slot_id:
		_refresh_marker()


## 이미 정체를 아는 킬러에게는 표식이 붙는다. 학습의 보상.
func _refresh_marker() -> void:
	if _marker == null:
		return
	var known := kind == Enums.NpcKind.KILLER and slot_id != "" and GameState.is_known(slot_id)
	# 이미 드러난 킬러는 느낌표가 표시를 맡으므로 마름모를 겹치지 않는다.
	_marker.visible = known and state != State.DEAD and not revealed
	if known and _label != null and not revealed:
		_label.text = "%s [%s]" % [NpcCatalog.disguise_name(disguise), NpcCatalog.killer_name(killer_type)]
		_label.modulate = Color(1.0, 0.55, 0.5)
