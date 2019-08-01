#version 460

#define saturate(x) min(max(x, 0.0), 1.0)

in vec2 vs_uv;
out vec4 fs_color;

layout(binding=0) uniform sampler2D tex;

layout(binding=1) buffer in_0
{
    vec4 buf0_col[];
};

uniform float u_time;
uniform float u_width;
uniform float u_height;
uniform uvec3 u_volume_size;
uniform vec2 u_movement;

struct VolumeSample
{
    float density;
    float distance;
    vec3 position;
};

uint VW = u_volume_size.x;
uint VWH = u_volume_size.x * u_volume_size.y;

float vmax(vec2 x)
{
    return max(x.x, x.y);
}

float vmax(vec3 x)
{
    return max(x.x, max(x.y, x.z));
}

float vmax(vec4 x)
{
    return max(max(x.x, x.y), max(x.z, x.w));
}

uint uvw_to_i(vec3 uvw)
{
    uvw = clamp(uvw, 0.0, 1.0);
    uvec3 xyz = uvec3(uvw * u_volume_size);
    return xyz.x + xyz.y * VW + xyz.z * VWH;
}

VolumeSample sample_volume(vec3 o, vec3 r)
{
    vec3 p;
    float t = 2.0;
    float d = 0.15;
    float density = 0.0;

    float c = cos(u_time);
    float s = sin(u_time);

    const float VOLUME_SCALE = 7.0;
    const float HALF_VOLUME_SCALE = VOLUME_SCALE * 0.5;
    
    for (int i = 0; i < 256; i++)
    {
        p = o + r * t;
        t += d;

        // p.xz = mat2(c, -s, s, c) * p.xz;

        vec3 uvw = (p.xyz - HALF_VOLUME_SCALE) / VOLUME_SCALE;
        if (vmax(abs(uvw)) > 1.0)
        {
            continue;
        }

        uint bi = uvw_to_i(uvw);
        density += buf0_col[bi].x * 0.008;

        if (density >= 1.0)
        {
            density = 1.0;
            break;
        }
    }

    VolumeSample vs = VolumeSample(
        density,
        t,
        o + r * t
    );
    return vs;
}

mat3 look_at(vec3 from, vec3 to)
{
    const vec3 UP = vec3(0.0, 1.0, 0.0);
    vec3 ww = normalize(to - from);
    vec3 uu = normalize(cross(ww, UP));
    vec3 vv = normalize(cross(uu, ww));

    return mat3(uu, vv, ww);
}

vec2 rotate_2d(vec2 o, float a)
{
    float c = cos(a);
    float s = sin(a);
    return mat2(c, -s, s, c) * o;
}

void main()
{
    vec2 uv = vs_uv;
    uv.x *= u_width / u_height;

    vec3 o = vec3(0.0, 5.0, 15.0);
    o.z += u_movement.y;
    o.xz = rotate_2d(o.xz, u_movement.x * 0.1);

    vec3 r = normalize(vec3(uv, 1.0));
    r = look_at(o, vec3(0.0)) * r;

    VolumeSample result = sample_volume(o, r);

    vec3 RGB = result.density * vec3(1.0, 0.8, 0.8);
    RGB = saturate(RGB);

    if (result.density > 0.0)
    {
        // RGB += normalize(abs(result.position));
    }
    fs_color = vec4(RGB, 1.0);
}
