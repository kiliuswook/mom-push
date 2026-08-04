# 엄마, 밀어! (Mom, Push!)

Godot 4.6 / GDScript. 타임루프 암살자 색출 병맛 물리 FPS.
기획 원본은 `Mom, Push! Game Concept Proposal v0.2` (2026.05.12). 요약과 구현 매핑은 `docs/GDD.md`.

현재 범위: **v0.2 문서의 MVP 검증 범위 6항목 전부 + 수배 단계 사다리 전체**.
사운드, 세이브, 실제 스플릿스크린, 모델링 에셋은 **미구현**.

## 절대 흔들리면 안 되는 규칙 세 개

1. **사격을 막는 것은 속도가 아니라 "직접 굴리는 입력"이다** (문서 8절).
   정지·관성 롤·엄마가 미는 중에는 전부 쏠 수 있고, 내가 바퀴를 굴리는 동안에만 못 쏜다.
   수치는 `Balance.SPREAD_BY_DRIVE`, 판정은 `WheelchairPlayer._update_drive_state()`.
2. **킬러 배치는 `GameState.run_seed` 로 결정되고 루프 내내 고정이다.**
   이게 깨지면 타임루프 학습이 통째로 무의미해진다. 루프마다 초기화되는 것은 처치 기록과 수배뿐이다.
3. **같은 위장을 쓴 민간인이 반드시 함께 존재한다** (`NpcCatalog.KILLER_CATEGORIES`).
   외형으로 구분 가능해지는 순간 게임이 사라진다.

## 프로젝트 구조

```
res://
├── scenes/main.tscn      # 씬 파일은 이것 하나뿐. 나머지는 전부 코드로 조립한다.
├── scripts/
│   ├── main.gd           # 진입점. 액터 생성 + 루프 수명 주기 배선.
│   ├── globals/          # 순수 데이터 (RefCounted). 로직 없음.
│   │   ├── enums.gd      # 전역 열거형
│   │   ├── balance.gd    # 모든 튜닝 수치의 단일 원천
│   │   └── npc_catalog.gd# 위장 / 킬러 규격 / 배치 슬롯
│   ├── player/           # wheelchair_player.gd, mom.gd
│   ├── npc/              # npc.gd, bomb.gd, helicopter.gd, heli_hitbox.gd
│   ├── world/            # town.gd, build.gd, fx.gd, rail.gd, stair_lift.gd, escape_zone.gd
│   └── ui/               # hud.gd, crosshair.gd, loop_screen.gd
├── autoload/             # EventBus -> GameState -> LoopManager (등록 순서 = 의존 순서)
├── assets/fonts/         # NotoSansKR.ttf (SIL OFL). 한글 UI 에 필수.
├── docs/GDD.md
└── tests/                # smoke_check (헤드리스 통합 점검), capture (스크린샷)
```

### 왜 씬 파일이 하나뿐인가

외부 3D 에셋 없이 프리미티브만 쓰는 프로토타입이라, 노드 트리를 `.tscn` 대신 코드
(`WheelchairPlayer.create()`, `Town.create()` 같은 정적 팩토리)로 조립한다.
지오메트리가 데이터 테이블에서 나오므로 이 편이 diff 와 검증이 쉽다.
**에셋 파이프라인이 생기면 이 결정을 다시 봐야 한다.**

## Autoload

- **EventBus** — 시그널 허브. 시스템 간 직접 참조 대신 전부 여기를 경유한다.
- **GameState** — 한 판의 진실원. 시드 / 킬러 배치 / 루프를 넘어 유지되는 지식 / 이번 루프 처치 기록.
- **LoopManager** — 루프 수명 주기 + 수배 사다리. `end_loop()` -> 정지 -> `loop_reset_requested`.

## 좌표 규약 (자주 틀리는 곳)

- Godot 노드의 정면은 **-Z**. 마을 루트는 **+Z 방향**이므로 스폰 yaw 는 `Balance.SPAWN_YAW`(=PI).
- 플레이어 정면/후면은 `player.forward_direction()` / `back_direction()` 을 쓴다. 직접 sin/cos 하지 않는다.
- **+Z 를 보고 있을 때 월드 +X 는 화면 왼쪽**이다. 배치 좌표를 눈으로 검증할 때 헷갈리기 쉽다.
- NPC 와 엄마의 비주얼은 자기들끼리 일관되게 **+Z 를 정면**으로 만들어져 있다 (`_facing = atan2(x, z)`).
  카메라가 달린 플레이어만 -Z 규약을 따른다.

## 물리 레이어

`Build.LAYER_WORLD(1) / LAYER_PLAYER(2) / LAYER_NPC(4) / LAYER_TRIGGER(8)`.
플레이어와 NPC는 서로 충돌하지 않는다 (휠체어가 군중에 끼는 것을 막기 위해 의도적).
총알 레이는 `WORLD | NPC`, 시야 판정 레이는 `WORLD` 만.

## 검증

```bash
godot --headless --path . tests/smoke_check.tscn   # 55 체크. 종료 코드로 성공/실패.
godot --path . tests/capture.tscn -- <출력폴더>     # 구역별 스크린샷 8장.
```

`smoke_check` 는 실제 물리를 돌려서 이동 속도와 구동 상태 전이까지 확인한다.
기능을 고쳤으면 여기에 체크를 추가한다.

## 네이밍 / 스타일

- 파일/폴더 `snake_case`, 클래스 `PascalCase`, 변수/함수 `snake_case`, 상수 `SCREAMING_SNAKE_CASE`.
- 파일 상단 순서: `class_name` → `extends` → 시그널 → enum → const → `@export` → 변수 → 함수.
- **정적 타이핑 필수**. 들여쓰기 탭, 함수 사이 빈 줄 2개, 최대 줄 길이 100.
- **밸런스 수치는 전부 `scripts/globals/` const 로 외부화.** 로직에 숫자 하드코딩 금지.
- 주석은 "무엇"이 아니라 "왜"를 적는다. 특히 기획 문서의 어느 조항에서 온 규칙인지 남긴다.

## 외부 도구

- **Godot**: `C:\Users\SangWook Lee\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe` (PATH 미등록)
- **gdtoolkit**: 미설치. 설치하면 `gdformat` → `gdlint` 를 수정한 `.gd` 에 적용할 것.

## 주의

- `.godot/` 는 빌드 캐시. 손대지 않는다.
- `assets/fonts/NotoSansKR.ttf` 를 지우면 **한글 UI 가 전부 빈 네모로 깨진다.**
- 장애 희화화 리스크(문서 17절)는 코드 주석이 아니라 연출로 관리한다.
  웃음의 대상은 휠체어가 아니라 과장된 암살자 세계와 물리다. 새 콘텐츠를 넣을 때 이 선을 지킬 것.
