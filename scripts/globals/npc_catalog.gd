class_name NpcCatalog
extends RefCounted

## 위장 외형 / 킬러 타입 / 배치 슬롯 데이터. 순수 데이터 — 로직 없음.
##
## 핵심 규칙: 같은 위장(disguise)을 쓴 민간인과 킬러가 함께 존재한다.
## 따라서 외형만으로는 절대 구분할 수 없고, 텔(tell)과 루프 학습으로만 판별된다.

## 위장 외형. body/accent 는 절차적으로 만드는 NPC 메시 색.
const DISGUISES := {
	"nurse": {"name": "간호사", "body": Color(0.86, 0.90, 0.94), "accent": Color(0.35, 0.62, 0.75), "prop": "clipboard"},
	"janitor": {"name": "청소부", "body": Color(0.31, 0.44, 0.32), "accent": Color(0.72, 0.68, 0.30), "prop": "broom"},
	"jogger": {"name": "조깅하는 사람", "body": Color(0.85, 0.35, 0.30), "accent": Color(0.18, 0.18, 0.20), "prop": "none"},
	"driver": {"name": "자동차 운전자", "body": Color(0.28, 0.32, 0.40), "accent": Color(0.60, 0.60, 0.64), "prop": "none"},
	"taxi": {"name": "택시 운전사", "body": Color(0.90, 0.74, 0.18), "accent": Color(0.15, 0.15, 0.18), "prop": "none"},
	"delivery": {"name": "피자 배달부", "body": Color(0.88, 0.45, 0.12), "accent": Color(0.92, 0.88, 0.78), "prop": "box"},
	"window": {"name": "창가의 주민", "body": Color(0.55, 0.48, 0.66), "accent": Color(0.30, 0.28, 0.34), "prop": "none"},
	"roofer": {"name": "옥상 작업자", "body": Color(0.70, 0.62, 0.34), "accent": Color(0.90, 0.78, 0.20), "prop": "none"},
	"vendor": {"name": "노점 상인", "body": Color(0.46, 0.36, 0.28), "accent": Color(0.78, 0.70, 0.55), "prop": "none"},
	"shopper": {"name": "장 보는 시민", "body": Color(0.40, 0.55, 0.48), "accent": Color(0.80, 0.76, 0.70), "prop": "bag"},
	"resident": {"name": "동네 주민", "body": Color(0.52, 0.52, 0.60), "accent": Color(0.72, 0.66, 0.58), "prop": "none"},
	"police": {"name": "경찰", "body": Color(0.16, 0.22, 0.42), "accent": Color(0.85, 0.85, 0.90), "prop": "none"},
	"swat": {"name": "SWAT", "body": Color(0.13, 0.14, 0.16), "accent": Color(0.35, 0.38, 0.42), "prop": "none"},
}

## 킬러 타입별 전투 규격과 판별 단서.
## tell 은 루프 화면 / 코덱스에 그대로 노출되는 학습 문구다.
const KILLER_DEFS := {
	Enums.KillerType.CLEANER:
	{
		"name": "클리너",
		"aggro": 15.0,
		"attack_range": 11.0,
		"damage": 30.0,
		"interval": 0.85,
		"windup": 0.45,
		"speed": 2.1,
		"ranged": true,
		"tell": "가까워지면 빗자루를 놓고 허리춤으로 손이 간다.",
	},
	Enums.KillerType.RUNNER:
	{
		"name": "러너",
		"aggro": 24.0,
		"attack_range": 2.1,
		"damage": 58.0,
		"interval": 0.75,
		"windup": 0.25,
		"speed": 5.6,
		"ranged": false,
		"tell": "정해진 코스를 벗어나 뒤로 돌아 접근한 뒤 칼을 꺼낸다.",
	},
	Enums.KillerType.DRIVER:
	{
		"name": "드라이버",
		"aggro": 34.0,
		"attack_range": 3.0,
		"damage": 85.0,
		"interval": 2.2,
		"windup": 0.9,
		"speed": 14.0,
		"ranged": false,
		"tell": "도로에 진입하면 시동을 걸고 그대로 돌진한다.",
	},
	Enums.KillerType.TAXI:
	{
		"name": "택시 킬러",
		"aggro": 30.0,
		"attack_range": 22.0,
		"damage": 26.0,
		"interval": 0.55,
		"windup": 1.1,
		"speed": 12.0,
		"ranged": true,
		"tell": "플레이어 옆으로 급정차한 뒤 창문에서 사격한다.",
	},
	Enums.KillerType.DELIVERY:
	{
		"name": "배달 킬러",
		"aggro": 22.0,
		"attack_range": 17.0,
		"damage": 70.0,
		"interval": 2.4,
		"windup": 1.0,
		"speed": 2.4,
		"ranged": true,
		"tell": "상자를 어깨 위로 들어올리면 폭탄이 날아온다.",
	},
	Enums.KillerType.SNIPER:
	{
		"name": "스나이퍼",
		"aggro": 85.0,
		"attack_range": 85.0,
		"damage": 62.0,
		"interval": 2.6,
		"windup": 1.7,
		"speed": 0.0,
		"ranged": true,
		"tell": "고지대에서 붉은 레이저가 잠깐 스친 뒤 총성이 온다.",
	},
	Enums.KillerType.CROWD:
	{
		"name": "군중 킬러",
		"aggro": 9.0,
		"attack_range": 8.0,
		"damage": 34.0,
		"interval": 0.8,
		"windup": 0.5,
		"speed": 2.6,
		"ranged": true,
		"tell": "특정 거리 안으로 들어가면 그때서야 품에서 무기를 꺼낸다.",
	},
}

## 킬러 배치 카테고리. 매 판 각 카테고리에서 정확히 한 명이 킬러가 된다.
## 나머지 슬롯은 전부 진짜 민간인이다. (문서 16절: 숨은 킬러 5종 + 군중 킬러)
const KILLER_CATEGORIES := [
	{"type": Enums.KillerType.CLEANER, "slots": ["hosp_janitor", "road_cleaner", "plaza_cleaner"]},
	{"type": Enums.KillerType.RUNNER, "slots": ["road_jogger", "shop_jogger", "plaza_jogger"]},
	{"type": Enums.KillerType.SNIPER, "slots": ["house_window", "house_roof"]},
	{"type": Enums.KillerType.DELIVERY, "slots": ["shop_delivery", "plaza_delivery"]},
	{"type": Enums.KillerType.TAXI, "slots": ["road_taxi", "road_car"]},
	{
		"type": Enums.KillerType.CROWD,
		"slots": ["shop_vendor", "shop_shopper", "house_resident", "plaza_citizen_a", "plaza_citizen_b"]
	},
]

## 차량으로 표현되는 슬롯. 킬러일 때 DRIVER/TAXI 로 동작한다.
const VEHICLE_SLOTS := ["road_taxi", "road_car"]

## NPC 배치 슬롯. pos 는 스폰 위치, route 는 순찰 경유지(비었으면 제자리).
## elevated 슬롯은 창문/옥상이라 이동하지 않는다.
const SLOTS := [
	{
		"id": "hosp_nurse",
		"disguise": "nurse",
		"zone": Enums.Zone.HOSPITAL,
		"pos": Vector3(3.0, 0.0, 8.0),
		"route": [Vector3(3.0, 0.0, 8.0), Vector3(-2.0, 0.0, 6.0), Vector3(3.5, 0.0, 13.0)],
	},
	{
		"id": "hosp_janitor",
		"disguise": "janitor",
		"zone": Enums.Zone.HOSPITAL,
		"pos": Vector3(-4.0, 0.0, 12.5),
		"route": [Vector3(-4.0, 0.0, 12.5), Vector3(-4.5, 0.0, 4.0), Vector3(1.0, 0.0, 14.0)],
	},
	{
		"id": "road_jogger",
		"disguise": "jogger",
		"zone": Enums.Zone.ROAD,
		"pos": Vector3(7.5, 0.0, 24.0),
		"route": [Vector3(7.5, 0.0, 22.0), Vector3(7.5, 0.0, 45.0), Vector3(-7.5, 0.0, 45.0), Vector3(-7.5, 0.0, 22.0)],
	},
	{
		"id": "road_cleaner",
		"disguise": "janitor",
		"zone": Enums.Zone.ROAD,
		"pos": Vector3(-8.5, 0.0, 38.0),
		"route": [Vector3(-8.5, 0.0, 34.0), Vector3(-8.5, 0.0, 46.0)],
	},
	{
		"id": "road_taxi",
		"disguise": "taxi",
		"zone": Enums.Zone.ROAD,
		"pos": Vector3(4.2, 0.0, 46.0),
		"route": [Vector3(4.2, 0.0, 46.0), Vector3(4.2, 0.0, 19.0)],
	},
	{
		"id": "road_car",
		"disguise": "driver",
		"zone": Enums.Zone.ROAD,
		"pos": Vector3(-4.2, 0.0, 18.0),
		"route": [Vector3(-4.2, 0.0, 18.0), Vector3(-4.2, 0.0, 47.0)],
	},
	{
		"id": "shop_vendor",
		"disguise": "vendor",
		"zone": Enums.Zone.SHOPS,
		"pos": Vector3(-9.0, 0.0, 57.0),
		"route": [],
	},
	{
		"id": "shop_shopper",
		"disguise": "shopper",
		"zone": Enums.Zone.SHOPS,
		"pos": Vector3(4.5, 0.0, 62.0),
		"route": [Vector3(4.5, 0.0, 62.0), Vector3(-5.0, 0.0, 66.0), Vector3(6.0, 0.0, 74.0)],
	},
	{
		"id": "shop_delivery",
		"disguise": "delivery",
		"zone": Enums.Zone.SHOPS,
		"pos": Vector3(8.5, 0.0, 72.0),
		"route": [Vector3(8.5, 0.0, 72.0), Vector3(8.5, 0.0, 58.0), Vector3(2.0, 0.0, 80.0)],
	},
	{
		"id": "shop_jogger",
		"disguise": "jogger",
		"zone": Enums.Zone.SHOPS,
		"pos": Vector3(-5.5, 0.0, 79.0),
		"route": [Vector3(-5.5, 0.0, 79.0), Vector3(-5.5, 0.0, 52.0), Vector3(6.0, 0.0, 52.0), Vector3(6.0, 0.0, 79.0)],
	},
	{
		"id": "house_window",
		"disguise": "window",
		"zone": Enums.Zone.HOUSES,
		"pos": Vector3(-11.6, 6.4, 96.0),
		"route": [],
	},
	{
		"id": "house_roof",
		"disguise": "roofer",
		"zone": Enums.Zone.HOUSES,
		"pos": Vector3(12.0, 9.4, 106.0),
		"route": [],
	},
	{
		"id": "house_resident",
		"disguise": "resident",
		"zone": Enums.Zone.HOUSES,
		"pos": Vector3(2.5, 0.0, 100.0),
		"route": [Vector3(2.5, 0.0, 100.0), Vector3(-3.0, 0.0, 110.0), Vector3(5.0, 0.0, 112.0)],
	},
	{
		"id": "plaza_cleaner",
		"disguise": "janitor",
		"zone": Enums.Zone.PLAZA,
		"pos": Vector3(-6.5, 0.0, 124.0),
		"route": [Vector3(-6.5, 0.0, 124.0), Vector3(7.0, 0.0, 126.0), Vector3(0.0, 0.0, 140.0)],
	},
	{
		"id": "plaza_delivery",
		"disguise": "delivery",
		"zone": Enums.Zone.PLAZA,
		"pos": Vector3(9.5, 0.0, 132.0),
		"route": [Vector3(9.5, 0.0, 132.0), Vector3(9.5, 0.0, 120.0)],
	},
	{
		"id": "plaza_citizen_a",
		"disguise": "resident",
		"zone": Enums.Zone.PLAZA,
		"pos": Vector3(0.5, 0.0, 137.0),
		"route": [Vector3(0.5, 0.0, 137.0), Vector3(-8.0, 0.0, 133.0), Vector3(6.0, 0.0, 142.0)],
	},
	{
		"id": "plaza_citizen_b",
		"disguise": "shopper",
		"zone": Enums.Zone.PLAZA,
		"pos": Vector3(-10.0, 0.0, 139.0),
		"route": [Vector3(-10.0, 0.0, 139.0), Vector3(-2.0, 0.0, 122.0)],
	},
	{
		"id": "plaza_jogger",
		"disguise": "jogger",
		"zone": Enums.Zone.PLAZA,
		"pos": Vector3(6.5, 0.0, 120.0),
		"route": [Vector3(6.5, 0.0, 120.0), Vector3(6.5, 0.0, 143.0), Vector3(-9.0, 0.0, 143.0), Vector3(-9.0, 0.0, 120.0)],
	},
]


static func slot_by_id(id: String) -> Dictionary:
	for slot: Dictionary in SLOTS:
		if slot["id"] == id:
			return slot
	return {}


static func disguise_name(key: String) -> String:
	if DISGUISES.has(key):
		return String(DISGUISES[key]["name"])
	return key


static func killer_name(type: Enums.KillerType) -> String:
	if KILLER_DEFS.has(type):
		return String(KILLER_DEFS[type]["name"])
	return "민간인"


static func zone_name(zone: Enums.Zone) -> String:
	match zone:
		Enums.Zone.HOSPITAL:
			return "병원"
		Enums.Zone.ROAD:
			return "병원 앞 도로"
		Enums.Zone.SHOPS:
			return "상점가"
		Enums.Zone.HOUSES:
			return "주택가"
		Enums.Zone.PLAZA:
			return "광장"
		Enums.Zone.ESCAPE:
			return "탈출 지점"
	return "?"
