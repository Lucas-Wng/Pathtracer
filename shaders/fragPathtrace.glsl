#version 300 es
precision highp float;
precision highp int;

out vec4 FragColor;
#define gl_FragColor FragColor

uniform vec3 iResolution;
uniform float iTime;
uniform int uSampleCount;
uniform sampler2D uPreviousFrame;
uniform int uFrameCount;
uniform bool uDisplayOnly;
uniform vec3 uCameraPos;
uniform vec3 uCameraForward;
uniform vec3 uCameraRight;
uniform vec3 uCameraUp;

#define PI 3.141592653589793

struct Sphere {
    vec3 center;
    float radius;
    vec3 albedo;
    vec3 emission;
    int material;
};

struct Box {
    vec3 minCorner;
    vec3 maxCorner;
    vec3 albedo;
    vec3 emission;
    int material;
};

struct Hit {
    float t;
    vec3 position;
    vec3 normal;
    vec3 albedo;
    vec3 emission;
    int material;
};

#define NUM_SPHERES 2
#define NUM_BOXES 7
#define MAX_BOUNCES 16
#define MAX_SAMPLES_PER_PIXEL 1024
#define MAT_DIFFUSE 0
#define MAT_MIRROR 1
#define MAT_GLASS 2

uint rngSeed;
uniform vec4 uSphereCenterRadius[NUM_SPHERES];
uniform vec4 uSphereAlbedo[NUM_SPHERES];
uniform vec4 uSphereEmission[NUM_SPHERES];
uniform int uSphereMaterial[NUM_SPHERES];
uniform vec4 uBoxMinCorner[NUM_BOXES];
uniform vec4 uBoxMaxCorner[NUM_BOXES];
uniform vec4 uBoxAlbedo[NUM_BOXES];
uniform vec4 uBoxEmission[NUM_BOXES];
uniform int uBoxMaterial[NUM_BOXES];

void loadSphere(int index, out Sphere sphere) {
    vec4 cr = uSphereCenterRadius[index];
    vec4 albedo = uSphereAlbedo[index];
    vec4 emission = uSphereEmission[index];
    sphere.center = cr.xyz;
    sphere.radius = cr.w;
    sphere.albedo = albedo.xyz;
    sphere.emission = emission.xyz;
    sphere.material = uSphereMaterial[index];
}

void loadBox(int index, out Box box) {
    box.minCorner = uBoxMinCorner[index].xyz;
    box.maxCorner = uBoxMaxCorner[index].xyz;
    box.albedo = uBoxAlbedo[index].xyz;
    box.emission = uBoxEmission[index].xyz;
    box.material = uBoxMaterial[index];
}

void cameraRay(vec2 p, out vec3 ro, out vec3 rd) {
    vec2 uv = p;
    vec3 d = uCameraRight * (uv.x - 0.5) +
             uCameraUp * (uv.y - 0.5) +
             uCameraForward;
    rd = normalize(d);
    ro = uCameraPos;
}

bool intersectSphere(vec3 ro, vec3 rd, Sphere s, out float tHit) {
    vec3 op = s.center - ro;
    float b = dot(op, rd);
    float det = b * b - dot(op, op) + s.radius * s.radius;
    if (det < 0.0) return false;

    det = sqrt(det);
    float eps = 1e-4;

    float t = b - det;
    if (t > eps) {
        tHit = t;
        return true;
    }

    t = b + det;
    if (t > eps) {
        tHit = t;
        return true;
    }

    return false;
}

bool intersectBox(vec3 ro, vec3 rd, Box box, out float tHit, out vec3 normal) {
    vec3 invDir = 1.0 / rd;
    vec3 t0 = (box.minCorner - ro) * invDir;
    vec3 t1 = (box.maxCorner - ro) * invDir;
    vec3 tmin = min(t0, t1);
    vec3 tmax = max(t0, t1);
    float tNear = max(max(tmin.x, tmin.y), tmin.z);
    float tFar = min(min(tmax.x, tmax.y), tmax.z);
    if (tFar < max(tNear, 0.0)) return false;

    tHit = tNear > 0.0 ? tNear : tFar;
    vec3 hitPos = ro + rd * tHit;
    const float eps = 1e-3;
    if (abs(hitPos.x - box.minCorner.x) < eps) {
        normal = vec3(-1.0, 0.0, 0.0);
    }
    else if (abs(hitPos.x - box.maxCorner.x) < eps) {
        normal = vec3(1.0, 0.0, 0.0);
    }
    else if (abs(hitPos.y - box.minCorner.y) < eps) {
        normal = vec3(0.0, -1.0, 0.0);
    }
    else if (abs(hitPos.y - box.maxCorner.y) < eps) {
        normal = vec3(0.0, 1.0, 0.0);
    }
    else if (abs(hitPos.z - box.minCorner.z) < eps) {
        normal = vec3(0.0, 0.0, -1.0);
    }
    else {
        normal = vec3(0.0, 0.0, 1.0);
    }

    if (dot(normal, rd) > 0.0) {
        normal = -normal;
    }

    return true;
}

uint hashSeed(uint seed) {
    seed = (seed ^ 61u) ^ (seed >> 16u);
    seed *= 9u;
    seed = seed ^ (seed >> 4u);
    seed *= 0x27d4eb2du;
    seed = seed ^ (seed >> 15u);
    return seed;
}

void initSeed(vec2 fragCoord, int frameCount, int sampleIdx) {
    ivec2 pixel = ivec2(floor(fragCoord));
    uint seed = uint(pixel.x) * 1973u;
    seed ^= uint(pixel.y) * 9277u;
    seed ^= uint(frameCount) * 2663u;
    seed ^= uint(sampleIdx) * 374761u;
    rngSeed = hashSeed(seed);
}

uint xorshift32() {
    rngSeed ^= rngSeed << 13u;
    rngSeed ^= rngSeed >> 17u;
    rngSeed ^= rngSeed << 5u;
    return rngSeed;
}

float randFloat() {
    return float(xorshift32()) * (1.0 / 4294967295.0);
}

vec3 cosineSampleHemisphere(vec3 normal) {
    float r1 = randFloat();
    float r2 = randFloat();
    float phi = 2.0 * PI * r1;
    float r = sqrt(r2);
    float x = r * cos(phi);
    float z = r * sin(phi);
    float y = sqrt(max(0.0, 1.0 - r2));

    vec3 u = normalize(abs(normal.y) < 0.999 ? cross(vec3(0.0, 1.0, 0.0), normal) : cross(vec3(1.0, 0.0, 0.0), normal));
    vec3 v = cross(normal, u);
    return normalize(u * x + v * z + normal * y);
}

bool traceScene(vec3 ro, vec3 rd, out Hit hit) {
    float closest = 1e9;
    bool found = false;
    Hit tempHit;

    for (int i = 0; i < NUM_SPHERES; i++) {
        float t;
        Sphere sphere;
        loadSphere(i, sphere);
        if (intersectSphere(ro, rd, sphere, t) && t < closest) {
            closest = t;
            tempHit.t = t;
            tempHit.position = ro + rd * t;
            tempHit.normal = normalize(tempHit.position - sphere.center);
            tempHit.albedo = sphere.albedo;
            tempHit.emission = sphere.emission;
            tempHit.material = sphere.material;
            found = true;
        }
    }

    for (int i = 0; i < NUM_BOXES; i++) {
        float t;
        vec3 normal;
        Box box;
        loadBox(i, box);
        if (intersectBox(ro, rd, box, t, normal) && t < closest) {
            closest = t;
            tempHit.t = t;
            tempHit.position = ro + rd * t;
            tempHit.normal = normal;
            tempHit.albedo = box.albedo;
            tempHit.emission = box.emission;
            tempHit.material = box.material;
            found = true;
        }
    }

    if (found) {
        hit = tempHit;
    }

    return found;
}

vec3 environment(vec3 rd) {
    float t = 0.5 * (rd.y + 1.0);
    return mix(vec3(0.35, 0.4, 0.55), vec3(0.8, 0.9, 1.0), t);
}

float schlick(float cosine, float refIdx) {
    float r0 = (1.0 - refIdx) / (1.0 + refIdx);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * pow(1.0 - cosine, 5.0);
}

vec3 pathTrace(vec3 ro, vec3 rd) {
    vec3 radiance = vec3(0.0);
    vec3 throughput = vec3(1.0);

    for (int bounce = 0; bounce < MAX_BOUNCES; bounce++) {
        Hit hit;
        if (!traceScene(ro, rd, hit)) {
            radiance += throughput * environment(rd);
            break;
        }

        radiance += throughput * hit.emission;

        float maxChannel = max(throughput.r, max(throughput.g, throughput.b));
        if (maxChannel < 0.001) {
            break;
        }

        if (hit.material == MAT_DIFFUSE) {
            throughput *= hit.albedo;
            ro = hit.position + hit.normal * 0.001;
            rd = cosineSampleHemisphere(hit.normal);
        }
        else if (hit.material == MAT_MIRROR) {
            throughput *= hit.albedo;
            rd = reflect(rd, hit.normal);
            ro = hit.position + rd * 0.002;
        }
        else if (hit.material == MAT_GLASS) {
            float etai = 1.0;
            float etat = 1.5;
            vec3 normal = hit.normal;
            float cosi = clamp(dot(rd, normal), -1.0, 1.0);
            if (cosi > 0.0) {
                normal = -normal;
                float temp = etai;
                etai = etat;
                etat = temp;
            }
            float etaRatio = etai / etat;
            float sint2 = etaRatio * etaRatio * (1.0 - cosi * cosi);
            bool cannotRefract = sint2 > 1.0;
            float cosTheta = clamp(-dot(rd, normal), 0.0, 1.0);
            float reflectProb = schlick(cosTheta, etat / etai);
            vec3 refrDir = refract(rd, normal, etaRatio);
            throughput *= hit.albedo;
            if (cannotRefract || randFloat() < reflectProb) {
                rd = reflect(rd, normal);
            }
            else {
                rd = normalize(refrDir);
            }
            ro = hit.position + rd * 0.002;
        }

        if (bounce >= 3) {
            float p = clamp(max(throughput.r, max(throughput.g, throughput.b)), 0.05, 0.95);
            if (randFloat() > p) {
                break;
            }
            throughput /= p;
        }
    }

    return radiance;
}

void main() {
    vec2 uv = gl_FragCoord.xy / iResolution.xy;
    if (uDisplayOnly) {
        vec3 displayColor = texture(uPreviousFrame, uv).rgb;
        displayColor = pow(displayColor, vec3(1.0 / 2.2));
        gl_FragColor = vec4(displayColor, 1.0);
        return;
    }
    
    initSeed(gl_FragCoord.xy, uFrameCount, 0);

    vec2 jitter = vec2(randFloat(), randFloat());
    vec2 jitteredUV = (gl_FragCoord.xy + jitter) / iResolution.xy;
    vec3 ro, rd;
    cameraRay(jitteredUV, ro, rd);
    vec3 newSample = pathTrace(ro, rd);
    
    // Accumulate with previous frame
    vec3 accumulated = texture(uPreviousFrame, uv).rgb;
    vec3 color = mix(accumulated, newSample, 1.0 / float(uFrameCount + 1));
    gl_FragColor = vec4(color, 1.0);
}
