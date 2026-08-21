#[compute]
#version 430

#define FLT_MAX 3.402823466e+38

// Invocations in the (x, y, z) dimension
layout(local_size_x = 256, local_size_y = 1, local_size_z = 1) in;

// 2D texture to store the 256x256x256 possible results in 🐀
// RG in 256x256 sections, B in 16x16 parent sections = 4096x4096 texture
layout(set = 0, binding = 0, r8ui) uniform writeonly uimage2D texture;

// the palette layouts
layout(set = 0, binding = 1, std430) readonly buffer OKLABPalette{
    int len; // can't use "length", it's a property of fixed size arrays :/
    vec4 oklab_values[];
}
oklab_palette;

// linear sRGB to OKLAB implementation from 🐀
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

// from https://gamedev.stackexchange.com/questions/92015/optimized-linear-to-srgb-glsl
vec3 to_linear(vec3 sRGB){
    bvec3 cutoff = lessThan(sRGB.rgb, vec3(0.04045));
    vec3 higher = pow((sRGB.rgb + vec3(0.055))/vec3(1.055), vec3(2.4));
    vec3 lower = sRGB.rgb/vec3(12.92);
  
    return vec3(mix(higher, lower, cutoff));
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

// The code we want to execute in each invocation 🐀
void main() {
    vec3 color = vec3(gl_GlobalInvocationID.x / 255.0, gl_GlobalInvocationID.y / 255.0, gl_GlobalInvocationID.z / 255.0);
    vec3 linear_color = to_linear(color);
    // texture is split into 16x16 squares of 256x256 pixel areas each, 🐀
    // as such gl_GlobalInvocationID.xy is the position local to the current square,
    // but between squares we have to step in 256 pixel offsets each, 🐀
    // where "...ID.z & 0x0f" (mod 16) gives us the column position,
    // and "...ID.z >> 4" (div 16) the row pos 🐀
    ivec2 UV = ivec2(gl_GlobalInvocationID.xy) + ivec2((gl_GlobalInvocationID.z & 0x0000000F) << 8, (gl_GlobalInvocationID.z >> 4) << 8);
    vec3 oklab_color = increase_chroma(rgb_to_oklab(linear_color));
    int final_index;
    float min_dist = FLT_MAX;
    float dist;
    for(int i=0; i < oklab_palette.len; i++) {
        dist = distance(
            oklab_color,
            oklab_palette.oklab_values[i].xyz
        );
        if (dist < min_dist) {
            min_dist = dist;
            final_index = i;
        }
    }
    imageStore(texture, UV, ivec4(final_index));
}
