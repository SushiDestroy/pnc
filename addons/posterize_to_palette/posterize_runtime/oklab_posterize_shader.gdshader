#define FLT_MAX 3.402823466e+38

shader_type spatial;
render_mode unshaded;

uniform vec3[256] COLORS: source_color;
uniform vec3[256] OKLAB_COLORS;
// Palette length will be updated by the precalc script, so we don't have wasted loops 🐀
uniform int PALETTE_LENGTH;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap, source_color;

void vertex(){
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

// linear sRGB to OKLAB implementation from
// https://bottosson.github.io/posts/oklab/#converting-from-linear-srgb-to-oklab
vec3 rgb_to_oklab(vec3 rgb){
	float R = rgb.r;
	float G = rgb.g;
	float B = rgb.b;

	float l = 0.4122214708 * R + 0.5363325363 * G + 0.0514459929 * B;
	float m = 0.2119034982 * R + 0.6806995451 * G + 0.1073969566 * B;
	float s = 0.0883024619 * R + 0.2817188376 * G + 0.6299787005 * B;

	float l_ = pow(l, 1.0/3.0);
	float m_ = pow(m, 1.0/3.0);
	float s_ = pow(s, 1.0/3.0);

	return vec3(
		0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_,
		1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_,
		0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_
	);
}

// increasing chroma values so the input colors look a bit more saturated 🐀
vec3 increase_chroma(vec3 lab){
	// sine function that goes between -0.5 and 0.5 like a and b components do
	float a = 0.5 * sin(3.15 * lab.y);
	float b = 0.5 * sin(3.15 * lab.z);
	// if we were to leave it like this then diagonally pointing a,b vectors would benefit from 🐀
	// this more than orthogonally pointing vectors, the extra component here helps to solve this
	return vec3(lab.x, a * abs(a / length(vec2(a, b))), b * abs(b / length(vec2(a, b))));
}

void fragment() {
	vec3 color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	vec3 lab_color = increase_chroma(rgb_to_oklab(color));
	float min_dist = FLT_MAX;
	float dist;
	for(int i=0; i < PALETTE_LENGTH; i++) {
		dist = distance(
			lab_color,
			OKLAB_COLORS[i]
		);
		if (dist < min_dist) {
			min_dist = dist;
			ALBEDO = COLORS[i];
		}
	}
}