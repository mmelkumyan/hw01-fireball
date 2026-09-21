#version 300 es
precision highp float;

#include "./common.glsl"

uniform float u_Time;
uniform vec2 u_Dimensions;
uniform vec3 u_Eye;
uniform vec3 u_Ref;
uniform vec3 u_Up;

in vec2 fs_UV;
out vec4 out_Col;

void main() {
    vec2 uv = fs_UV;
    // uv.x *= u_Dimensions.x / u_Dimensions.y;   // undo aspect squash

    uv = uv * 2.f - 1.f; //[0,1] -> [-1,1]

    // placeholder: radial falloff
    // float d = length(uv);
    // out_Col = vec4(mix(vec3(0.1, 0.05, 0.15), vec3(0.0), d), 1.0);

    float aspect = u_Dimensions.x / u_Dimensions.y;
    float tanFovy = tan(3.14f / 2.f * 0.5);

    vec3 forward = u_Eye - u_Ref;
    float len = length(forward);
    forward = forward / len;
    vec3 right = normalize(cross(forward, u_Up));
    vec3 up = cross(right, forward);

    vec3 screenPoint = u_Ref + fs_UV.x * len * aspect * tanFovy * right
                             + fs_UV.y * len * tanFovy * up;
    vec3 rayDir = normalize(screenPoint - u_Eye);

    float noise = perlinNoise3D(-rayDir * 1.5f - vec3(u_Time, 0.f, 0.f) * 0.0009f
                    + fbm3D(-rayDir * 2.f - vec3(u_Time, 0.f, 0.f) * 0.0003f, 5)
                    );
    noise = noise * 0.5f + 0.5f;

    float coverage = .3f;
    float softness = .15f;
    float cloudMask = createMask(gain(noise, .2f), coverage, softness);

    float cloudNoise = perlinNoise3D(-rayDir * 5.f - vec3(u_Time, 0.f, 0.f) * 0.0005f
                    + fbm3D(-rayDir * 6.f - vec3(u_Time, 0.f, 0.f) * 0.0008f, 5)
                    );
    
    float yBlend = rayDir.y * 0.5 + 0.5f;
    yBlend += cloudNoise * .3f;
    yBlend = clamp(yBlend, 0.f, 1.f);
    
    vec3 skyColor = palette(discretize(yBlend, 32), 
        vec3(0.500, 0.500, 0.348),
        vec3(0.500, 0.500, 0.208),
        vec3(0.428, 0.248, 0.500),
        vec3(0.000, 0.200, 0.500)
    );
    vec3 cloudColor = mix(vec3(1.f), skyColor, 0.35);
    cloudColor = cloudColor * remap(noise, 0.f,1.f, 0.5, 2.f);

    vec3 color = mix(cloudColor, skyColor, cloudMask);

    // Desaturate a bit
    // color = gain(co)


    out_Col = vec4(color, 1.f);
}
