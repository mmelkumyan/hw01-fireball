// Shared helpers

#define PI 3.14159

// Requires a constant bound loop
#define MAX_OCTAVES 6

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

// octaves is capped at MAX_OCTAVES by the loop bound.
float fbm3D(vec3 uvw, int octaves) {
    float total = 0.f;
    float freq = 2.f;
    float amp = 0.5f;
    float persistence = 0.5f;

    for (int i = 0; i < MAX_OCTAVES; ++i) {
        if (i >= octaves) {
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

float gain(float t, float g) {
  if(t < 0.5f)
    return bias(t * 2.0,g)/2.0;
  else
    return bias(t * 2.0 - 1.0,1.0 - g)/2.0 + 0.5;
}

/*
float worleyNoise2D(vec2 uv, vec2 dims) {
    uv *= dims;

    vec2 uvInt = floor(uv);
    vec2 uvFract = fract(uv);

    float minDist = 1.0;
    for (int y=-1; y<=1; y++) {
        for (int x=-1; x<=1; x++) {
            vec2 neighbor = vec2(float(x), float(y));
            vec2 point = random2Dto2D(uvInt + neighbor);

            vec2 diff = neighbor + point - uvFract;
            float dist = length(diff);
            minDist = min(minDist, dist);
        }
    }
    return minDist;
}
*/

float worleyNoise3D(vec3 uvw, vec3 dims) {
    uvw *= dims;

    vec3 uvwInt = floor(uvw);
    vec3 uvwFract = fract(uvw);

    float minDist = 1.0;
    for (int z=-1; z<=1; z++) {
        for (int y=-1; y<=1; y++) {
            for (int x=-1; x<=1; x++) {
                vec3 neighbor = vec3(float(x), float(y), float(z));
                vec3 point = random3Dto3D(uvwInt + neighbor);

                vec3 diff = neighbor + point - uvwFract;
                float dist = length(diff);
                minDist = min(minDist, dist);
            }
        }
    }
    
    return minDist;
}

float discretize(float t, int bands) {
    float bands_f = float(bands);
    return floor(t * bands_f) / (bands_f - 1.f);
}
    
float createMask(float t, float coverage, float softness) {
    return smoothstep(coverage - softness/2.f, coverage + softness/2.f, t);
}

// https://dev.thi.ng/gradients/
vec3 palette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
    t = clamp(t, 0.f, 1.f);
    return a + b * cos(6.283185 * (c * t + d));
}

float remap(float value, float inMin, float inMax, float outMin, float outMax) {
    return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
}
