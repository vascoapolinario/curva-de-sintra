shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform float clock=0.0;
void fragment() {
    float height=1.0-UV.y;
    float sway=sin(height*9.0-clock*5.1)*0.065*height;
    float edge=abs(UV.x-0.5+sway);
    float width=(1.0-height)*0.30+(sin(height*17.0-clock*7.0)*0.04);
    float flame=1.0-smoothstep(width-0.035,width+0.035,edge);
    flame*=smoothstep(0.0,0.12,height)*(1.0-smoothstep(0.80,1.0,height));
    ALBEDO=mix(vec3(1.0,0.13,0.015),vec3(1.0,0.72,0.17),clamp((1.0-height)-edge*2.0,0.0,1.0));
    ALPHA=flame*0.88;
}
