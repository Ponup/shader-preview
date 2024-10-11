#version 410 core

out vec4 FragColor;

uniform float time;

float sdSphere(in vec3 pos, float rad) {
    return length(pos) - rad;
}

float sdElipsoid(in vec3 pos, vec3 rad) {
    float k0 = length(pos/rad);
    float k1 = length(pos/rad/rad);
    return k0*(k0-1)/k1;
}

// smooth min
float smin(in float a, in float b, float k) {
    float h =  max(k - abs(a-b), 0.0);
    return min(a,b) - h * h / (k*4);
}

float sdGuy(in vec3 pos) {
    float t = 0.5;fract(time);
    float y = 4*t*(1-t);
    float dy = 4*(1-2*t);

    vec2 u = normalize(vec2(1, -dy)); // u v are perpdendiclar
    vec2 v = vec2(dy, 1);

    vec3 cen = vec3(0, y, 0);
    float sy = 0.5 + 0.5*y;
    float sz = 1.0/sy;
    vec3 rad = vec3(0.25, 0.25*sy, 0.25*sz);

    vec3 q = pos-cen;

    //q.yz = vec2(dot(u,q.yz), dot(v,q.yz));

    float d = sdElipsoid(q, rad);
    vec3 h = q ; //head position

    //head
    float d2 = sdElipsoid(h- vec3(0,0.28,0), vec3(0.2));
    float d3 = sdElipsoid(h- vec3(0,0.28,.1), vec3(0.2));

    d2 = smin(d2, d3, 0.03);
    d = smin(d,d2, 0.03);

    //eyes
    vec3 sh = vec3(abs(h.x), h.yz);
    float d4 = sdSphere(sh - vec3(0.08,0.28,0.25), 0.05);
    

    d = min(d, d4);

    return d;
}

float map(in vec3 pos) {
    float d1  = sdGuy(pos);

    float d2 = pos.y - (-0.25);

    return min(d1, d2); // closest gets rendered
}

vec3 calcNormal(in vec3 pos) {
    vec2 e = vec2(0.0001, 0);
    return normalize(vec3(map(pos + e.xyy) - map(pos-e.xyy),
                        map(pos + e.yxy) - map(pos-e.yxy),
                        map(pos + e.yyx) - map(pos-e.yyx)));
}

float castRay( in vec3 ro, vec3 rd) {
    float t = 0;
    for(int i = 0; i < 100; i++) {
        vec3 pos = ro + t * rd;
        float h = map(pos);

        if(h < 0.001) break;

        t += h;

        if(t > 20) break;
    }
    if(t>20.0) t=-1.0;
    return t;
}

void main() {
    vec2 p = (2 * gl_FragCoord.xy - vec2(800,600)) / 600; // perspective

    float an = time; //angle

    vec3 ta = vec3(0, .95, 0); //camera target
    vec3 ro = ta + vec3(1.5*sin(an), 0, 1.5*cos(an)); // camera origin

    vec3 ww = normalize(ta - ro);
    vec3 uu = normalize(cross(ww, vec3(0,1,0)));
    vec3 vv = normalize(cross(uu, ww));

    vec3 rd = normalize(p.x*uu+ p.y*vv+1.8 *ww); // camera direction

    vec3 col = vec3(0.4, 0.75, 1) - 0.7*rd.y; // default color, sky
    col = mix(col, vec3(0.7, 0.75, 0.8), exp(-10*rd.y)); // gray horizon
    float t = castRay(ro, rd);

    if(t > 0) {
        vec3 pos = ro + t*rd;
        vec3 nor = calcNormal(pos);

        vec3 mate = vec3(0.18); //albedo?
        vec3 sun_dir = normalize(vec3(0.8, 0.4, 0.2));
        float sun_dif = clamp(dot(nor, sun_dir), 0, 1); // diffuse
        float sun_sha = step(castRay(pos+nor*0.001, sun_dir),0.0);        
        float sky_dif = clamp(0.5 + 0.5 * dot(nor, vec3(0,1,0)), 0, 1);
        float bou_dif = clamp(0.5 + 0.5 * dot(nor, vec3(0,-1,0)), 0, 1); // bounce light

        col = mate*vec3(7, 4.5, 3) * sun_dif * sun_sha;
        col += mate*vec3(0.5, 0.8, 0.9) * sky_dif;
        col += mate*vec3(0.7, 0.3, 0.2) * bou_dif;
    }

    col = pow(col, vec3(0.4545)); // gamma correction

    FragColor = vec4(col, 1);
}

