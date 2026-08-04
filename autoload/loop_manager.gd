extends Node

## 루프 수명 주기와 수배 단계 사다리를 소유한다.
##
## 문서 7절: 민간인 사살 -> 경찰 -> SWAT -> 헬기 -> 전투기 미사일로 강제 Game Over.
## "GTA 처럼 난장판을 치는 게임이 아니라, GTA 식 난장판을 벌이면 반드시 망하는 게임"이므로
## 사다리는 되돌릴 수 없다. 내려오는 단계는 ALERT 뿐이다.

const WANTED_LABELS := {
	Enums.Wanted.CLEAR: "이상 없음",
	Enums.Wanted.ALERT: "신고 접수",
	Enums.Wanted.POLICE: "경찰 출동",
	Enums.Wanted.SWAT: "SWAT 출동",
	Enums.Wanted.HELI: "헬기 출동",
	Enums.Wanted.JET: "전투기 요격",
}

var ending: bool = false
var end_reason: Enums.LoopEnd = Enums.LoopEnd.KILLED
var end_info: Dictionary = {}

var loop_time: float = 0.0

var _alert_timer: float = 0.0
var _jet_timer: float = 0.0
var _freeze_timer: float = 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if ending:
		_freeze_timer -= delta
		if _freeze_timer <= 0.0:
			ending = false
			EventBus.loop_reset_requested.emit()
		return
	if not GameState.loop_active:
		return
	loop_time += delta
	if GameState.wanted == Enums.Wanted.ALERT:
		_alert_timer -= delta
		if _alert_timer <= 0.0:
			_set_wanted(Enums.Wanted.CLEAR, "상황 종료")
	if GameState.wanted == Enums.Wanted.JET:
		_jet_timer -= delta
		if _jet_timer <= 0.0:
			end_loop(Enums.LoopEnd.WANTED_OUT, {"cause": "전투기 미사일"})


# --- 루프 -------------------------------------------------------------------


func begin_loop() -> void:
	ending = false
	end_info = {}
	loop_time = 0.0
	# 리빌 슬로우모션이 걸린 채로 루프가 끝났을 수 있다.
	Engine.time_scale = 1.0
	_alert_timer = 0.0
	_jet_timer = 0.0
	GameState.reset_loop_state()
	EventBus.loop_started.emit(GameState.loop_index)


## 루프 시작 직후의 유예. 킬러는 이 동안 먼저 움직이지 않는다.
func grace_active() -> bool:
	return loop_time < Balance.LOOP_GRACE_TIME


## 루프를 끝낸다. 화면 정지 후 loop_reset_requested 가 나간다.
func end_loop(reason: Enums.LoopEnd, info: Dictionary = {}) -> void:
	if ending or not GameState.loop_active:
		return
	GameState.loop_active = false
	Engine.time_scale = 1.0
	ending = true
	end_reason = reason
	end_info = info
	_freeze_timer = Balance.DEATH_FREEZE_TIME
	if reason == Enums.LoopEnd.ESCAPED:
		GameState.runs_cleared += 1
		EventBus.run_cleared.emit(GameState.loop_index)
	else:
		GameState.total_deaths += 1
	EventBus.loop_ending.emit(reason, info)


## 다음 루프로 진행한다. 지식은 유지된다.
func advance_loop() -> void:
	GameState.loop_index += 1
	begin_loop()


func reason_text(reason: Enums.LoopEnd, info: Dictionary) -> String:
	match reason:
		Enums.LoopEnd.KILLED:
			return "%s 에게 당했다" % String(info.get("cause", "누군가"))
		Enums.LoopEnd.WANTED_OUT:
			return "수배 단계 초과 — 전투기 미사일"
		Enums.LoopEnd.GAVE_UP:
			return "스스로 루프를 되감았다"
		Enums.LoopEnd.ESCAPED:
			return "탈출 성공"
	return ""


# --- 수배 사다리 -------------------------------------------------------------


## 민간인을 위협했다(빗맞힘 / 총격 목격). ALERT 까지만 올린다.
func report_threat(source: String = "총성") -> void:
	if GameState.wanted >= Enums.Wanted.POLICE:
		return
	_alert_timer = Balance.ALERT_DECAY_TIME
	if GameState.wanted == Enums.Wanted.CLEAR:
		_set_wanted(Enums.Wanted.ALERT, source)


## 무언가를 죽였다. 소속에 따라 사다리가 올라간다.
func report_kill(kind: Enums.NpcKind) -> void:
	match kind:
		Enums.NpcKind.CIVILIAN:
			GameState.register_civilian_down()
			_raise_to(Enums.Wanted.POLICE, "민간인 사살")
		Enums.NpcKind.POLICE:
			_raise_to(Enums.Wanted.SWAT, "경찰 사살")
		Enums.NpcKind.SWAT:
			_raise_to(Enums.Wanted.HELI, "SWAT 사살")
		Enums.NpcKind.KILLER:
			pass


## 헬기를 격추했다. 문서대로 전투기가 뜨고 강제 Game Over 카운트가 시작된다.
func report_heli_destroyed() -> void:
	_raise_to(Enums.Wanted.JET, "헬기 격추")


func _raise_to(level: Enums.Wanted, reason: String) -> void:
	if GameState.wanted >= level:
		# 같은 단계에서 반복되면 한 칸 더 올린다.
		if level >= Enums.Wanted.POLICE and GameState.wanted < Enums.Wanted.JET:
			_set_wanted((GameState.wanted + 1) as Enums.Wanted, reason)
		return
	_set_wanted(level, reason)


func _set_wanted(level: Enums.Wanted, reason: String) -> void:
	if GameState.wanted == level:
		return
	GameState.wanted = level
	EventBus.wanted_changed.emit(level, reason)
	if level == Enums.Wanted.ALERT:
		_alert_timer = Balance.ALERT_DECAY_TIME
	if level == Enums.Wanted.JET:
		_jet_timer = Balance.JET_COUNTDOWN
		EventBus.jet_countdown_started.emit(_jet_timer)


func jet_time_left() -> float:
	return maxf(0.0, _jet_timer)


func wanted_label() -> String:
	return String(WANTED_LABELS.get(GameState.wanted, "?"))
