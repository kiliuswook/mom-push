class_name Town
extends Node3D

## 마을 전체. 문서 11절의 루트를 그대로 편다.
##   병원 -> 병원 앞 도로 -> 상점가 -> 주택가 -> 광장 -> 탈출 지점
##
## "핵심은 넓이보다 기억 가능성이다." 따라서 한 줄짜리 좁고 밀도 높은 맵이며,
## 구역마다 무엇을 배워야 하는지가 다르다.

const START_POSITION := Vector3(0.0, 0.3, 0.0)
const START_YAW := Balance.SPAWN_YAW
const ESCAPE_POSITION := Vector3(0.0, 0.0, 152.0)

const C_GRASS := Color(0.34, 0.42, 0.28)
const C_PAVE := Color(0.60, 0.59, 0.56)
const C_ASPHALT := Color(0.22, 0.23, 0.25)
const C_LINE := Color(0.88, 0.88, 0.84)
const C_HOSPITAL := Color(0.87, 0.89, 0.87)
const C_SHOP := Color(0.66, 0.55, 0.47)
const C_HOUSE := Color(0.71, 0.65, 0.55)
const C_CONCRETE := Color(0.55, 0.55, 0.54)
const C_METAL := Color(0.42, 0.45, 0.50)

var player: WheelchairPlayer = null
var escape_zone: EscapeZone = null

var _npcs: Array[Npc] = []
var _responders: Array[Npc] = []
var _heli: Helicopter = null
var _response_timer: float = 0.0


static func create(target: WheelchairPlayer) -> Town:
	var t := Town.new()
	t.set_script(load("res://scripts/world/town.gd"))
	t.name = "Town"
	t.player = target
	return t


func _ready() -> void:
	_build_environment()
	_build_ground()
	_build_hospital()
	_build_road()
	_build_shops()
	_build_houses()
	_build_plaza()
	_build_escape()
	_build_perimeter()
	_build_zone_triggers()
	EventBus.wanted_changed.connect(_on_wanted_changed)


func _process(delta: float) -> void:
	if not GameState.loop_active:
		return
	if GameState.wanted < Enums.Wanted.POLICE:
		return
	_response_timer -= delta
	if _response_timer <= 0.0:
		_response_timer = Balance.RESPONSE_INTERVAL
		_spawn_response_wave()


# --- 환경 -------------------------------------------------------------------


func _build_environment() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.32, 0.45, 0.62)
	sky_mat.sky_horizon_color = Color(0.72, 0.76, 0.78)
	sky_mat.ground_bottom_color = Color(0.28, 0.29, 0.28)
	sky_mat.ground_horizon_color = Color(0.62, 0.63, 0.60)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.fog_enabled = true
	e.fog_density = 0.006
	e.fog_light_color = Color(0.70, 0.74, 0.78)
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.ssao_enabled = true
	env.environment = e
	add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(38.0), 0.0)
	sun.light_energy = 1.15
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	add_child(sun)


# --- 지면 -------------------------------------------------------------------


func _build_ground() -> void:
	# 걷는 면이 정확히 y=0 이 되도록 두께 2 슬랩의 윗면을 0 에 맞춘다.
	Build.box(self, Vector3(76.0, 2.0, 200.0), Vector3(0.0, -1.0, 76.0), C_GRASS)
	# 중앙 보도 (장식 - 충돌 없음)
	Build.box(self, Vector3(24.0, 0.02, 190.0), Vector3(0.0, 0.01, 74.0), C_PAVE, false)


# --- 병원 (시작 지점 / 루프 리셋 지점) ----------------------------------------


func _build_hospital() -> void:
	var wall_h := 4.6
	Build.box(self, Vector3(26.0, 0.02, 26.0), Vector3(0.0, 0.02, 4.0), Color(0.80, 0.84, 0.85), false)
	Build.box(self, Vector3(27.0, wall_h, 0.5), Vector3(0.0, wall_h * 0.5, -9.0), C_HOSPITAL)
	Build.box(self, Vector3(0.5, wall_h, 25.0), Vector3(-13.0, wall_h * 0.5, 3.5), C_HOSPITAL)
	Build.box(self, Vector3(0.5, wall_h, 25.0), Vector3(13.0, wall_h * 0.5, 3.5), C_HOSPITAL)
	# 정면 벽 — 가운데 5m 출입구
	Build.box(self, Vector3(10.5, wall_h, 0.5), Vector3(-8.0, wall_h * 0.5, 16.0), C_HOSPITAL)
	Build.box(self, Vector3(10.5, wall_h, 0.5), Vector3(8.0, wall_h * 0.5, 16.0), C_HOSPITAL)
	Build.box(self, Vector3(27.0, 0.4, 25.5), Vector3(0.0, wall_h + 0.2, 3.5), Color(0.75, 0.77, 0.78))

	# 침대 몇 개와 커튼 — 여기서 깨어난다.
	for i: int in 3:
		var x := -8.0 + float(i) * 8.0
		Build.box(self, Vector3(1.1, 0.55, 2.2), Vector3(x, 0.28, -5.0), Color(0.90, 0.91, 0.93), false)
		Build.box(self, Vector3(1.2, 0.12, 0.5), Vector3(x, 0.62, -6.0), Color(0.78, 0.80, 0.86), false)
	Build.box(self, Vector3(0.2, 3.0, 6.0), Vector3(-4.0, 1.5, -4.0), Color(0.62, 0.72, 0.75), false)

	# 천장이 햇빛을 막으므로 실내등이 없으면 새까맣다.
	for i: int in 3:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(0.0, 3.9, -4.0 + float(i) * 8.0)
		lamp.light_energy = 3.2
		lamp.omni_range = 17.0
		lamp.light_color = Color(0.95, 0.97, 1.0)
		add_child(lamp)
		Build.box(self, Vector3(3.0, 0.1, 0.5), lamp.position + Vector3(0.0, 0.4, 0.0), Color(0.95, 0.97, 1.0), false)

	Build.label(self, "병원 — 루프 리셋 지점", Vector3(0.0, 3.2, -7.0), 0.55, Color(0.85, 0.92, 1.0))
	Build.label(self, "출구 →", Vector3(0.0, 2.6, 14.5), 0.45, Color(1.0, 0.92, 0.6))

	# 문턱 (도로 턱). 밀리는 중이면 자동으로 넘는다.
	Build.box(self, Vector3(5.0, 0.22, 0.6), Vector3(0.0, 0.11, 16.0), C_CONCRETE)


# --- 병원 앞 도로 (첫 킬러 노출 구간) -----------------------------------------


func _build_road() -> void:
	Build.box(self, Vector3(18.0, 0.02, 34.0), Vector3(0.0, 0.02, 32.0), C_ASPHALT, false)
	# 횡단보도 — 택시 킬러의 트리거 지점 (문서 6절)
	for i: int in 7:
		Build.box(
			self,
			Vector3(1.1, 0.02, 4.0),
			Vector3(-6.6 + float(i) * 2.2, 0.03, 32.0),
			C_LINE,
			false
		)
	Build.label(self, "횡단보도 — 조심", Vector3(0.0, 2.2, 32.0), 0.4, Color(1.0, 0.9, 0.55))

	# 연석. 낮은 턱이라 밀리면 넘고, 직접 굴리면 걸린다.
	Build.box(self, Vector3(6.0, 0.26, 34.0), Vector3(-12.0, 0.13, 32.0), C_PAVE)
	Build.box(self, Vector3(6.0, 0.26, 34.0), Vector3(12.0, 0.13, 32.0), C_PAVE)
	# 경사로 — 직접 굴려서 인도로 올라가는 유일한 길
	Build.ramp(self, 3.0, 3.0, 0.26, Vector3(-12.0, 0.0, 18.0), C_CONCRETE)
	Build.ramp(self, 3.0, 3.0, 0.26, Vector3(12.0, 0.0, 46.0), C_CONCRETE, PI)

	Build.box(self, Vector3(9.0, 9.0, 30.0), Vector3(-19.0, 4.5, 32.0), Color(0.58, 0.56, 0.52))
	Build.box(self, Vector3(9.0, 11.0, 30.0), Vector3(19.0, 5.5, 32.0), Color(0.52, 0.50, 0.50))
	_street_lamp(Vector3(-10.0, 0.0, 22.0))
	_street_lamp(Vector3(10.0, 0.0, 42.0))


func _street_lamp(base: Vector3) -> void:
	Build.cylinder(self, 0.12, 5.0, base + Vector3(0.0, 2.5, 0.0), C_METAL, false)
	Build.box(self, Vector3(1.4, 0.16, 0.4), base + Vector3(0.5, 5.0, 0.0), C_METAL, false)


# --- 상점가 (민간인과 킬러가 섞이는 구간) --------------------------------------


func _build_shops() -> void:
	Build.box(self, Vector3(11.0, 7.5, 34.0), Vector3(-17.5, 3.75, 66.0), C_SHOP)
	Build.box(self, Vector3(11.0, 8.5, 34.0), Vector3(17.5, 4.25, 66.0), C_SHOP.darkened(0.12))
	var awning := Color(0.75, 0.25, 0.22)
	for i: int in 4:
		var z := 54.0 + float(i) * 9.0
		Build.box(self, Vector3(3.6, 0.14, 3.0), Vector3(-11.0, 2.7, z), awning, false)
		Build.box(self, Vector3(3.6, 0.14, 3.0), Vector3(11.0, 2.7, z), awning.darkened(0.2), false)
		Build.box(self, Vector3(2.4, 0.9, 1.2), Vector3(-10.4, 0.45, z), Color(0.50, 0.40, 0.30))
		Build.box(self, Vector3(2.4, 0.9, 1.2), Vector3(10.4, 0.45, z), Color(0.50, 0.40, 0.30))
	# 가운데 진열대 — 엄폐물
	Build.box(self, Vector3(2.0, 1.1, 5.0), Vector3(-2.5, 0.55, 62.0), Color(0.46, 0.42, 0.38))
	Build.box(self, Vector3(2.0, 1.1, 5.0), Vector3(2.5, 0.55, 74.0), Color(0.46, 0.42, 0.38))
	Build.label(self, "상점가", Vector3(0.0, 4.0, 50.0), 0.6, Color(1.0, 0.95, 0.8))


# --- 주택가 (옥상 / 창문 스나이퍼 구간) ---------------------------------------


func _build_houses() -> void:
	# 좌측 주택 — 6.4m 발코니에 창가 인물이 선다.
	Build.box(self, Vector3(11.0, 8.5, 18.0), Vector3(-18.0, 4.25, 96.0), C_HOUSE)
	Build.box(self, Vector3(3.6, 0.3, 3.6), Vector3(-11.6, 6.25, 96.0), C_CONCRETE)
	_railing(Vector3(-11.6, 6.4, 94.4), 3.6, 0.0)
	Build.box(self, Vector3(2.6, 2.2, 0.2), Vector3(-13.2, 7.5, 96.0), Color(0.35, 0.45, 0.52), false)

	# 우측 주택 — 9.4m 옥상. 스나이퍼 자리.
	Build.box(self, Vector3(13.0, 9.4, 18.0), Vector3(15.5, 4.7, 106.0), C_HOUSE.darkened(0.1))
	_railing(Vector3(9.2, 9.4, 106.0), 18.0, PI * 0.5)

	# 외부 계단 — 휠체어는 못 오른다. 엄마가 들어야 한다 (문서 10절).
	Build.stairs(self, 24, 0.392, 0.45, 2.6, Vector3(7.0, 0.0, 92.0), C_CONCRETE)
	Build.box(self, Vector3(4.6, 0.3, 3.2), Vector3(8.0, 9.25, 104.4), C_CONCRETE)
	var lift := StairLift.create(Vector3(7.0, 0.0, 90.6), Vector3(8.0, 9.4, 104.4))
	add_child(lift)

	# 난간 타기 — 옥상에서 광장으로 한 번에 내려온다.
	var rail_from := Vector3(11.0, 9.2, 114.0)
	var rail_to := Vector3(6.0, 0.9, 126.0)
	var mid := rail_from.lerp(rail_to, 0.5)
	var span := rail_from.distance_to(rail_to)
	var dir := (rail_to - rail_from).normalized()
	var pitch := asin(clampf(-dir.y, -1.0, 1.0))
	var yaw := atan2(dir.x, dir.z)
	Build.box(self, Vector3(0.3, 0.3, span), mid, C_METAL, true, Vector3(-pitch, yaw, 0.0))
	var rail := Rail.create(Vector3(2.4, 2.0, span), mid + Vector3.UP * 0.8, Vector3(-pitch, yaw, 0.0), dir)
	add_child(rail)
	Build.label(self, "난간 — 밀린 채로 올라타면 미끄러진다", rail_from + Vector3.UP, 0.3, Color(0.8, 0.95, 1.0))

	Build.label(self, "주택가 — 위를 봐라", Vector3(0.0, 4.2, 86.0), 0.6, Color(1.0, 0.9, 0.8))


func _railing(center: Vector3, length: float, yaw: float) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = center
	root.rotation.y = yaw
	Build.box(root, Vector3(length, 0.1, 0.1), Vector3(0.0, 1.0, 0.0), C_METAL, false)
	var posts := int(length / 1.2)
	for i: int in posts + 1:
		var x := -length * 0.5 + float(i) * 1.2
		Build.box(root, Vector3(0.08, 1.0, 0.08), Vector3(x, 0.5, 0.0), C_METAL, false)


# --- 광장 (다수의 위장 킬러) ---------------------------------------------------


func _build_plaza() -> void:
	Build.box(self, Vector3(28.0, 0.02, 30.0), Vector3(0.0, 0.02, 131.0), Color(0.66, 0.64, 0.60), false)
	Build.cylinder(self, 3.2, 0.8, Vector3(0.0, 0.4, 131.0), C_CONCRETE)
	Build.cylinder(self, 0.6, 2.4, Vector3(0.0, 1.6, 131.0), Color(0.72, 0.72, 0.70), false)
	for i: int in 4:
		var angle := TAU * float(i) / 4.0 + 0.4
		var pos := Vector3(sin(angle), 0.0, cos(angle)) * 9.5 + Vector3(0.0, 0.0, 131.0)
		Build.cylinder(self, 1.1, 0.9, pos + Vector3(0.0, 0.45, 0.0), Color(0.45, 0.38, 0.30))
		Build.cylinder(self, 0.9, 1.6, pos + Vector3(0.0, 1.6, 0.0), Color(0.30, 0.45, 0.25), false)
	Build.box(self, Vector3(10.0, 10.0, 26.0), Vector3(-20.0, 5.0, 131.0), Color(0.60, 0.58, 0.56))
	Build.box(self, Vector3(10.0, 12.0, 26.0), Vector3(20.0, 6.0, 131.0), Color(0.56, 0.54, 0.55))
	Build.label(self, "광장", Vector3(0.0, 4.5, 118.0), 0.7, Color(1.0, 0.95, 0.85))


# --- 탈출 지점 ---------------------------------------------------------------


func _build_escape() -> void:
	Build.box(self, Vector3(14.0, 0.06, 14.0), ESCAPE_POSITION + Vector3(0.0, 0.04, 0.0), Color(0.30, 0.45, 0.32), false)
	for i: int in 8:
		var angle := TAU * float(i) / 8.0
		# 반지름은 수평 성분에만 곱한다. y 까지 곱하면 기둥이 공중에 뜬다.
		Build.cylinder(
			self,
			0.16,
			1.4,
			ESCAPE_POSITION + Vector3(sin(angle), 0.0, cos(angle)) * 6.0 + Vector3(0.0, 0.7, 0.0),
			Color(0.95, 0.85, 0.30),
			false
		)
	# 탈출용 승합차
	Build.box(self, Vector3(2.4, 2.0, 5.6), ESCAPE_POSITION + Vector3(6.5, 1.2, 2.0), Color(0.30, 0.34, 0.42))
	Build.label(self, "탈출 지점", ESCAPE_POSITION + Vector3(0.0, 4.0, 0.0), 0.8, Color(0.6, 1.0, 0.7))
	Build.label(
		self,
		"모든 킬러를 제거하지 않으면 여기서 포위된다",
		ESCAPE_POSITION + Vector3(0.0, 3.0, 0.0),
		0.32,
		Color(1.0, 0.7, 0.6)
	)
	escape_zone = EscapeZone.create(ESCAPE_POSITION + Vector3(0.0, 1.5, 0.0), 5.0)
	add_child(escape_zone)


func _build_perimeter() -> void:
	Build.box(self, Vector3(1.0, 14.0, 200.0), Vector3(-25.0, 7.0, 76.0), Color(0.40, 0.42, 0.40))
	Build.box(self, Vector3(1.0, 14.0, 200.0), Vector3(25.0, 7.0, 76.0), Color(0.40, 0.42, 0.40))
	Build.box(self, Vector3(52.0, 14.0, 1.0), Vector3(0.0, 7.0, -22.0), Color(0.40, 0.42, 0.40))
	Build.box(self, Vector3(52.0, 14.0, 1.0), Vector3(0.0, 7.0, 166.0), Color(0.40, 0.42, 0.40))


func _build_zone_triggers() -> void:
	_zone_trigger(Enums.Zone.HOSPITAL, 4.0, 17.0)
	_zone_trigger(Enums.Zone.ROAD, 17.0, 48.0)
	_zone_trigger(Enums.Zone.SHOPS, 48.0, 84.0)
	_zone_trigger(Enums.Zone.HOUSES, 84.0, 116.0)
	_zone_trigger(Enums.Zone.PLAZA, 116.0, 146.0)
	_zone_trigger(Enums.Zone.ESCAPE, 146.0, 160.0)


func _zone_trigger(zone: Enums.Zone, z_start: float, z_end: float) -> void:
	var depth := z_end - z_start
	var area := Build.trigger_box(
		self, Vector3(46.0, 12.0, depth), Vector3(0.0, 6.0, (z_start + z_end) * 0.5), "Zone_%d" % zone
	)
	area.body_entered.connect(
		func(body: Node3D) -> void:
			if body is WheelchairPlayer:
				EventBus.zone_entered.emit(zone)
	)


# --- NPC 스폰 / 루프 리셋 ------------------------------------------------------


func spawn_npcs() -> void:
	for slot: Dictionary in NpcCatalog.SLOTS:
		var npc := Npc.create()
		npc.setup_from_slot(slot, player)
		npc.add_to_group("npc")
		add_child(npc)
		_npcs.append(npc)


func clear_actors() -> void:
	for npc: Npc in _npcs:
		if is_instance_valid(npc):
			npc.queue_free()
	_npcs.clear()
	for r: Npc in _responders:
		if is_instance_valid(r):
			r.queue_free()
	_responders.clear()
	if _heli != null and is_instance_valid(_heli):
		_heli.queue_free()
	_heli = null


## 루프를 되감는다. 지식은 GameState 가 들고 있으므로 여기서는 월드만 되돌린다.
func reset_for_loop() -> void:
	clear_actors()
	_response_timer = 0.0
	if escape_zone != null:
		escape_zone.rearm()
	spawn_npcs()


## 플레이어의 총성을 주변에 알린다 (문서 7절: 목격자 신고).
func broadcast_gunshot(from: Vector3) -> void:
	for npc: Npc in _npcs:
		if is_instance_valid(npc):
			npc.hear_gunshot(from)


# --- 수배 대응 ---------------------------------------------------------------


func _on_wanted_changed(level: Enums.Wanted, _reason: String) -> void:
	match level:
		Enums.Wanted.POLICE:
			_response_timer = 1.5
		Enums.Wanted.SWAT:
			_response_timer = 1.0
		Enums.Wanted.HELI:
			_spawn_heli()
		Enums.Wanted.JET:
			_response_timer = 999.0
		_:
			pass


func _spawn_response_wave() -> void:
	if player == null or not player.alive:
		return
	var kind := Enums.NpcKind.POLICE
	var count := Balance.POLICE_SPAWN_COUNT
	if GameState.wanted >= Enums.Wanted.SWAT:
		kind = Enums.NpcKind.SWAT
		count = Balance.SWAT_SPAWN_COUNT
	if _responders.size() > 8:
		return
	for i: int in count:
		var back := player.global_position.z - 26.0
		var spawn := Vector3(randf_range(-9.0, 9.0), 0.4, clampf(back, -4.0, 150.0))
		var responder := Npc.create()
		responder.setup_responder(kind, spawn, player)
		add_child(responder)
		_responders.append(responder)
	EventBus.notify(
		"%s 접근 중" % Josa.subject("SWAT" if kind == Enums.NpcKind.SWAT else "경찰"),
		Color(0.6, 0.75, 1.0)
	)


func _spawn_heli() -> void:
	if _heli != null and is_instance_valid(_heli):
		return
	_heli = Helicopter.create(player, player.global_position + Vector3(0.0, 24.0, -22.0))
	add_child(_heli)
