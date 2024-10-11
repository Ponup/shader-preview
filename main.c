#include <SDL2/SDL.h>
#include <GL/glew.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <time.h>

// Global variables
GLuint shaderProgram;
GLint timeLocation, mouseXLocation, mouseYLocation;
GLint resolutionXLocation, resolutionYLocation;
const char *vertexShaderSource = "#version 410 core\n"
                                 "layout(location = 0) in vec2 pos;\n"
                                 "void main() {\n"
                                 "    gl_Position = vec4(pos, 0.0, 1.0);\n"
                                 "}\n";
const char *defaultShaderFilePath = "shader.glsl";

// Function to check if a file has changed based on its modification time
time_t getFileModificationTime(const char *filePath)
{
    struct stat fileStat;
    if (stat(filePath, &fileStat) != 0)
    {
        printf("Failed to get file stats.\n");
        return -1;
    }
    return fileStat.st_mtime;
}

// Function to read shader file contents
char *readFile(const char *filePath)
{
    FILE *file = fopen(filePath, "r");
    if (!file)
    {
        printf("Failed to open shader file: %s\n", filePath);
        return NULL;
    }
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);
    char *content = (char *)malloc(length + 1);
    fread(content, 1, length, file);
    content[length] = '\0';
    fclose(file);
    return content;
}

// Function to compile a shader
GLuint compileShader(const char *source, GLenum shaderType)
{
    GLuint shader = glCreateShader(shaderType);
    glShaderSource(shader, 1, &source, NULL);
    glCompileShader(shader);

    // Check for compilation errors
    GLint compiled;
    glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
    if (!compiled)
    {
        GLint logLength;
        glGetShaderiv(shader, GL_INFO_LOG_LENGTH, &logLength);
        char *log = (char *)malloc(logLength);
        glGetShaderInfoLog(shader, logLength, NULL, log);
        printf("Shader compilation failed: %s\n", log);
        free(log);
        glDeleteShader(shader);
        return 0;
    }
    return shader;
}

// Function to link shaders into a program
GLuint linkProgram(GLuint vertexShader, GLuint fragmentShader)
{
    GLuint program = glCreateProgram();
    glAttachShader(program, vertexShader);
    glAttachShader(program, fragmentShader);
    glLinkProgram(program);

    // Check for linking errors
    GLint linked;
    glGetProgramiv(program, GL_LINK_STATUS, &linked);
    if (!linked)
    {
        GLint logLength;
        glGetProgramiv(program, GL_INFO_LOG_LENGTH, &logLength);
        char *log = (char *)malloc(logLength);
        glGetProgramInfoLog(program, logLength, NULL, log);
        printf("Program linking failed: %s\n", log);
        free(log);
        glDeleteProgram(program);
        return 0;
    }
    return program;
}

// Function to reload the shader
void reloadShader(const char *shaderPath)
{
    char *fragmentShaderSource = readFile(shaderPath);
    if (!fragmentShaderSource)
        return;

    // Compile new shaders and link program
    GLuint vertexShader = compileShader(vertexShaderSource, GL_VERTEX_SHADER);
    GLuint fragmentShader = compileShader(fragmentShaderSource, GL_FRAGMENT_SHADER);
    GLuint newProgram = linkProgram(vertexShader, fragmentShader);

    // Cleanup old shaders and program
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);
    glDeleteProgram(shaderProgram);

    // Use the new shader program
    shaderProgram = newProgram;
    timeLocation = glGetUniformLocation(shaderProgram, "time");
    mouseXLocation = glGetUniformLocation(shaderProgram, "mouseX");
    mouseYLocation = glGetUniformLocation(shaderProgram, "mouseY");
    resolutionXLocation = glGetUniformLocation(shaderProgram, "resolutionX");
    resolutionYLocation = glGetUniformLocation(shaderProgram, "resolutionY");
    free(fragmentShaderSource);

    printf("Shader reloaded successfully.\n");
}

int main(int argc, char **argv)
{
    const char *shaderPath = argc == 2 ? argv[1] : defaultShaderFilePath;

    if (SDL_Init(SDL_INIT_VIDEO) != 0)
    {
        printf("Failed to initialize SDL: %s\n", SDL_GetError());
        return -1;
    }

    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 1);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_CORE);

    SDL_Window *window = SDL_CreateWindow("Shader preview", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, 800, 600, SDL_WINDOW_OPENGL | SDL_WINDOW_RESIZABLE);
    if (!window)
    {
        printf("Failed to create window: %s\n", SDL_GetError());
        SDL_Quit();
        return -1;
    }

    SDL_GLContext context = SDL_GL_CreateContext(window);
    if (!context)
    {
        printf("Failed to create OpenGL context: %s\n", SDL_GetError());
        SDL_DestroyWindow(window);
        SDL_Quit();
        return -1;
    }

    glewExperimental = GL_TRUE;
    GLenum glewStatus = glewInit();
    if (glewStatus != GLEW_OK)
    {
        printf("Failed to initialize GLEW: %s\n", glewGetErrorString(glewStatus));
        SDL_GL_DeleteContext(context);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return -1;
    }

    // Initial shader loading
    reloadShader(shaderPath);
    time_t lastModificationTime = getFileModificationTime(shaderPath);

    // Fullscreen quad setup
    float vertices[] = {
        -1.0f,
        -1.0f,
        1.0f,
        -1.0f,
        -1.0f,
        1.0f,
        1.0f,
        1.0f,
    };
    GLuint vao, vbo;
    glGenVertexArrays(1, &vao);
    glGenBuffers(1, &vbo);
    glBindVertexArray(vao);
    glBindBuffer(GL_ARRAY_BUFFER, vbo);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void *)0);
    glEnableVertexAttribArray(0);

    // Main loop
    SDL_Event event;
    int running = 1;
    float time = 0.0f;
    int mouseX, mouseY;
    Uint32 timeReset = 0;
    SDL_bool updateMouse = SDL_FALSE;

    while (running)
    {
        // Handle events
        while (SDL_PollEvent(&event))
        {
            if (event.type == SDL_QUIT)
            {
                running = 0;
            }
            if (event.type == SDL_KEYDOWN)
            {
                if (event.key.keysym.sym == SDLK_UP)
                    timeReset = SDL_GetTicks();
            }

            if (event.type == SDL_MOUSEBUTTONDOWN)
                updateMouse = SDL_TRUE;
            if (event.type == SDL_MOUSEBUTTONUP)
                updateMouse = SDL_FALSE;
        }

        // Check for shader file changes
        time_t currentModificationTime = getFileModificationTime(shaderPath);
        if (currentModificationTime > lastModificationTime)
        {
            reloadShader(shaderPath);
            lastModificationTime = currentModificationTime;
        }

        time = (SDL_GetTicks() - timeReset) / 1000.0f; // Time in seconds
        if (updateMouse == SDL_TRUE)
        {
            SDL_GetMouseState(&mouseX, &mouseY);
            glUniform1i(mouseXLocation, mouseX);
            glUniform1i(mouseYLocation, mouseY);
        }

        glUseProgram(shaderProgram);
        glUniform1f(timeLocation, time);
        glUniform1i(resolutionXLocation, 800);
        glUniform1i(resolutionYLocation, 600);

        // Render with the shader
        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(shaderProgram);
        glBindVertexArray(vao);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

        SDL_GL_SwapWindow(window);
    }

    // Cleanup
    glDeleteVertexArrays(1, &vao);
    glDeleteBuffers(1, &vbo);
    glDeleteProgram(shaderProgram);

    SDL_GL_DeleteContext(context);
    SDL_DestroyWindow(window);
    SDL_Quit();
    return 0;
}
