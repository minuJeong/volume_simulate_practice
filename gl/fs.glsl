#version 460

#define FAR 50.0

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
uniform vec3 u_movement;

struct VolumeSample
{
    float density;
    float distance;
    vec3 position;
    vec3 local_position;
};

const uint VW = u_volume_size.x;
const uint VWH = u_volume_size.x * u_volume_size.y;
const float VOLUME_SCALE = 10.0;
const float HALF_VOLUME_SCALE = VOLUME_SCALE * 0.5;

float vmax(vec2 x) { return max(x.x, x.y); }
float vmax(vec3 x) { return max(x.x, max(x.y, x.z)); }
float vmax(vec4 x) { return max(max(x.x, x.y), max(x.z, x.w)); }
float vmin(vec2 x) { return min(x.x, x.y); }
float vmin(vec3 x) { return min(x.x, min(x.y, x.z)); }
float vmin(vec4 x) { return min(min(x.x, x.y), min(x.z, x.w)); }

uint uvw_to_i(vec3 uvw)
{
    uvw = clamp(uvw, 0.0, 1.0);
    uvec3 xyz = uvec3(uvw * u_volume_size);
    return xyz.x + xyz.y * VW + xyz.z * VWH;
}

float sdf_box_cheap(vec3 p, vec3 b)
{
    return vmax(abs(p) - b);
}

float world(vec3 p)
{
    return sdf_box_cheap(p, vec3(VOLUME_SCALE));
}

VolumeSample sample_volume(vec3 o, vec3 r)
{
    vec3 position;
    float distance = 2.0;
    float d;
    
    for (int i = 0; i < 32; i++)
    {
        position = o + r * distance;
        d = world(position);
        if (d < 0.002 || distance > FAR) { break; }
        distance += d;
    }

    vec3 inner_position;
    vec3 uvw;
    float density = 0.0;
    uint volume_data_i;
    const float VOLUME_STEP = 0.2;

    if (distance < FAR) for (int i = 0; i < 128; i++)
    {
        inner_position = o + r * distance;
        if (vmax(abs(inner_position)) > VOLUME_SCALE * 2.0) { continue; }

        uvw = (inner_position.xyz + HALF_VOLUME_SCALE) / VOLUME_SCALE;
        volume_data_i = uvw_to_i(uvw);
        density += buf0_col[volume_data_i].x * 0.036;

        if (density >= 1.0) { density = 1.0; break; }
        else { distance += VOLUME_STEP; }
    }

    uvw.z = 0.5;
    VolumeSample vs = VolumeSample
    (
        density,
        distance,
        position,
        uvw
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

vec3 normal_at(vec3 p)
{
    vec2 e = vec2(0.002, 0.0);
    return normalize(vec3(
        world(p + e.xyy) - world(p - e.xyy),
        world(p + e.yxy) - world(p - e.yxy),
        world(p + e.yyx) - world(p - e.yyx)
    ));
}

void main()
{
    vec2 uv = vs_uv;
    uv.x *= u_width / u_height;

    vec3 o = vec3(0.0, u_movement.z * 0.5 + 10, 20.0);
    o.z += u_movement.y * 0.5;
    o.xz = rotate_2d(o.xz, u_movement.x * 0.1 + 10);

    vec3 r = normalize(vec3(uv, 1.0));
    r = look_at(o, vec3(0.0)) * r;

    VolumeSample result = sample_volume(o, r);

    vec3 N = normal_at(result.position);

    vec3 RGB = result.density * vec3(1.0);
    RGB = saturate(RGB);
    if (result.distance < FAR)
    {
        vec3 L = vec3(-5.0, 5.0, 5.0);
        L = normalize(L - result.position);
        RGB += vec3(clamp(dot(N, L), 0.0, 1.0));
    }

    fs_color = vec4(RGB, 1.0);
}
