shader_type spatial;

// ダッシュの無敵中だけプレイヤーに使う。画面の点を間引いて描き、薄くなったように見せる。
// 半透明（ALPHA）にしないのは、帽子を透かして中の頭が見えるため。
// 間引く位置は画面上の座標で決まるので、帽子と頭は同じ点が同時に抜け、内側が見えることはない
uniform float keep = 0.5; // 描く点の割合（0.25 / 0.5 / 0.75）
uniform vec4 tint = vec4(0.85, 0.95, 1.0, 1.0);
global uniform float vcol_gamma;

void fragment() {
	// 2x2 の並び（0, 2 / 3, 1）で、しきい値より大きい点を捨てる
	vec2 p = mod(floor(FRAGCOORD.xy), 2.0);
	float v = p.y < 0.5 ? (p.x < 0.5 ? 0.0 : 2.0) : (p.x < 0.5 ? 3.0 : 1.0);
	if ((v + 0.5) / 4.0 > keep) {
		discard;
	}
	vec3 c = pow(COLOR.rgb, vec3(vcol_gamma)) * tint.rgb;
	ALBEDO = c;
	ROUGHNESS = 0.8;
	SPECULAR = 0.25;
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.5);
	EMISSION = c * rim * 0.5 + c * 0.06;
}
