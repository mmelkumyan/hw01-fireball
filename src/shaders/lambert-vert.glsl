#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself
uniform float u_Time; 

uniform float u_TimeScale; // noise scroll rate along x
uniform float u_TrailWidthBias; // How round the front of the fireball is
uniform float u_MinLength; // Min length of the tail
uniform float u_MaxLength; // Max length of the tail
uniform float u_PulseFreq; // Rate at which we alternate between lengths
uniform float u_Twists; // N*PI rotations around the center from start->end
uniform float u_TwistSpeed; // Speed at which we rotate
uniform float u_NoiseScale; // Scale of noise offset
uniform int u_Octaves; // Number of octaves in FBM noise

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.


out vec4 fs_Pos;
out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out float fs_MaxDist; // Max distance of a vert in the -x direction
out float fs_Noise; // Normal offset noise

#include "./common.glsl"

const vec4 lightPos = vec4(5, 0, 0, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.


float sinTime(float amp, float freq) {
    return (sin(u_Time * freq) * 0.5f + 0.5f) * amp;
}

void main()
{
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.


    vec4 modelposition = u_Model * vs_Pos;   // Temporarily store the transformed vertex positions for use below

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    // Pulse width/length
    float trailWidth =  mix(1.f, 0.1f, sinTime(1.f, u_PulseFreq));
    float trailLength =  mix(u_MinLength, u_MaxLength, sinTime(1.f, u_PulseFreq));
    fs_MaxDist = u_MaxLength * 0.75;

    // Get scale based on x pos
    float xPosBlend = vs_Pos.x/2.f + 0.5f;  // [0-1] in x
    xPosBlend = bias(xPosBlend, u_TrailWidthBias);

    // Twist in XY plane
    vec3 twistP = vs_Pos.xyz;
    float angle = mix(0.f, u_Twists*3.14, xPosBlend) + u_Time * u_TwistSpeed;
    twistP.yz = rotatePoint2d(twistP.yz, vec2(0.f), angle);

    // Warp- offset 
    float noiseOffset = fbm3D(vs_Pos.xyz * 0.5f, u_Octaves) * 1.2f;

    // Sample noise
    vec3 timeOffset = vec3(u_Time * u_TimeScale, 0.f, 0.f);
    float noise = fbm3D(twistP.xyz * u_NoiseScale + timeOffset + noiseOffset, u_Octaves)*0.5f + 0.5f;
    fs_Noise = noise;

    // Split normals- along x, and yz
    vec3 n = normalize(vs_Nor.xyz);
    vec3 xN = vec3(n.x, 0.f, 0.f);
    vec3 yzN = vec3(0.f, n.y, n.z);

    float xBias = 0.5f;
    float yzBias = 0.05f;
    float xStretch = mix(trailLength, 1.f, bias(xPosBlend, xBias)); 
    float yzStretch = mix(trailWidth, 1.f, bias(xPosBlend, yzBias));

    // Offset normals
    modelposition.xyz += (xN * xStretch + yzN * yzStretch) * noise;
    fs_Pos = modelposition;

    // output screenspace position
    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
