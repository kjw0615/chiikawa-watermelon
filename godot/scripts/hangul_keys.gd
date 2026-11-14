class_name HangulKeys
extends RefCounted
## 한글 -> 두벌식 자판 영문 변환. 한글 상태로 쳐 버린 비밀번호를 같은 키의 QWERTY 영문으로 되돌린다. (예: 한글 -> gksrmf, ㅁ -> a)

const CHO := ["r", "R", "s", "e", "E", "f", "a", "q", "Q", "t", "T", "d", "w", "W", "c", "z", "x", "v", "g"]
const JUNG := ["k", "o", "i", "O", "j", "p", "u", "P", "h", "hk", "ho", "hl", "y", "n", "nj", "np", "nl", "b", "m", "ml", "l"]
const JONG := ["", "r", "R", "rt", "s", "sw", "sg", "e", "f", "fr", "fa", "fq", "ft", "fx", "fv", "fg", "a", "q", "qt", "t", "T", "d", "w", "c", "z", "x", "v", "g"]
## 호환 자모(ㄱ~ㅣ, U+3131~U+3163) 낱글자
const JAMO := ["r", "R", "rt", "s", "sw", "sg", "e", "E", "f", "fr", "fa", "fq", "ft", "fx", "fv", "fg", "a", "q", "Q", "qt", "t", "T", "d", "w", "W", "c", "z", "x", "v", "g",
	"k", "o", "i", "O", "j", "p", "u", "P", "h", "hk", "ho", "hl", "y", "n", "nj", "np", "nl", "b", "m", "ml", "l"]

static func to_qwerty(text: String) -> String:
	var out := ""
	for ch in text:
		var c := ch.unicode_at(0)
		if c >= 0xAC00 and c <= 0xD7A3:   # 완성형 음절: 초성/중성/종성으로 분해
			var n := c - 0xAC00
			out += CHO[n / 588] + JUNG[(n % 588) / 28] + JONG[n % 28]
		elif c >= 0x3131 and c <= 0x3163:
			out += JAMO[c - 0x3131]
		else:
			out += ch
	return out
