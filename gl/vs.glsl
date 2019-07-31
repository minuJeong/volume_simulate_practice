#version 460

in vec2 in_pos;
out vec2 vs_uv;

void main()
{
    vs_uv = in_pos;
    gl_Position = vec4(in_pos, 0.0, 1.0);
}
