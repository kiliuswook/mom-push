extends Node

## 한 판(run)의 진실원.
##
## 킬러 배치는 run_seed 로 결정되며 루프를 반복해도 바뀌지 않는다.
## 이것이 타임루프 학습이 성립하는 조건이다 — 죽어서 얻은 정보가 다음 루프에서 유효해야 한다.
## 반대로 "이번 루프에서 누구를 죽였는가"는 루프마다 초기화된다.
## 문서 4절: 모든 킬러를 제거한 상태로 탈출 지점에 도달해야 클리어다.

var run_seed: int = 0
var loop_index: int = 1

## slot_id -> Enums.KillerType. 민간인 슬롯은 이 사전에 없다.
var assignments: Dictionary = {}

## slot_id -> {confirmed: bool, cause: String, zone: int, loop: int}
## 루프를 넘어 유지되는 유일한 자산.
var knowledge: Dictionary = {}

## 이번 루프 상태 -------------------------------------------------------------
var wanted: Enums.Wanted = Enums.Wanted.CLEAR
var killers_down: Array[String] = []
var civilians_down_this_loop: int = 0
var loop_active: bool = false

## 누적 통계 ------------------------------------------------------------------
var total_deaths: int = 0
var total_civilians_killed: int = 0
var runs_cleared: int = 0


func _ready() -> void:
	start_new_run()


## 새 판. seed 를 주지 않으면 무작위로 뽑는다.
func start_new_run(seed_value: int = -1) -> void:
	run_seed = seed_value if seed_value >= 0 else randi()
	loop_index = 1
	knowledge.clear()
	_assign_killers()
	reset_loop_state()


## 루프만 되감는다. 지식과 배치는 그대로.
func reset_loop_state() -> void:
	wanted = Enums.Wanted.CLEAR
	killers_down.clear()
	civilians_down_this_loop = 0
	loop_active = true


func _assign_killers() -> void:
	assignments.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed
	for category: Dictionary in NpcCatalog.KILLER_CATEGORIES:
		var slots: Array = category["slots"]
		var picked: String = String(slots[rng.randi_range(0, slots.size() - 1)])
		var type: Enums.KillerType = category["type"]
		# 차량 슬롯은 카테고리와 무관하게 차량 거동을 따른다.
		if picked == "road_car" and type == Enums.KillerType.TAXI:
			type = Enums.KillerType.DRIVER
		assignments[picked] = type


# --- 조회 -------------------------------------------------------------------


func is_killer(slot_id: String) -> bool:
	return assignments.has(slot_id)


func killer_type_of(slot_id: String) -> Enums.KillerType:
	if assignments.has(slot_id):
		return assignments[slot_id]
	return Enums.KillerType.NONE


func total_killers() -> int:
	return assignments.size()


func killers_remaining() -> int:
	return maxi(0, total_killers() - killers_down.size())


func all_killers_down() -> bool:
	return killers_remaining() == 0


func remaining_killer_slots() -> Array[String]:
	var out: Array[String] = []
	for slot_id: String in assignments.keys():
		if not killers_down.has(slot_id):
			out.append(slot_id)
	return out


# --- 지식 -------------------------------------------------------------------


func is_known(slot_id: String) -> bool:
	return knowledge.has(slot_id)


## 킬러의 정체를 확정 기록한다. 이미 알고 있으면 아무 일도 하지 않는다.
func learn(slot_id: String, cause: String) -> void:
	if knowledge.has(slot_id):
		return
	var slot: Dictionary = NpcCatalog.slot_by_id(slot_id)
	var zone: int = int(slot.get("zone", Enums.Zone.HOSPITAL))
	knowledge[slot_id] = {
		"confirmed": true,
		"cause": cause,
		"zone": zone,
		"loop": loop_index,
	}
	var type: Enums.KillerType = killer_type_of(slot_id)
	var note := "%s의 %s — %s" % [
		NpcCatalog.zone_name(zone),
		NpcCatalog.disguise_name(String(slot.get("disguise", ""))),
		NpcCatalog.killer_name(type),
	]
	EventBus.knowledge_gained.emit(slot_id, note)


func known_count() -> int:
	return knowledge.size()


## 코덱스 표시용. 확정된 킬러를 구역 순서로 정렬해 돌려준다.
func knowledge_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for slot_id: String in knowledge.keys():
		var slot: Dictionary = NpcCatalog.slot_by_id(slot_id)
		var type: Enums.KillerType = killer_type_of(slot_id)
		var def: Dictionary = NpcCatalog.KILLER_DEFS.get(type, {})
		out.append(
			{
				"slot_id": slot_id,
				"zone": int(knowledge[slot_id]["zone"]),
				"zone_name": NpcCatalog.zone_name(int(knowledge[slot_id]["zone"])),
				"disguise": NpcCatalog.disguise_name(String(slot.get("disguise", ""))),
				"killer_name": NpcCatalog.killer_name(type),
				"tell": String(def.get("tell", "")),
				"cause": String(knowledge[slot_id]["cause"]),
				"loop": int(knowledge[slot_id]["loop"]),
				"down": killers_down.has(slot_id),
			}
		)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["zone"] < b["zone"])
	return out


# --- 처치 기록 ---------------------------------------------------------------


func register_killer_down(slot_id: String) -> void:
	if killers_down.has(slot_id):
		return
	killers_down.append(slot_id)
	learn(slot_id, "직접 처치")
	EventBus.killer_progress_changed.emit(killers_down.size(), total_killers())


func register_civilian_down() -> void:
	civilians_down_this_loop += 1
	total_civilians_killed += 1
