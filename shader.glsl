#version 410 core

// Inputs
uniform int resolutionX, resolutionY;

// Ouput
out vec4 FragColor;

void main() {
    FragColor = vec4(gl_FragCoord.x/resolutionX, gl_FragCoord.y/resolutionY, gl_FragCoord.z, 1);
}

