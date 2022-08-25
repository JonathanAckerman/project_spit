WINDOW_WIDTH :: 1536;
WINDOW_HEIGHT :: 864;
WINDOW_CENTER :: Vector2.{WINDOW_WIDTH/2, WINDOW_HEIGHT/2};
RAYLIB :: true;

main :: () {
    window_title := to_c_string("project_spit");
    InitWindow(xx WINDOW_WIDTH, xx WINDOW_HEIGHT, window_title);
    SetTargetFPS(60);
    Debug.font = LoadFont("./assets/fonts/cour.ttf");
    SetTraceLogLevel(xx TraceLogLevel.LOG_NONE);

    Game.resetting = true;
    while Game.resetting {
        game_reset();
        while !WindowShouldClose() {
            game_loop();
            if IsKeyPressed(xx KeyboardKey.F5) { Game.resetting = true; break; }
        }
    }
    CloseWindow();
}

#load "Game.jai";
#load "Entity.jai";
#load "Input.jai";
#load "Collider.jai";
#load "Physics.jai";
#load "Graphics.jai";
#load "Resource.jai";
#load "Building.jai";
#load "Trader.jai";
#load "DebugTools.jai";
#load "Maybe.jai";
#load "Concepts.jai";
#load "Grid.jai";
#load "Utils.jai";
#load "TextureLoader.jai";

#import "Basic";
#import "Math";
#import "Random";
#import "Sort";
#import "String";
#import "Raylib-Jai";
#import "Hash_Table";