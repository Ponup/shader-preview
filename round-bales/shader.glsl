#version 410 core

#define DEBUG 1

// Inputs
uniform int resolutionX, resolutionY;

// Ouput
out vec4 FragColor;

void main() {
	vec3 skyColor = vec3(0, 0, 1);
	vec3 fieldColor = vec3(245,222,179)/255;
	vec3 debugColor = vec3(1, 0, 0);

	// see https://www.shadertoy.com/view/Mt2XDK
	vec2 pos = vec2(gl_FragCoord.x/resolutionX, gl_FragCoord.y/resolutionY);
	vec3 col = vec3(1);
	if(pos.y > 0.7)
		col = mix(col, skyColor, pos.y*pos.y);
	else
		col = mix(vec3(0), fieldColor, pos.y*pos.y);

#ifdef DEBUG
	if(pos.x == .5 && pos.y == .5) col = debugColor;
#endif

    FragColor = vec4(col, 1);
}

