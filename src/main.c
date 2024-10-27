#include "raylib.h"

/**
 * This is a function that does absolutely nothing.
 *
 * That's right: nothing at all.
 */
void nothing(void) {
}

int main(void) {
    InitWindow(800, 600, "Hello world!");

    while (!WindowShouldClose()) {
        BeginDrawing();

        ClearBackground(RAYWHITE);
        DrawText("Hello world!", 400, 300, 20, LIGHTGRAY);

        EndDrawing();
    }

    CloseWindow();

    return 0;
}
