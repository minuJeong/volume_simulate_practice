#version 460

layout(local_size_x=4, local_size_y=4, local_size_z=4) in;

layout(binding=0) buffer bind_1
{
    float volume_noise[];
};

layout(binding=1) buffer in_0
{
    vec4 volume_data[];
};

uniform uvec3 u_volume_size;

uint VW = u_volume_size.x;
uint VWH = u_volume_size.x * u_volume_size.y;

uint xyz_to_i(uvec3 xyz)
{
    return xyz.x + xyz.y * VW + xyz.z * VWH;
}

uint uvw_to_i(vec3 uvw)
{
    uvw = clamp(uvw, 0.0, 1.0);
    uvec3 xyz = uvec3(uvw * u_volume_size);
    return xyz_to_i(xyz);
}

void main()
{
    uvec3 xyz = gl_LocalInvocationID.xyz + gl_WorkGroupID.xyz * gl_WorkGroupSize.xyz;
    uint i = xyz_to_i(xyz);

    vec3 uvw = vec3(xyz) / vec3(u_volume_size);
    // uvw.x = volume_noise[i].x;

    float alpha = volume_noise[i].x + 0.4;
    volume_data[i] = vec4(uvw, alpha);
}
