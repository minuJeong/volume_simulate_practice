#version 460

layout(local_size_x=4, local_size_y=4, local_size_z=4) in;

layout(binding=1) buffer in_0
{
    vec4 buf0_col[];
};

uniform uvec3 u_volume_size;

void main()
{
    uvec3 xyz = gl_LocalInvocationID.xyz + gl_WorkGroupID.xyz * gl_WorkGroupSize.xyz;
    uint i = xyz.x;

    vec3 uvw = xyz / u_volume_size;

    uvw.x = 0.4;

    buf0_col[i] = vec4(uvw, 1.0);
}
