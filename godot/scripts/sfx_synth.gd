class_name SfxSynth
extends RefCounted
## 코드로 합성하는 효과음(별도 오디오 파일 없음). 음식 분수의 '뾰뵤복' 솟구치는 소리.

const RATE := 22050

## 분수가 솟는 동안(기본 3초) 이어지는 통통 튀는 방울 소리: 음이 위로 휘는 짧은 '뾰' 를 불규칙하게 겹치고, 끝에 낮은 '복' 으로 마무리
static func fountain(duration := 3.0) -> AudioStreamWAV:
	var n := int(duration * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7   # 항상 같은 소리
	var t := 0.0
	while t < duration - 0.25:
		var swell := clampf(0.55 + t / duration * 0.6, 0.0, 1.0) * (1.0 if t < duration - 0.6 else (duration - 0.25 - t) / 0.35 + 0.25)
		_pop(buf, t, rng.randf_range(240.0, 420.0), rng.randf_range(640.0, 1050.0), 0.13, 0.5 * swell)
		if rng.randf() < 0.4:   # 가끔 낮은 '뵤'/'복' 을 겹침
			_pop(buf, t + 0.05, rng.randf_range(150.0, 220.0), rng.randf_range(300.0, 460.0), 0.16, 0.35 * swell)
		t += rng.randf_range(0.1, 0.19)
	_pop(buf, duration - 0.3, 170.0, 70.0, 0.22, 0.6)   # 마지막 낮은 '복'
	return _to_wav(buf)

## 짧은 한 방울: 주파수가 f0 에서 f1 로 빠르게 휘고(부드럽게 올라가거나 내려가고), 시작은 빠르고 끝은 지수적으로 줄어든다
static func _pop(buf: PackedFloat32Array, start: float, f0: float, f1: float, length: float, vol: float) -> void:
	var s0 := int(start * RATE)
	var cnt := int(length * RATE)
	var phase := 0.0
	for k in cnt:
		var idx := s0 + k
		if idx >= buf.size():
			break
		var u := float(k) / cnt
		var f := lerpf(f0, f1, 1.0 - pow(1.0 - u, 2.2))
		phase += TAU * f / RATE
		var env := exp(-u * 4.5) * minf(1.0, u * 40.0)
		buf[idx] += (sin(phase) + 0.25 * sin(phase * 2.0)) * env * vol

static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var peak := 0.001
	for v in buf:
		peak = maxf(peak, absf(v))
	var gain := minf(0.9 / peak, 1.5)
	var data := PackedByteArray()
	data.resize(buf.size() * 2)
	for i in buf.size():
		data.encode_s16(i * 2, int(clampf(buf[i] * gain, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w
