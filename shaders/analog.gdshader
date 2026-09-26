shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform bool camcorder = false;
uniform float grain_amount : hint_range(0.0, 0.2) = 0.035;
uniform float brightness : hint_range(0.7, 1.8) = 1.12;
uniform float pixel_size = 1.7;
uniform bool scanlines = true;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898,78.233))) * 43758.5453); }
void fragment() {
    vec2 resolution = 1.0 / SCREEN_PIXEL_SIZE;
    vec2 uv = floor(SCREEN_UV * resolution / pixel_size) * pixel_size / resolution;
    vec3 c = texture(screen_texture, uv).rgb;
    float n = hash(floor(uv * resolution) + fract(TIME) * 77.0) - 0.5;
    c = mix(vec3(dot(c, vec3(0.299,0.587,0.114))), c, 0.74);
    c *= vec3(1.04, 1.0, 0.88) * brightness;
    if (camcorder) {
        float luma = dot(c, vec3(0.299,0.587,0.114));
        c = vec3(0.58,0.89,0.68) * pow(luma, 0.64) * 1.7;
        c += (hash(vec2(floor(uv.y*240.0), floor(TIME*12.0)))-0.5)*0.027;
    }
    c += n * grain_amount * (camcorder ? 1.8 : 1.0);
    if (scanlines) c *= 1.0 - 0.07 * step(0.5, fract(SCREEN_UV.y * resolution.y / 3.0));
    vec2 v = SCREEN_UV * (1.0 - SCREEN_UV.yx);
    c *= clamp(pow(v.x*v.y*18.0, 0.22), 0.30, 1.0);
    COLOR = vec4(c,1.0);
}
