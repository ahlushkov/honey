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

// ----------------------------
// smooth union
// ----------------------------
float smin(float a, float b, float k)
{
    float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

// ----------------------------
float hash(float n)
{
    return fract(sin(n * 91.7) * 43758.545);
}

// ----------------------------
float sdSphere(vec3 p, vec3 c, float r)
{
    return length(p - c) - r;
}

// ----------------------------
// compact screen-space motion
// ----------------------------
vec3 blobPos(int id)
{
    float f = float(id);
    float t = iTime;

    // Distributed transformation map pushing components into the corners
    float x0 = hash(f * 12.3) * 10.0 - 5.0;
    float z0 = hash(f * 21.8) * 3.0 - 1.5;

    float speed = 0.15 + hash(f * 4.2) * 0.18;
    float phase = hash(f * 9.1) * 6.28;

    float y = sin(t * speed + phase) * (2.8 + hash(f) * 1.5);
    float x = sin(t * speed * 0.6 + phase) * 1.5;
    float z = cos(t * speed * 0.55 + phase) * 0.5;

    return vec3(x0 + x, y, z0 + z);
}

// ----------------------------
// metaballs
// ----------------------------
float scene(vec3 p)
{
    float d = 100.0;

    // Up-scaled global volume sizes to maintain density ratios across corners
    float size[10] = float[](
        1.70,
        1.35,
        1.10,
        0.85,
        0.65,
        0.50,
        0.38,
        0.28,
        0.20,
        0.15
    );

    for(int i=0; i<10; i++)
    {
        d = smin(
            d,
            sdSphere(
                p,
                blobPos(i),
                size[i]
            ),
            0.85
        );
    }

    return d;
}

// ----------------------------
// fast normal
// ----------------------------
vec3 normal(vec3 p)
{
    float e = 0.0015;

    return normalize(vec3(
        scene(p + vec3(e, 0, 0)) - scene(p - vec3(e, 0, 0)),
        scene(p + vec3(0, e, 0)) - scene(p - vec3(0, e, 0)),
        scene(p + vec3(0, 0, e)) - scene(p - vec3(0, 0, e))
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
    bool hit = false;
    vec3 p;

    for(int i=0; i<80; i++)
    {
        p = ro + rd * t;
        float d = scene(p);

        closest = min(closest, d);

        if(d < 0.001)
        {
            hit = true;
            break;
        }

        t += max(d * 0.9, 0.002);

        if(t > 25.0)
            break;
    }

    vec3 col = vec3(1);

    if(hit)
    {
        vec3 n = normal(p);
        vec3 view = normalize(ro - p);
        vec3 light = normalize(vec3(-0.5, 1.2, -1));

        float diff = max(dot(n, light), 0);
        float spec = pow(max(dot(reflect(-light, n), view), 0), 90);
        float rim = pow(1 - max(dot(n, view), 0), 2.0);

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
// 2x2 anti alias
// ----------------------------
void main()
{
    vec2 pixel = 1.0 / iResolution;
    vec3 color = vec3(0);

    for(int x=0; x<2; x++)
    {
        for(int y=0; y<2; y++)
        {
            vec2 offset = vec2(float(x), float(y)) * pixel * 0.5;
            vec2 uv = qt_TexCoord0 * 2.0 - 1.0;

            uv.x *= iResolution.x / iResolution.y;

            color += render(uv + offset);
        }
    }

    color /= 4.0;

    fragColor = vec4(color, 1) * qt_Opacity;
}
