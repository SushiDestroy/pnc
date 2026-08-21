shader_type spatial;
render_mode unshaded;

uniform vec3[256] COLORS: source_color;
// The lookup table we get from our compute shader 🐀
uniform sampler2D PALETTE_LUT: filter_nearest, repeat_disable;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap, source_color;

void vertex(){
	POSITION = vec4(VERTEX.xy, 1.0-VERTEX.z, 1.0);
}

// from https://gamedev.stackexchange.com/questions/92015/optimized-linear-to-srgb-glsl 🐀
vec3 from_linear(vec3 linearRGB)
{
	bvec3 cutoff = lessThan(linearRGB.rgb, vec3(0.0031308));
	vec3 higher = vec3(1.055)*pow(linearRGB.rgb, vec3(1.0/2.4)) - vec3(0.055);
	vec3 lower = linearRGB.rgb * vec3(12.92);

	return mix(higher, lower, cutoff);
}

void fragment() {
	vec3 color = texture(SCREEN_TEXTURE, SCREEN_UV).rgb;
	color = from_linear(color);
	int b1 = int(clamp(color.b * 255.0, 0.0, 255.0)) & 0x0000000F;
	int b2 = int(clamp(color.b * 255.0, 0.0, 255.0)) >> 4;
	b1 = b1 << 8;
	b2 = b2 << 8;
	int r = int(clamp(color.r * 255.0, 0.0, 255.0));
	int g = int(clamp(color.g * 255.0, 0.0, 255.0));
	ivec2 lut_uv = ivec2(r, g) + ivec2(b1, b2);

	ALBEDO = COLORS[int(texelFetch(PALETTE_LUT, lut_uv, 0).r * 255.0)];
}