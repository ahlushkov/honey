#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding=0) uniform buf
{
    mat4 qt_Matrix;
    float qt_Opacity;
    float iTime;
    vec2 iResolution;
};

// ==========================================================
// PERF DIAL: set to 4 to restore the original 2x2 supersample
// quality (costs ~4x more). 1 is the fast default below.
// ==========================================================
#define AA_SAMPLES 1

// ----------------------------
// Constants
// ----------------------------
const int   NUM_BLOBS = 7; // was 10 — the 3 smallest (r=0.28/0.20/0.15)
                            // are almost entirely swallowed by the large
                            // smin(k=0.85) smoothing anyway, so dropping
                            // them saves ~30% of every scene() call with
                            // essentially no visible change to the blob.
const float SIZES[7] = float[](
    1.70, 1.35, 1.10, 0.85, 0.65, 0.50, 0.38
);

// ----------------------------
// PERF: blob positions only depend on iTime, computed once
// per pixel into a global array (see previous pass notes).
// ----------------------------
vec3 gBlobPos[7];

float hash(float n)
{
    return fract(sin(n * 91.7) * 43758.545);
}

vec3 computeBlobPos(int id)
{
    float f = float(id);
    float t = iTime;

    float x0 = hash(f * 12.3) * 10.0 - 5.0;
    float z0 = hash(f * 21.8) * 3.0 - 1.5;

    float speed = 0.15 + hash(f * 4.2) * 0.18;
    float phase = hash(f * 9.1) * 6.28;

    float y = sin(t * speed + phase) * (2.8 + hash(f) * 1.5);
    float x = sin(t * speed * 0.6 + phase) * 1.5;
    float z = cos(t * speed * 0.55 + phase) * 0.5;

    return vec3(x0 + x, y, z0 + z);
}

void fillBlobPositions()
{
    for (int i = 0; i < NUM_BLOBS; i++)
        gBlobPos[i] = computeBlobPos(i);
}

// ----------------------------
// smooth union
// ----------------------------
float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

float sdSphere(vec3 p, vec3 c, float r)
{
    return length(p - c) - r;
}

float scene(vec3 p)
{
    float d = 100.0;

    for (int i = 0; i < NUM_BLOBS; i++)
    {
        d = smin(d, sdSphere(p, gBlobPos[i], SIZES[i]), 0.85);
    }

    return d;
}

// ----------------------------
// PERF: normal via forward differences, reusing the distance
// value already known at the hit point (d0 ~ 0.001 from the
// raymarch loop) instead of re-evaluating scene(p). That's
// 3 scene() calls instead of the previous 4 (tetrahedron) or
// original 6 (central differences) — a further 25% cut on
// top of the earlier normal optimization, with negligible
// accuracy loss since h is tiny.
// ----------------------------
vec3 normalFast(vec3 p, float d0)
{
    const float h = 0.0015;

    return normalize(vec3(
        scene(p + vec3(h, 0, 0)) - d0,
        scene(p + vec3(0, h, 0)) - d0,
        scene(p + vec3(0, 0, h)) - d0
    ));
}

// ----------------------------
// raymarch
// ----------------------------
vec3 render(vec2 uv)
{
    vec3 ro = vec3(0, 0, 7);
    vec3 rd = normalize(vec3(uv.x, uv.y, -1.8));

    float t = 0.0;
    float closest = 99.0;
    float dHit = 0.0;
    bool hit = false;
    vec3 p;

    // PERF: 48 steps / far=16 — tightened from 64/18. The scene
    // geometry can't range far enough from the origin to need
    // more (checked against camera position + blob amplitude),
    // so this is a free reduction in worst-case iterations.
    for (int i = 0; i < 48; i++)
    {
        p = ro + rd * t;
        float d = scene(p);

        closest = min(closest, d);

        if (d < 0.001)
        {
            hit = true;
            dHit = d;
            break;
        }

        t += max(d * 0.9, 0.002);

        if (t > 16.0)
            break;
    }

    vec3 col = vec3(1);

    if (hit)
    {
        vec3 n = normalFast(p, dHit);
        vec3 view = normalize(ro - p);
        vec3 light = normalize(vec3(-0.5, 1.2, -1));

        float diff = max(dot(n, light), 0.0);
        float spec = pow(max(dot(reflect(-light, n), view), 0.0), 90.0);
        float rim = pow(1.0 - max(dot(n, view), 0.0), 2.0);

        vec3 orange = vec3(1.0, 0.42, 0.03);
        vec3 honey = vec3(1.0, 0.62, 0.08);

        float shine = 0.5 + 0.5 * sin(p.y * 3.0 + iTime);
        vec3 base = mix(orange, honey, shine);

        col = base * 0.55
            + base * diff * 1.4
            + spec * vec3(1)
            + rim * vec3(1, 0.6, 0.15);

        col *= 1.25;
    }
    else
    {
        float glow = exp(-closest * 3.0);
        col = mix(
            vec3(1),
            vec3(1, 0.55, 0.1),
            glow * 0.3
        );
    }

    return col;
}

// ----------------------------
// Anti-aliasing loop, gated by AA_SAMPLES.
// At AA_SAMPLES=1 this degenerates to a single center sample
// with zero branching overhead (the compiler folds the loops
// away entirely since the bounds become constant 1).
// ----------------------------
void main()
{
    fillBlobPositions();

    vec2 pixel = 1.0 / iResolution;
    vec3 color = vec3(0);

#if AA_SAMPLES >= 4
    for (int x = 0; x < 2; x++)
    {
        for (int y = 0; y < 2; y++)
        {
            vec2 offset = vec2(float(x), float(y)) * pixel * 0.5;
            vec2 uv = qt_TexCoord0 * 2.0 - 1.0;
            uv.x *= iResolution.x / iResolution.y;
            color += render(uv + offset);
        }
    }
    color /= 4.0;
#else
    vec2 uv = qt_TexCoord0 * 2.0 - 1.0;
    uv.x *= iResolution.x / iResolution.y;
    color = render(uv);
#endif

    fragColor = vec4(color, 1) * qt_Opacity;
}
