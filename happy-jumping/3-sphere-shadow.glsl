#version 410 core

// gl_FragCoord
out vec4 FragColor;

uniform float time;

float map(in vec3 pos) {
    float d1  = length(pos) - 0.25;

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
    vec3 ro = vec3(0, 0, 1); // camera origin
    vec3 rd = normalize(vec3(p, -1.2)); // camera direction
    vec3 col = vec3(0); // default color

    float t = castRay(ro, rd);

    if(t > 0) {
        vec3 pos = ro + t*rd;
        vec3 nor = calcNormal(pos);

        vec3 sun_dir = normalize(vec3(0.8, 0.4, 0.2));
        float sun_dif = clamp(dot(nor, sun_dir), 0, 1); // diffuse
        float sun_sha = step(castRay(pos+nor*0.001, sun_dir),0.0);        
        float sky_dif = clamp(dot(nor, vec3(0,1,0)), 0, 1);

        col = vec3(1, 0.7, 0.5) * sun_dif * sun_sha;
        col += vec3(0, 0.1, 0.3) * sky_dif;
    }

    FragColor = vec4(col, 1);
}

