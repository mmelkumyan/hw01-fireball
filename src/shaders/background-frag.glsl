#version 300 es
precision highp float;

#include "./common.glsl"

uniform float u_Time;
uniform vec2 u_Dimensions;
uniform vec3 u_Eye;
uniform vec3 u_Ref;
uniform vec3 u_Up;
uniform float u_ScrollSpeed;

in vec2 fs_UV;
out vec4 out_Col;

void main() {
    float aspect = u_Dimensions.x / u_Dimensions.y;
    // FOV = PI/2 = 90 degrees
    float tanFovy = tan(3.14f / 1.8f * 0.5);

    // Get vectors of camera dir
    vec3 forward = u_Eye - u_Ref;
    float len = length(forward);
    forward = forward / len;
    vec3 right = normalize(cross(forward, u_Up));
    vec3 up = cross(right, forward);

    vec3 screenPoint = u_Ref + fs_UV.x * len * aspect * tanFovy * right
                             + fs_UV.y * len * tanFovy * up;
    vec3 rayDir = normalize(screenPoint - u_Eye);
    // Get ray from eye through pixel into the world

    // Create noise for cloud mask
    float noise = perlinNoise3D(-rayDir * 1.9f + vec3(u_Time, 0.f, 0.f) * 0.0009f * u_ScrollSpeed
                    + fbm3D(-rayDir * 2.f + vec3(u_Time, 0.f, 0.f) * 0.0003f * u_ScrollSpeed, 4)
                    );
    noise = noise * 0.5f + 0.5f;

    float coverage = .3f;
    float softness = .15f;
    float cloudMask = createMask(gain(noise, .2f), coverage, softness);

    // Create noise to perturb sky gradient 
    float skyNoise = perlinNoise3D(-rayDir * 5.f + vec3(u_Time, -u_Time/1.f, 0.f) * 0.0005f * u_ScrollSpeed
                    + fbm3D(-rayDir * 6.f + vec3(u_Time, -u_Time/1.f, 0.f) * 0.0008f * u_ScrollSpeed, 4)
                    );
    float yBlend = (rayDir.y * 0.5 + 0.5f) + skyNoise * .3f;
    yBlend = clamp(yBlend, 0.f, 1.f);

    // Set sky color and cloud colors
    vec3 skyColor = palette(discretize(yBlend, 32), 
        // vec3(0.500, 0.500, 0.348),
        // vec3(0.500, 0.500, 0.208),
        // vec3(0.428, 0.248, 0.500),
        // vec3(0.000, 0.200, 0.500)
        vec3( 0.048, 0.358, 0.588),
        vec3( 0.158, 0.698, -0.382),
        vec3( 0.228, 0.138, 0.448),
        vec3(-1.232, 1.188, 0.518)
    );
    vec3 cloudColor = mix(vec3(1.f), skyColor, 0.35); // Clouds mix in a little bit of sky color
    cloudColor = cloudColor * remap(noise, 0.f,1.f, 0.5, 2.f);

    // Final color mix
    vec3 color = mix(cloudColor, skyColor, cloudMask);

    out_Col = vec4(color, 1.f);
}
