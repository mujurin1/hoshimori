shader_type spatial;

// 頂点カラーで塗る共通マテリアル。flash で白く光り、tint で色を変える。
// (WebGL では個体ごとの instance uniform が効かないので、マテリアルを切り替えて使う)
uniform float flash = 0.0;
uniform vec4 tint = vec4(1.0);
uniform float rim_strength = 0.5;
uniform float glow = 0.06;
global uniform float vcol_gamma;

void fragment() {
	vec3 c = pow(COLOR.rgb, vec3(vcol_gamma)) * tint.rgb;
	float f = clamp(flash, 0.0, 1.0);
	ALBEDO = mix(c, vec3(1.0), f);
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = vec3(f) * 1.6 + c * rim * rim_strength + c * glow;
}
