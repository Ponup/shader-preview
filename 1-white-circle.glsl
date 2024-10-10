#version 410 core

// gl_FragCoord
out vec4 FragColor;

uniform float time;

float map(in vec3 pos) {
    float d  = length(pos) - 0.25;
    return d;
}

void main() {
    vec2 p = (2 * gl_FragCoord.xy - vec2(800,600)) / 600; // perspective
    vec3 ro = vec3(0, 0, 2); // camera origin
    vec3 rd = normalize(vec3(p, -1.2)); // camera direction
    vec3 col = vec3(0); // default color

    float t = 0;
    for(int i = 0; i < 100; i++) {
        vec3 pos = ro + t * rd;
        float h = map(pos);

        if(h < 0.001) break;

        t += h;

        if(t > 20) break;
    }
    if(t < 20) {
        col = vec3(1);
    }

    FragColor = vec4(col, 1);
}

