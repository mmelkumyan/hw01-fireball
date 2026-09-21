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

const vec4 lightPos = vec4(5, 0, 0, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.


#define PI 3.14159f;


// ----------- HELPERS ------------------
float quintic(float t) {
    return t * t * t * (t * (t * 6.f - 15.f) + 10.f);
}

vec3 quintic(vec3 xyz) {
    return vec3(quintic(xyz.x),
                quintic(xyz.y),
                quintic(xyz.z));
}

vec3 random3Dto3D(vec3 xyz) {
    vec3 sins = sin(vec3(dot(xyz, vec3(127.1f, 311.7f, 531.8f)),
                         dot(xyz, vec3(269.5f, 183.3f, 121.3f)),
                         dot(xyz, vec3(420.6f, 631.2f, 302.9f))));
    sins *= 43758.54f;
    return fract(sins);
}

float perlinNoise3D(vec3 uvw) {
    float surfletSum = 0.f;
    // Iterate over the eight corners around uvw
    for (int dx = 0; dx <= 1; ++dx) {
        for (int dy = 0; dy <= 1; ++dy) {
            for (int dz = 0; dz <= 1; ++dz) {
                vec3 gridPoint = floor(uvw) + vec3(dx, dy, dz);

                // Compute falloff function
                vec3 dist = abs(uvw - gridPoint);
                vec3 t = vec3(1.f) - quintic(dist);

                // Get random vector for the grid point
                vec3 gradient = 2.f * random3Dto3D(gridPoint) - vec3(1.f);

                // Get vector from grid point to uvw
                vec3 diff = uvw - gridPoint;

                // Get value of height field by dotting diff w/ gradient
                float height = dot(diff, gradient);

                // Scale height field by polynomial fallof func
                surfletSum += height * t.x * t.z * t.y;
            }
        }
    }
    return surfletSum;
}

// Requires a constant bound loop
#define MAX_OCTAVES 6

float fbm3D(vec3 uvw) {
    float total = 0.f;
    float freq = 2.f;
    float amp = 0.5f;
    float persistence = 0.5f;

    for (int i = 0; i < MAX_OCTAVES; ++i) {
        if (i >= u_Octaves) {
            break;
        }
        total += perlinNoise3D(uvw * freq) * amp;

        freq *= 2.f;
        amp *= persistence;
    }
    return total;
}

vec2 rotatePoint2d(vec2 uv, vec2 center, float angle)
{
    vec2 rotatedPoint = vec2(uv.x - center.x, uv.y - center.y);
    float newX = cos(angle) * rotatedPoint.x - sin(angle) * rotatedPoint.y;
    rotatedPoint.y = sin(angle) * rotatedPoint.x + cos(angle) * rotatedPoint.y;
    rotatedPoint.x = newX;
    return rotatedPoint;
}

float bias(float t, float b) {
    return (t / ((((1.0/b) - 2.0)*(1.0 - t))+1.0));
}

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
    float noiseOffset = fbm3D(vs_Pos.xyz * 0.5f) * 1.2f;

    // Sample noise
    vec3 timeOffset = vec3(u_Time * u_TimeScale, 0.f, 0.f);
    float noise = fbm3D(twistP.xyz * u_NoiseScale + timeOffset + noiseOffset)*0.5f + 0.5f;
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
