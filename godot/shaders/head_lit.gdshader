shader_type canvas_item;

// 2.5D 입체감: 스프라이트 위에 월드 고정 광원의 약한 음영/하이라이트를 덧입힌다.
// 원본 색 유지, 밝기만 light_strength로 약하게 조절.
uniform vec2 light_dir = vec2(-0.5, -0.7); // 월드 기준 광원 방향(화면 좌상단)
uniform float body_rot = 0.0;              // 몸체 회전(라디안)
uniform vec2 center_uv = vec2(0.5);        // 무게중심(UV)
uniform vec2 extent_uv = vec2(0.5);        // 실루엣 반폭(UV)
uniform float light_strength = 0.3;      // 원본에 좌상단 음영이 구워져 있어 약하게(0=무조명)
uniform float flash = 0.0;                 // 합체 등 순간 하이라이트

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	vec2 p = (UV - center_uv) / extent_uv * 0.7;
	float d = clamp(length(p), 0.0, 1.0);
	float z = sqrt(1.0 - d * d);
	vec3 n = normalize(vec3(p, z * 0.9));
	float c = cos(body_rot);
	float s = sin(body_rot);
	vec2 nw = vec2(n.x * c - n.y * s, n.x * s + n.y * c);
	vec3 l = normalize(vec3(light_dir, 0.8));
	float diff = clamp(dot(vec3(nw, n.z), l) * 0.5 + 0.5, 0.0, 1.0);
	vec3 col = tex.rgb * (1.0 + (diff - 0.5) * light_strength) + vec3(flash);
	COLOR = vec4(col, tex.a);
}
