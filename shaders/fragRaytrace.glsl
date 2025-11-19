#version 300 es
precision highp float;
precision highp int;

out vec4 FragColor;
#define gl_FragColor FragColor

uniform vec3 iResolution;
uniform float iTime;
uniform int uSampleCount;

#define PI 3.141592653589793

struct Sphere {
    vec3 center;
    float radius;
    vec3 albedo;
    vec3 emission;
};

struct Hit {
    float t;
    vec3 position;
    vec3 normal;
    vec3 albedo;
    vec3 emission;
};

#define NUM_SPHERES 4
#define MAX_BOUNCES 4
#define MAX_SAMPLES_PER_PIXEL 8

Sphere spheres[NUM_SPHERES];
vec3 rngState;

void setupScene() {
    spheres[0] = Sphere(
        vec3(cos(iTime * 0.002) * 0.5 + 0.1, -0.2, sin(iTime * 0.002) * 0.5),
        0.1,
        vec3(0.8, 0.35, 0.25),
        vec3(0.0)
    );
    spheres[1] = Sphere(
        vec3(-0.35, -0.15, 0.3),
        0.2,
        vec3(0.3, 0.65, 0.7),
        vec3(0.0)
    );
    spheres[2] = Sphere(
        vec3(0.0, 0.5, -0.2),
        0.05,
        vec3(0.0),
        vec3(15.0, 14.0, 12.0)
    );
    spheres[3] = Sphere(
        vec3(0.0, -100.35, 0.0),
        100.0,
        vec3(0.9),
        vec3(0.0)
    );
}

void cameraRay(vec2 p, out vec3 ro, out vec3 rd) {
    vec2 screen = p * 2.0 - 1.0;
    float aspect = iResolution.x / iResolution.y;
    screen.x *= aspect;

    ro = vec3(0.0, 0.0, -1.6);
    vec3 forward = vec3(0.0, 0.0, 1.0);
    vec3 right = vec3(1.0, 0.0, 0.0);
    vec3 up = vec3(0.0, 1.0, 0.0);

    float focalLength = 1.2;
    rd = normalize(screen.x * right + screen.y * up + focalLength * forward);
}

bool intersectSphere(vec3 ro, vec3 rd, Sphere s, out float t) {
    vec3 oc = ro - s.center;
    float a = dot(rd, rd);
    float b = 2.0 * dot(rd, oc);
    float c = dot(oc, oc) - s.radius * s.radius;
    float disc = b * b - 4.0 * a * c;
    if (disc < 0.0) return false;

    float h = sqrt(disc);
    float t0 = (-b - h) / (2.0 * a);
    float t1 = (-b + h) / (2.0 * a);
    t = (t0 > 0.0) ? t0 : t1;
    return t > 0.0;
}

void initSeed(vec2 fragCoord, float time, int sampleIdx) {
    rngState = vec3(fragCoord / iResolution.xy, fract(time * 0.001 + float(sampleIdx)));
}

float randFloat() {
    rngState = fract(rngState + vec3(0.1234567, 0.2345678, 0.3456789));
    float n = dot(rngState, vec3(12.9898, 78.233, 45.164));
    return fract(sin(n) * 43758.5453);
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
        if (intersectSphere(ro, rd, spheres[i], t) && t < closest) {
            closest = t;
            tempHit.t = t;
            tempHit.position = ro + rd * t;
            tempHit.normal = normalize(tempHit.position - spheres[i].center);
            tempHit.albedo = spheres[i].albedo;
            tempHit.emission = spheres[i].emission;
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

vec3 pathTrace(vec3 ro, vec3 rd) {
    vec3 radiance = vec3(0.0);
    vec3 throughput = vec3(1.0);

    for (int bounce = 0; bounce < MAX_BOUNCES; ++bounce) {
        Hit hit;
        if (!traceScene(ro, rd, hit)) {
            radiance += throughput * environment(rd);
            break;
        }

        radiance += throughput * hit.emission;

        throughput *= hit.albedo;
        if (max(throughput.r, max(throughput.g, throughput.b)) < 0.001) {
            break;
        }

        ro = hit.position + hit.normal * 0.001;
        rd = cosineSampleHemisphere(hit.normal);
    }

    return radiance;
}

void main() {
    setupScene();

    int samples = clamp(uSampleCount, 1, MAX_SAMPLES_PER_PIXEL);
    vec3 color = vec3(0.0);
    for (int sampleIdx = 0; sampleIdx < MAX_SAMPLES_PER_PIXEL; ++sampleIdx) {
        if (sampleIdx >= samples) break;
        initSeed(gl_FragCoord.xy, iTime, sampleIdx);
        vec2 jitter = vec2(randFloat(), randFloat());
        vec2 uv = (gl_FragCoord.xy + jitter) / iResolution.xy;
        vec3 ro, rd;
        cameraRay(uv, ro, rd);
        color += pathTrace(ro, rd);
    }

    color /= float(samples);
    color = pow(color, vec3(1.0 / 2.2));

    gl_FragColor = vec4(color, 1.0);
}
