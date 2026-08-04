extends Node

## 시스템 간 직접 참조 대신 거치는 시그널 허브.
## 발신자는 무엇이 듣는지 몰라야 한다.

# --- 플레이어 --------------------------------------------------------------
signal player_damaged(amount: float, hp: float, from_position: Vector3)
signal player_died(cause: String, killer_slot_id: String)
signal drive_changed(drive: Enums.Drive)
signal ammo_changed(in_mag: int, mag_size: int, reloading: bool)
signal aim_changed(aiming: bool, settle: float, can_fire: bool)
signal weapon_fired(spread_deg: float, alarming: bool)

# --- 엄마 ------------------------------------------------------------------
signal mom_grip_changed(gripping: bool)
signal mom_mode_changed(manual: bool)
signal mom_action(action: String)

# --- NPC / 전투 -------------------------------------------------------------
signal npc_killed(info: Dictionary)
signal npc_alerted(slot_id: String)
signal killer_progress_changed(down: int, total: int)
signal tell_observed(slot_id: String, tell: String)

# --- 수배 (문서 7절) --------------------------------------------------------
signal wanted_changed(level: Enums.Wanted, reason: String)
signal jet_countdown_started(seconds: float)

# --- 루프 ------------------------------------------------------------------
signal loop_started(loop_index: int)
signal loop_ending(reason: Enums.LoopEnd, info: Dictionary)
signal loop_reset_requested()
signal knowledge_gained(slot_id: String, note: String)
signal run_cleared(loop_index: int)

# --- 진행 / UI --------------------------------------------------------------
signal zone_entered(zone: Enums.Zone)
signal escape_progress(ratio: float)
signal escape_ambush_triggered(remaining: int)
signal toast(text: String, color: Color)


## 짧은 상단 알림. 색은 생략하면 기본 흰색.
func notify(text: String, color: Color = Color(0.95, 0.95, 0.95)) -> void:
	toast.emit(text, color)
