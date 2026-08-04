class_name Josa
extends RefCounted

## 한국어 조사 자동 선택.
##
## "청소부 가(이) 움직인다" 같은 표기는 UI 품질을 떨어뜨린다.
## 앞 글자의 받침 유무로 조사를 고른다.
## 한글 음절은 U+AC00..U+D7A3 이고 (코드 - 0xAC00) % 28 != 0 이면 받침이 있다.

const HANGUL_START := 0xAC00
const HANGUL_END := 0xD7A3

## 받침이 있으면 true. 한글 음절이 아니면 false (영문/숫자는 받침 없음으로 취급).
static func has_final(word: String) -> bool:
	if word.is_empty():
		return false
	var code := word.unicode_at(word.length() - 1)
	if code < HANGUL_START or code > HANGUL_END:
		# 영문 약어(SWAT 등)는 받침 있음으로 읽는 편이 자연스럽다.
		return _latin_reads_as_final(word)
	return (code - HANGUL_START) % 28 != 0


static func _latin_reads_as_final(word: String) -> bool:
	var last := word.to_upper().substr(word.length() - 1, 1)
	# L, M, N, R, NG 로 끝나는 알파벳 읽기는 받침이 있다. (SWAT -> "스왓" 받침 있음)
	return not "AEIOUY".contains(last)


## 이/가
static func subject(word: String) -> String:
	return "%s%s" % [word, "이" if has_final(word) else "가"]


## 은/는
static func topic(word: String) -> String:
	return "%s%s" % [word, "은" if has_final(word) else "는"]


## 을/를
static func object(word: String) -> String:
	return "%s%s" % [word, "을" if has_final(word) else "를"]


## 으로/로
static func direction(word: String) -> String:
	return "%s%s" % [word, "으로" if has_final(word) else "로"]
