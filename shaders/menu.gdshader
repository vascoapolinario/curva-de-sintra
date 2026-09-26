shader_type canvas_item;
uniform bool settings_page=false;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){
    vec2 uv=UV;
    float darkness=mix(0.55,0.08,smoothstep(0.0,0.70,uv.x));
    darkness+=smoothstep(0.52,1.0,abs(uv.y-0.5)*2.0)*0.08;
    float grain=(hash(floor(uv*vec2(1280.0,720.0))+floor(TIME*8.0))-0.5)*0.027;
    float mist=sin(uv.x*9.0+uv.y*13.0+TIME*0.045)*sin(uv.y*19.0-TIME*0.025)*0.008;
    vec3 tone=vec3(0.019,0.029,0.025)+grain+mist;
    if(settings_page){ darkness=0.97; tone*=0.65; }
    COLOR=vec4(tone,clamp(darkness,0.0,1.0));
}
