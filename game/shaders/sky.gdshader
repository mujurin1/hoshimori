shader_type sky;

uniform vec3 top_color : source_color = vec3(0.01, 0.015, 0.06);
uniform vec3 band_color : source_color = vec3(0.07, 0.06, 0.20);
uniform float star_amount = 1.0;
uniform vec3 glow_dir = vec3(0.0, 0.0, -1.0);
uniform vec3 glow_color : source_color = vec3(1.0, 0.55, 0.3);
uniform float glow_amount = 0.0;

float hash13(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float stars(vec3 d, float scale, float thresh) {
	vec3 p = d * scale;
	vec3 ip = floor(p);
	vec3 fp = fract(p) - 0.5;
	float h = hash13(ip);
	float s = smoothstep(thresh, 1.0, h);
	return s * smoothstep(0.32, 0.0, length(fp));
}

void sky() {
	vec3 d = normalize(EYEDIR);
	// 天の川っぽい帯
	float band = exp(-pow(d.y * 2.2 + 0.25 * sin(d.x * 3.0), 2.0));
	vec3 col = mix(top_color, band_color, band);
	float st = stars(d, 70.0, 0.965) * 2.6 + stars(d, 150.0, 0.95) * 1.2 + stars(d, 260.0, 0.93) * 0.5 * (0.5 + band);
	vec3 scol = mix(vec3(0.75, 0.85, 1.0), vec3(1.0, 0.9, 0.75), hash13(floor(d * 70.0) + 7.0));
	col += scol * st * star_amount;
	float g = max(dot(d, normalize(glow_dir)), 0.0);
	col = mix(col, glow_color, clamp(pow(g, 3.5) * glow_amount, 0.0, 1.0));
	col += glow_color * pow(g, 24.0) * glow_amount * 1.5;
	COLOR = col;
}
