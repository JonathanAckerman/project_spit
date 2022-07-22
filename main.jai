WINDOW_WIDTH :: 1536;
WINDOW_HEIGHT :: 864;

main :: () {
    window_title := to_c_string("project_spit");
    InitWindow(xx WINDOW_WIDTH, xx WINDOW_HEIGHT, window_title);
    SetTargetFPS(60);
    Debug.font = LoadFont("./assets/fonts/cour.ttf");

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
#load "Input.jai";
#load "Resource.jai";
#load "Trader.jai";
#load "debug_tools.jai";
#load "Maybe.jai";

#import "Raylib-Jai";
#import "Basic";
#import "Math";
#import "Random";
#import "Sort";