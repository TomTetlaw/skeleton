
Camera :: struct {
	FLY_SPEED :: 1.0;
    ROTATION_SPEED :: 0.3;
    ROTATION_SMOOTHING :: 0.3;
    
    position: Vec3;
    
    yaw, pitch: float;
    rotation: Mat4;
    neg_rotation: Mat4;
    rotation_input: Vec2;
    
    view: Mat4;
};

update_camera :: (camera : *Camera) {
	move_input: Vec3;
    
    move_speed := Camera.FLY_SPEED;
    if key_state(SDL_SCANCODE_LSHIFT) move_speed *= 10;
    
    move_input.x = key_state(SDL_SCANCODE_D) - key_state(SDL_SCANCODE_A);
    move_input.y = key_state(SDL_SCANCODE_E) - key_state(SDL_SCANCODE_Q);
    move_input.z = key_state(SDL_SCANCODE_W) - key_state(SDL_SCANCODE_S);
    move_input = vec3_rotate(normalize(move_input), camera.neg_rotation);
    
	camera.position += move_input * move_speed * g_delta_time;
    
    camera.rotation_input = lerp(camera.rotation_input, mouse.delta, Camera.ROTATION_SMOOTHING);
    delta:= camera.rotation_input * Camera.ROTATION_SPEED;
    camera.yaw += delta.x;
    camera.pitch += delta.y;
    camera.pitch = clamp(camera.pitch, -89.0, 89.0);
    
    camera.rotation = mat4_euler_rotation(.{camera.pitch * deg2rad, camera.yaw * deg2rad, 0});
    camera.neg_rotation = mat4_euler_rotation(.{-camera.pitch * deg2rad, -camera.yaw * deg2rad, 0});
    transform := mat4_translation(camera.position) * camera.rotation;
    camera.view = mat4_inverse(transform);
}

#scope_file

#import "Basic";