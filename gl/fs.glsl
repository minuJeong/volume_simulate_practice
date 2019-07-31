#version 460

in vec2 vs_uv;
out vec4 fs_color;

layout(binding=0) uniform sampler2D tex;

layout(binding=1) buffer in_0
{
    vec4 buf0_col[];
};

uniform float u_time;
uniform uvec3 u_volume_size;

uint VW = u_volume_size.x;
uint VWH = u_volume_size.x * u_volume_size.y;

uint uvw_to_i(vec3 uvw)
{
    uvw = clamp(uvw, 0.0, 1.0);
    uvec3 xyz = uvec3(uvw * u_volume_size);
    return xyz.x + xyz.y * VW + xyz.z * VWH;
}

vec3 sample_volume(vec3 o, vec3 r)
{
    vec3 p;
    float t = 0.0;
    float d = 0.1;
    float density = 0.0;

    float c = cos(u_time);
    float s = sin(u_time);
    
    for (int i = 0; i < 256; i++)
    {
        p = o + r * t;
        t += d;

        p.xz = mat2(c, -s, s, c) * p.xz;
        vec3 uvw = p.xyz / 3.0;

        if (uvw.x < -1.0 || uvw.x > +1.0 ||
            uvw.y < -1.0 || uvw.y > +1.0 ||
            uvw.z < -1.0 || uvw.z > +1.0)
        {
            continue;
        }

        uint bi = uvw_to_i(uvw);
        density += buf0_col[bi].x * 0.5;

        if (density >= 1.0)
        {
            break;
        }
    }

    return p;

    density = clamp(density, 0.0, 1.0);
    // return density;
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
    vec2 uv = vs_uv * 0.5 + 0.5;

    vec3 o = vec3(0.0, 5.0, 20.0);
    vec3 r = normalize(vec3(vs_uv, 1.0));

    r = look_at(o, vec3(0.0)) * r;

    // float density = sample_volume(o, r);
    vec3 xyz = sample_volume(o, r);

    // vec3 RGB = density * vec3(0.8, 0.2, 0.2);
    vec3 RGB = clamp(abs(xyz), 0.0, 1.0);
    fs_color = vec4(RGB, 1.0);
}
