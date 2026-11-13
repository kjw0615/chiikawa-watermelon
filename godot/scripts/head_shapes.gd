class_name HeadShapes
## 머리 스프라이트(PNG)의 알파 외곽선을 추출해 콜라이더/압출 레이어용 실루엣을 만든다.
## 단계별 이미지/반지름은 NodeDefs(data/nodes.json)에서 가져온다. 반지름 = 등가 반지름 sqrt(면적/PI).

const STATES := ["neutral", "surprised", "squash", "happy"]
const CLOSE_RATIO := 0.10      # 콜라이더 모폴로지 닫기: 반지름 대비 이 비율만큼 팽창->수축해 작은 홈/뾰족한 털을 메움(톱니바퀴처럼 구르거나 끼는 현상 방지)
const EPSILON := 6.0              # 외곽선 단순화 정도(텍스처 px)

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
## 구르기/끼임 방지용 콜라이더 외곽선: 팽창 후 수축(닫기)으로 홈을 메우고 살짝 단순화
static func smooth_collider(outline: PackedVector2Array, r: float) -> PackedVector2Array:
	var d := r * CLOSE_RATIO
	var grown := Geometry2D.offset_polygon(outline, d, Geometry2D.JOIN_ROUND)
	if grown.is_empty():
		return outline
	var best := PackedVector2Array()
	var best_area := 0.0
	for g in grown:
		if Geometry2D.is_polygon_clockwise(g):
			continue   # 구멍 제외
		var a: float = area_centroid(g)[0]
		if a > best_area:
			best_area = a
			best = g
	var shrunk := Geometry2D.offset_polygon(best, -d, Geometry2D.JOIN_ROUND)
	if shrunk.is_empty():
		return outline
	best = shrunk[0]
	var bi := 0.0
	for g in shrunk:
		var a: float = area_centroid(g)[0]
		if a > bi:
			bi = a
			best = g
	return best

## 폴리곤의 면적당 극관성모멘트(무게중심 기준): I_c / A
static func polar_moment_per_area(p: PackedVector2Array) -> float:
	var io := 0.0
	var a2 := 0.0
	for i in p.size():
		var q := p[(i + 1) % p.size()]
		var cr := p[i].x * q.y - q.x * p[i].y
		a2 += cr
		io += cr * (p[i].x * p[i].x + p[i].x * q.x + q.x * q.x + p[i].y * p[i].y + p[i].y * q.y + q.y * q.y)
	var area := absf(a2) * 0.5
	var i_origin := absf(io) / 12.0
	var c: Vector2 = area_centroid(p)[1]
	return (i_origin - area * c.length_squared()) / area

static func get_data(stage: int) -> Dictionary:
	if _cache.has(stage):
		return _cache[stage]
	var texs := {}
	for st in STATES:
		texs[st] = load(NodeDefs.art_path(stage, st))
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
	var s: float = NodeDefs.radius(stage) / sqrt(best_area / PI)

	var outline := PackedVector2Array()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for v in best:
		outline.append((v - cen) * s)
		lo = lo.min(v)
		hi = hi.max(v)

	var collider := smooth_collider(outline, NodeDefs.radius(stage))
	var cac := area_centroid(collider)

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
		"area": best_area * s * s,
		"collider": collider, "com": cac[1], "inertia_k": polar_moment_per_area(collider), "color": avg, "top": top,
		"centroid": cen,
		"centroid_uv": cen / size,
		"extent_uv": (hi - lo) * 0.5 / size,
	}
	_cache[stage] = data
	return data
