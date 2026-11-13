class_name HeadShapes
## 머리 스프라이트(PNG)의 알파 외곽선을 추출해 콜라이더/압출 레이어용 실루엣을 만든다.
## 순서 = 합체 단계: 0 치이카와(둥근형) -> 1 하치와레(뾰족귀) -> 2 우사기(긴귀)

const KINDS := ["chiikawa", "hachiware", "usagi"]
const NAMES := ["치이카와", "하치와레", "우사기"]
const RAD := [34.0, 44.0, 56.0]   # 단계별 등가 반지름(px) = sqrt(면적/PI)
const STATES := ["neutral", "surprised", "squash", "happy"]
const EPSILON := 3.0              # 외곽선 단순화 정도(텍스처 px)

static var _cache := {}

static func area_centroid(p: PackedVector2Array) -> Array:
	var a := 0.0
	var c := Vector2.ZERO
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		var cr := p[i].x * q.y - q.x * p[i].y
		a += cr
		c += (p[i] + q) * cr
	a *= 0.5
	var cen := Vector2.ZERO
	if a != 0.0:
		cen = c / (6.0 * a)
	return [absf(a), cen]

## 단계 stage의 데이터: tex, size, outline(스케일 적용, 무게중심=원점), centroid_uv, extent_uv,
## area(스케일 적용), scale(텍스처px -> 월드px), color(평균색), top(윗쪽 돌출 길이)
static func get_data(stage: int) -> Dictionary:
	if _cache.has(stage):
		return _cache[stage]
	var texs := {}
	for st in STATES:
		texs[st] = load("res://assets/heads/%s_%s.png" % [KINDS[stage], st])
	var tex: Texture2D = texs["neutral"]   # 콜라이더/정렬은 neutral 기준 고정
	var img := tex.get_image()
	var bm := BitMap.new()
	bm.create_from_image_alpha(img, 0.5)
	var polys := bm.opaque_to_polygons(Rect2i(Vector2i.ZERO, bm.get_size()), EPSILON)
	var best := PackedVector2Array()
	var best_area := 0.0
	for p in polys:
		var a: float = area_centroid(p)[0]
		if a > best_area:
			best_area = a
			best = p
	var ac := area_centroid(best)
	var cen: Vector2 = ac[1]
	var s: float = RAD[stage] / sqrt(best_area / PI)

	var outline := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in best:
		outline.append((v - cen) * s)
		lo = lo.min(v)
		hi = hi.max(v)

	# 평균색(불투명 픽셀) - 압출 측면색에 사용
	var sum := Color(0, 0, 0, 0)
	var n := 0
	for y in range(0, img.get_height(), 6):
		for x in range(0, img.get_width(), 6):
			var c := img.get_pixel(x, y)
			if c.a > 0.9:
				sum += c
				n += 1
	var avg := Color(sum.r / maxi(n, 1), sum.g / maxi(n, 1), sum.b / maxi(n, 1))

	var size := Vector2(img.get_size())
	var top := 0.0
	for v in outline:
		top = maxf(top, -v.y)
	var data := {
		"tex": tex, "texs": texs, "size": size, "outline": outline, "scale": s,
		"area": best_area * s * s, "color": avg, "top": top,
		"centroid": cen,
		"centroid_uv": cen / size,
		"extent_uv": (hi - lo) * 0.5 / size,
	}
	_cache[stage] = data
	return data
