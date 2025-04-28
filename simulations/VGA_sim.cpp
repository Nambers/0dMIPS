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
constexpr int SCALE_FACTOR = 5;
constexpr int BUF_WIDTH = 640 / SCALE_FACTOR;
constexpr int BUF_HEIGHT = 480 / SCALE_FACTOR;
constexpr size_t VGA_COLOR_ADDR = 0x20000008;

uint32_t fps_lasttime = SDL_GetTicks();
uint32_t fps_current;
uint32_t fps_frames = 0;

inline uint8_t color4to8(uint8_t c) { return c << 4 | c; }

class Pixel {
   public:
    uint8_t a;
    uint8_t r;
    uint8_t g;
    uint8_t b;
    Pixel() = default;
    Pixel(uint8_t r, uint8_t g, uint8_t b) : a(255), r(r), g(g), b(b) {}
    static const SDL_PixelFormat FORMAT = SDL_PIXELFORMAT_ARGB8888;
};

struct AppState {
    SDL_Window *window;
    SDL_Renderer *renderer;
    VGA_sim *top;
    uint32_t test_pixel = 0;
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

    // Create window and renderer
    if (!SDL_CreateWindowAndRenderer(nullptr, SCREEN_WIDTH, SCREEN_HEIGHT, 0,
                                     &as->window, &as->renderer)) {
        std::cerr << "Window could not be created! SDL_Error: "
                  << SDL_GetError() << std::endl;
        return SDL_APP_FAILURE;
    }

    SDL_SetWindowTitle(as->window, "VGA Simulator");

    // Initialize the VGA module
    as->top = new VGA_sim;
    as->top->rst = 1;
    as->top->clk = 1;
    as->top->VGA_clk = 1;
    as->top->wr_enable = 0;
    as->top->addr = 0;
    as->top->w_data = 0;
    TICK;
    TICK;
    as->top->rst = 0;

    std::cout << "Simulation starting. Press 'q' to quit, 'r' to reset."
              << std::endl;
    as->top->addr = VGA_COLOR_ADDR;
    return SDL_APP_CONTINUE;
}

SDL_AppResult SDL_AppIterate(void *appstate) {
    AppState *as = (AppState *)appstate;
    static uint32_t frame_counter = 0;
    static bool buffered = false;

    if (as->top->VGA_taken) {
        as->test_pixel = (as->test_pixel + 1) % ((BUF_WIDTH * BUF_HEIGHT));
        if (as->test_pixel == 0) {
            buffered = true;
            as->top->wr_enable = false;
        }
    }
    if (!buffered) {
        uint32_t x = (as->test_pixel % BUF_WIDTH) & 0x3ff;
        uint32_t y = ((as->test_pixel / BUF_WIDTH) % BUF_HEIGHT) & 0x3ff;
        uint32_t red = ((x + frame_counter) % 16);
        uint32_t green = ((y + frame_counter) % 16);
        uint32_t blue = ((x + y) % 16);
        uint32_t color = (red << 8) | (green << 4) | blue;

        as->top->wr_enable = 1;
        as->top->w_data = (y << 22) | (x << 12) | color;
    }

    if (as->top->VGA->h < SCREEN_WIDTH && as->top->VGA->v < SCREEN_HEIGHT) {
        SDL_SetRenderDrawColor(as->renderer, color4to8(as->top->VGA_r),
                               color4to8(as->top->VGA_g),
                               color4to8(as->top->VGA_b), SDL_ALPHA_OPAQUE);
        SDL_RenderPoint(as->renderer, as->top->VGA->h, as->top->VGA->v);
    }

    if (as->top->VGA->h == 0 && as->top->VGA->v == 0) {
        buffered = false;
        SDL_RenderPresent(as->renderer);
        fps_frames++;
        frame_counter++;
        if (fps_lasttime < SDL_GetTicks() - 1000) {
            fps_lasttime = SDL_GetTicks();
            fps_current = fps_frames;
            std::cout << "current FPS: " << fps_current << std::endl;
            fps_frames = 0;
        }
    }
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
                    as->test_pixel = 0;
                    std::cout << "Reset done" << std::endl;
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
