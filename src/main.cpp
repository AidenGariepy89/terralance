#include <cstdio>

#include "raylib.h"

int main(void) {
    InitWindow(800, 600, "Hello world!");

    while (!WindowShouldClose()) {
        BeginDrawing();

        ClearBackground(RAYWHITE);
        DrawText("Hello world!", 400, 300, 20, LIGHTGRAY);

        // Quit when ESC or CAPS_LOCK is pressed.
        // ESC quit is built-in to raylib.
        if (IsKeyPressed(KEY_CAPS_LOCK)) {
            break;
        }

        EndDrawing();
    }

    CloseWindow();

    return 0;
}
