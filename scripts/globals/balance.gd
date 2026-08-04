class_name Balance
extends RefCounted

## 밸런스 수치 단일 원천. 로직 스크립트에 숫자를 하드코딩하지 않는다.

# --- 휠체어 이동 (문서 8절) -------------------------------------------------
const SELF_ACCEL := 4.2  # 직접 굴릴 때 가속 (m/s^2)
const SELF_MAX_SPEED := 2.6  # 직접 굴릴 때 최고 속도
const PUSH_ACCEL := 11.0  # 엄마가 밀 때 가속
const PUSH_MAX_SPEED := 7.6  # 엄마가 밀 때 최고 속도
const ROLL_FRICTION := 0.62  # 관성 롤 감속 (작을수록 오래 굴러간다)
const BRAKE_DECEL := 16.0  # 급정지 감속
const TURN_SPEED_SELF := 1.7  # 직접 조작 회전 (rad/s)
const TURN_SPEED_PUSH := 2.5  # 밀리는 중 회전
const STOP_THRESHOLD := 0.35  # 이 속도 아래면 완전 정지로 본다
const AIR_CONTROL := 0.25  # 공중에서의 조향 비율
const JUMP_VELOCITY := 7.2  # 휠체어 점프 (코옵 전용)
const STEP_HEIGHT := 0.45  # 밀리는 중 자동으로 넘는 도로 턱 높이
const CARRY_CLIMB_SPEED := 1.15  # 엄마가 들고 계단을 오르는 속도
const CARRY_LIFT_RATE := 1.6  # 들어올릴 때 상승 속도

# --- 조준 / 사격 ------------------------------------------------------------
const AIM_SETTLE_TIME := 0.28  # 정지 후 정밀 조준이 완성되기까지
const FIRE_COOLDOWN := 0.34
const RELOAD_TIME := 1.55
const MAG_SIZE := 6
const BULLET_DAMAGE := 70.0
const HEADSHOT_MULT := 2.0
const WEAPON_RANGE := 120.0
const RECOIL_PITCH := 2.4  # 발사 시 카메라 반동 (deg)
const RECOIL_PUSHBACK := 1.1  # 정지 상태에서 뒤로 밀리는 속도 (병맛 물리)

## 구동 상태별 사격 정확도. 값은 분산각(deg). -1 이면 사격 불가.
const SPREAD_BY_DRIVE := {
	Enums.Drive.STOPPED: 0.25,
	Enums.Drive.SELF: -1.0,
	Enums.Drive.COAST: 1.9,
	Enums.Drive.PUSHED: 3.4,
	Enums.Drive.CARRIED: -1.0,
}

# --- 플레이어 --------------------------------------------------------------
const PLAYER_MAX_HP := 100.0
const MOUSE_SENSITIVITY := 0.0022
const PITCH_LIMIT := 1.35  # rad
const CAMERA_HEIGHT := 1.02  # 앉은키. 서 있는 NPC보다 낮다.
## 스폰 방향. Godot 의 정면은 -Z 이므로 출구(+Z)를 보려면 180도 돌아 있어야 한다.
const SPAWN_YAW := PI

# --- 엄마 ------------------------------------------------------------------
const MOM_FOLLOW_SPEED := 5.4
const MOM_GRAB_RANGE := 2.6  # 손잡이를 잡을 수 있는 거리
const MOM_LOSE_RANGE := 4.2  # 이 이상 벌어지면 손을 놓는다
const MOM_MAX_HP := 100.0

# --- NPC -------------------------------------------------------------------
const NPC_MAX_HP := 100.0
const NPC_WALK_SPEED := 1.55
const NPC_FLEE_SPEED := 4.6
const NPC_TURN_SPEED := 6.0
const NPC_WAYPOINT_TOLERANCE := 0.8
const NPC_IDLE_TIME := 1.4

## 차량형 킬러가 벗어날 수 없는 도로 영역.
## 차가 인도와 병원 로비까지 쫓아오면 우스운 게 아니라 그냥 대응 불가다.
## 도로 안에서만 위험하므로 "횡단보도 진입 타이밍"이 학습 대상이 된다 (문서 6절).
const ROAD_HALF_WIDTH := 8.5
const ROAD_Z_MIN := 17.0
const ROAD_Z_MAX := 48.0

## 킬러 텔(tell) — 문서 12절 "두 번째 루프부터는 알고 보면 피할 수 있어야 한다".
const TELL_GLANCE_RANGE := 26.0  # 이 거리 안에서 플레이어를 힐끗 본다
const TELL_GLANCE_INTERVAL := 3.1
const TELL_GLANCE_TIME := 0.55

# --- 수배 단계 (문서 7절) ---------------------------------------------------
const ALERT_DECAY_TIME := 22.0  # ALERT 단계는 시간이 지나면 가라앉는다
const WITNESS_RANGE := 18.0  # 목격 반경
const POLICE_SPAWN_COUNT := 2
const SWAT_SPAWN_COUNT := 3
const POLICE_HP := 130.0
const SWAT_HP := 190.0
const RESPONSE_INTERVAL := 9.0  # 같은 단계에서 증원이 오는 간격
const JET_COUNTDOWN := 6.0  # 전투기 경보 후 강제 Game Over 까지

# --- 탈출 지점 (문서 4절) ---------------------------------------------------
const ESCAPE_AMBUSH_RADIUS := 11.0  # 남은 킬러가 이 반경에 원형으로 등장
const ESCAPE_HOLD_TIME := 2.0  # 탈출 판정에 필요한 체류 시간

# --- 루프 ------------------------------------------------------------------
const DEATH_FREEZE_TIME := 1.6  # 죽은 뒤 루프 화면이 뜨기까지
const KILLER_SLOT_COUNT := 6  # 한 판에 배치되는 킬러 수

## 루프 시작 직후 유예 시간. 이 동안 킬러는 절대 먼저 움직이지 않는다.
## 병원 침대에서 눈뜨자마자 죽는 것은 "억울한 죽음"이 아니라 그냥 조작 불능이다.
const LOOP_GRACE_TIME := 3.0
