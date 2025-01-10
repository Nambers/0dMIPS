/*
    To test if VGA unit is implemented correctly
    the clk and VGA_clk are in same speed in this simulation
    the screen supposed to be filled with pure color and increasing every frame
*/
#define SDL_MAIN_USE_CALLBACKS
#include <SDL3/SDL.h>
#include <SDL3/SDL_main.h>
#include <VGA_sim.h>
#include <VGA_sim__Syms.h>
#include <verilated.h>

#include <iostream>

constexpr int SCREEN_WIDTH = 640;
constexpr int SCREEN_HEIGHT = 480;

inline uint8_t color4to8(uint8_t c) { return c << 4 | c; }

class Pixel {
   public:
    uint8_t a;
    uint8_t r;
    uint8_t g;
    uint8_t b;
    Pixel() = default;
    Pixel(uint8_t r, uint8_t g, uint8_t b) : r(r), g(g), b(b) {}
    static const SDL_PixelFormat FORMAT = SDL_PIXELFORMAT_ARGB8888;
};

struct AppState {
    Pixel pixels[SCREEN_HEIGHT][SCREEN_WIDTH];
    SDL_Window *window;
    SDL_Renderer *renderer;
    VGA_sim *top;
    uint16_t test_pixel;
};

#define TICK                              \
    as->top->clk = !as->top->clk;         \
    as->top->VGA_clk = !as->top->VGA_clk; \
    as->top->eval()

SDL_AppResult SDL_AppInit(void **appstate, int argc, char *argv[]) {
    if (!SDL_SetAppMetadata("VGA_sim", nullptr, nullptr)) {
        return SDL_APP_FAILURE;
    }

    Verilated::commandArgs(argc, argv);

    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        std::cerr << "SDL could not initialize! SDL_Error: " << SDL_GetError()
                  << std::endl;
        return SDL_APP_FAILURE;
    }

    AppState *as = (AppState *)SDL_calloc(1, sizeof(AppState));
    if (!as) {
        return SDL_APP_FAILURE;
    }

    *appstate = as;

    if (!SDL_CreateWindowAndRenderer(nullptr, SCREEN_WIDTH, SCREEN_HEIGHT, 0,
                                     &as->window, &as->renderer)) {
        std::cerr << "Window could not be created! SDL_Error: "
                  << SDL_GetError() << std::endl;
        return SDL_APP_FAILURE;
    }

    as->top = new VGA_sim;
    as->top->rst = 1;
    as->top->clk = 1;
    as->top->VGA_clk = 1;
    TICK;
    TICK;
    as->top->rst = 0;

    std::cout << "simulation starting, press 'q' to quit" << std::endl;

    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppIterate(void *appstate) {
    AppState *as = (AppState *)appstate;
    if (as->top->wr_ready) as->top->w_data = as->test_pixel;
    if (as->top->VGA->h == 0 && as->top->VGA->v == 0) {
        SDL_RenderPresent(as->renderer);
        SDL_SetRenderDrawColor(as->renderer, 0, 0, 0, SDL_ALPHA_OPAQUE);
        SDL_RenderClear(as->renderer);
        as->test_pixel++;
    }
    SDL_SetRenderDrawColor(as->renderer, color4to8(as->top->VGA_r),
                           color4to8(as->top->VGA_g), color4to8(as->top->VGA_b),
                           SDL_ALPHA_OPAQUE);
    SDL_RenderPoint(as->renderer, as->top->VGA->h, as->top->VGA->v);
    TICK;
    TICK;
    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppEvent(void *appstate, SDL_Event *event) {
    AppState *as = (AppState *)appstate;
    switch (event->type) {
        case SDL_EVENT_QUIT:
            return SDL_APP_SUCCESS;
        case SDL_EVENT_KEY_DOWN:
            switch (event->key.scancode) {
                case SDL_SCANCODE_Q:
                    return SDL_APP_SUCCESS;
                case SDL_SCANCODE_R: {
                    as->top->rst = 1;
                    TICK;
                    TICK;
                    as->top->rst = 0;
                    std::cout << "reset done" << std::endl;
                    break;
                }
            }
    }
    return SDL_APP_CONTINUE;
}

void SDL_AppQuit(void *appstate, SDL_AppResult result) {
    if (appstate != NULL) {
        AppState *as = (AppState *)appstate;
        delete as->top;
        SDL_DestroyRenderer(as->renderer);
        SDL_DestroyWindow(as->window);
        SDL_free(as);
    }
}
