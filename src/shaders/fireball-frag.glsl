#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;
in float fs_MaxDist;
in float fs_Noise;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

vec3 colorA = vec3(1.0f, 0.98f, 0.91f);
vec3 colorB = vec3(1.0f, 0.89f, 0.52f);
vec3 colorC = vec3(1.0f, 0.6f, 0.14f);
vec3 colorD = vec3(0.91f, 0.33f, 0.0f);
vec3 colorE = vec3(0.6f, 0.16f, 0.08f);
vec3 colorF = vec3(0.33f, 0.08f, 0.03f);
vec3 colorG = vec3(0.13f, 0.03f, 0.03f);
float edgeA = 0.2f;
float edgeB = 0.3f;
float edgeC = 0.4f;
float edgeD = 0.5f;
float edgeE = 0.65f;
float edgeF = 0.8f;
float edgeG = 0.99f;

vec3 colorGradient(float t) {
    vec3 c = colorA;
    c = mix(c, colorB, smoothstep(edgeA, edgeB, t));
    c = mix(c, colorC, smoothstep(edgeB, edgeC, t));
    c = mix(c, colorD, smoothstep(edgeC, edgeD, t));
    c = mix(c, colorE, smoothstep(edgeD, edgeE, t));
    c = mix(c, colorF, smoothstep(edgeE, edgeF, t));
    c = mix(c, colorG, smoothstep(edgeF, edgeG, t));
    return c;
}

float remap(float value, float inMin, float inMax, float outMin, float outMax) {
    return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
}


void main()
{
    // Calc dist from tip of fire ball
    float dist = length(abs(fs_Pos.xyz - vec3(1.f, 0.f, 0.f)));
    dist /= fs_MaxDist; // Normalize
    
    float noiseWidth = .19f;
    float noise = remap(fs_Noise, 0.3, 0.6, -noiseWidth, noiseWidth);
    float t = dist + noise;
    
    // Dist from tip + noise offset -> gradient map
    vec3 color = colorGradient(t);

    out_Col = vec4(color, 1.f);
}
