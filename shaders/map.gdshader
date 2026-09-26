shader_type spatial;
render_mode unshaded, cull_disabled;
uniform sampler2D paper : source_color, filter_linear_mipmap;
uniform vec2 car_uv = vec2(0.5);
uniform float heading = 0.0;
void fragment() {
    vec3 base = texture(paper,UV).rgb * 0.79;
    vec2 d=UV-car_uv;
    float r=length(d);
    base=mix(base,vec3(0.08,0.035,0.015),1.0-smoothstep(0.012,0.014,r));
    base=mix(base,vec3(0.95,0.56,0.12),1.0-smoothstep(0.006,0.008,r));
    vec2 f=vec2(-sin(heading),-cos(heading));
    float along=dot(d,f);
    float across=abs(dot(d,vec2(-f.y,f.x)));
    float arrow=step(0.012,along)*step(along,0.028)*step(across,(0.03-along)*0.52);
    base=mix(base,vec3(0.73,0.31,0.055),arrow);
    ALBEDO=base;
}
