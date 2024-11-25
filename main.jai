real_time, game_time, real_delta_time, delta_time: float;
game_paused := false;

main :: () {
    SDL_Init(SDL_INIT_EVERYTHING);
    window := SDL_CreateWindow("Skeleton", SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, xx WINDOW_WIDTH, xx WINDOW_HEIGHT, SDL_WINDOW_OPENGL);
    
#if OS == .WINDOWS {
        wm_info: SDL_SysWMinfo;
        SDL_GetWindowWMInfo(window, *wm_info);
        hwnd := wm_info.info.win.window;
    }
    
    SDL_GL_SetAttribute(SDL_GL_RED_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_GREEN_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_BLUE_SIZE, 8);
    SDL_GL_SetAttribute(SDL_GL_DOUBLEBUFFER, 1);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 4);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 6);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_FLAGS, xx SDL_GL_CONTEXT_DEBUG_FLAG);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, xx SDL_GL_CONTEXT_PROFILE_CORE);
    gl_context := SDL_GL_CreateContext(window);
    
    key_states = SDL_GetKeyboardState(null);
    
    init_memory_system();
    init_texture_system();
    init_renderer();
    // init_font_system();
    init_shader_system();
    init_mesh_system();
    init_animation_system();
    
    frame_keys.allocator = temp;
    
    mesh_test := load_mesh("mesh/man/man.mesh");
    anim_test := load_animation("mesh/man/man.anim");
    anim_player := create_anim_player(mesh_test, anim_test);
    anim_play(*anim_player);
    
    mesh_map_test := load_mesh("mesh/maps/test.mesh");
    
    mesh_cube := load_mesh("mesh/cube/cube.mesh");
    
    old_time = current_time_monotonic();
    
    quit := false;
    while !quit {
        quit = process_window_events();
        if quit break;
        
        // update time
        {
            now := current_time_monotonic();
            delta := now - old_time;
            
            real_time_f64 = to_float64_seconds(now);
            real_delta_time_f64 = to_float64_seconds(delta);
            
            if game_paused {
                delta_time_f64 = 0.0;
            } else {
                delta_time_f64 = real_delta_time_f64;
                game_time_f64 += delta_time_f64;
            }
            
            real_time = xx real_time_f64;
            game_time = xx game_time_f64;
            real_delta_time = xx real_delta_time_f64;
            delta_time = xx delta_time_f64;
            
            old_time = now;
        }
        
        // update mouse
        {
            x, y: s32;
            SDL_GetMouseState(*x, *y);
            
            pos := Vec2.{xx x, xx y};
            
            mouse.delta.x = mouse.position.x - pos.x;
            mouse.delta.y = mouse.position.y - pos.y;
            
            mouse.position.x = pos.x;
            mouse.position.y = pos.y;
        }
        
        update_camera(*camera);
        anim_update(*anim_player);
        
        draw_mesh(mesh_map_test, mat4_identity());
        draw_skinned_mesh(mesh_test, *anim_player, mat4_translation(.{0, 0, 0}));
        
        rotation := quat_axis_angle(.{0, 1, 0}, sin(game_time) * 360 * deg2rad);
        for x: 0..5 {
            for y: 0..5 {
                draw_mesh(mesh_cube, mat4_translation(/*.{3.0 + (x*4.0), 3.0 + (y*4.0),*/ .{0, 0, xx(x+(y*5))}) /** mat4_rotation(rotation)*/);
            }
        }
        
        if key_pressed(SDL_SCANCODE_LEFT) anim_update(*anim_player);
        
        renderer_draw_frame();
        
        SDL_GL_SwapWindow(window);
        
        frame_keys.count = 0;
        
        arena_reset(*frame_arena);
    }
}

process_window_events :: () -> bool {
    event: SDL_Event;
    while SDL_PollEvent(*event) {
        if event.type == SDL_QUIT return true;
        
        if event.type == SDL_KEYDOWN {
            if event.key.state {
                if event.key.keysym.scancode == SDL_SCANCODE_ESCAPE return true;
                
                array_add(*frame_keys, event.key.keysym.scancode);
            }
        }
    }
    
    return false;
}

Mouse :: struct {
    delta: Vec2;
    position: Vec2;
}

frame_keys: [..] SDL_Scancode;
mouse: Mouse;

key_pressed :: (code: SDL_Scancode) -> bool {
    for frame_keys if it == code return true;
    return false;
}

key_state :: (code: SDL_Scancode) -> float {
    return ifx key_states[code] then 1.0 else 0.0;
}

#scope_file

#import "Basic";
#import "SDL";
#import "GL";

key_states: *u8;

WINDOW_WIDTH := 1366;
WINDOW_HEIGHT := 768;

old_time: Apollo_Time;
real_time_f64, game_time_f64, real_delta_time_f64, delta_time_f64: float64;