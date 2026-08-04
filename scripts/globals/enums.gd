class_name Enums
extends RefCounted

## 프로젝트 전역 열거형. 데이터 전용 — 로직 없음.

## 킬러 타입 (문서 12절). NONE 은 진짜 민간인.
enum KillerType {
	NONE,
	CLEANER,  # 청소부 - 가까워지면 권총 사격
	RUNNER,  # 조깅하던 사람 - 뒤에서 접근 후 근접 공격
	DRIVER,  # 지나가던 자동차 운전자 - 차량 돌진
	TAXI,  # 택시 운전사 - 급정차 후 사격
	DELIVERY,  # 피자 배달부 - 폭탄 상자 투척
	SNIPER,  # 창가/옥상 인물 - 원거리 저격
	CROWD,  # 평범한 시민 - 특정 거리 안에서 무기 꺼냄
}

## NPC 소속. 판별과 수배 계산의 기준.
enum NpcKind {
	CIVILIAN,
	KILLER,
	POLICE,
	SWAT,
}

## 수배 단계 (문서 7절). 단계가 오를수록 강한 병력이 출동한다.
enum Wanted {
	CLEAR,
	ALERT,  # 신고 / 경계 상승
	POLICE,  # 경찰 출동
	SWAT,  # SWAT 출동
	HELI,  # 헬기 출동
	JET,  # 전투기 - 미사일로 강제 Game Over
}

## 휠체어 구동 상태 (문서 8절 표). 사격 가부를 결정한다.
enum Drive {
	STOPPED,  # 완전 정지 - 정밀 조준 + 사격 가능
	SELF,  # 직접 휠체어 조작 중 - 사격 불가
	COAST,  # 관성으로 굴러가는 중 - 사격 가능
	PUSHED,  # 엄마가 미는 중 - 고속 이동 + 사격 가능
	CARRIED,  # 엄마가 들고 계단을 오르는 중 - 사격 불가
}

## 맵 구역 (문서 11절).
enum Zone {
	HOSPITAL,
	ROAD,
	SHOPS,
	HOUSES,
	PLAZA,
	ESCAPE,
}

## 루프가 끝난 이유. 루프 화면 문구와 학습 기록에 쓰인다.
enum LoopEnd {
	KILLED,  # 누군가에게 죽었다
	WANTED_OUT,  # 수배 단계 초과 - 전투기 미사일
	GAVE_UP,  # 플레이어가 스스로 루프를 되감았다
	ESCAPED,  # 클리어
}
