
Camera :: struct {
	FLY_SPEED :: 1.0;
    ROTATION_SPEED :: 0.3;
    ROTATION_SMOOTHING :: 0.3;
    
    rotation_around_up: float;
    rotation_around_right: float;
    rotation_input: Vec2;
    position: Vec3;
    
    rotation: Quaternion;
    neg_rotation: Mat4;
    transform: Mat4;
    view: Mat4;
};

update_camera :: (camera : *Camera) {
	move_input: Vec3;
    
    move_speed := Camera.FLY_SPEED;
    if key_state(SDL_SCANCODE_LSHIFT) move_speed *= 10;
    
    move_input.x = key_state(SDL_SCANCODE_S) - key_state(SDL_SCANCODE_W);
    move_input.y = key_state(SDL_SCANCODE_D) - key_state(SDL_SCANCODE_A);
    move_input.z = key_state(SDL_SCANCODE_Q) - key_state(SDL_SCANCODE_E);
    move_input = vec3_rotate(normalize(move_input), camera.rotation);
    
	camera.position += move_input * move_speed * delta_time;
    
    camera.rotation_input = lerp(camera.rotation_input, mouse.delta, Camera.ROTATION_SMOOTHING);
    delta := camera.rotation_input * Camera.ROTATION_SPEED;
    camera.rotation_around_up += delta.x * deg2rad;
    camera.rotation_around_right += delta.y * deg2rad;
    camera.rotation_around_right = clamp(camera.rotation_around_right, -80.0 * deg2rad, 80.0 * deg2rad);
    
    rotation_around_up := quat_axis_angle(.{0, 1, 0}, camera.rotation_around_up);
    rotation_around_right := quat_axis_angle(.{1, 0, 0}, camera.rotation_around_right);
    camera.rotation = rotation_around_up * rotation_around_right;
    
    camera.transform = mat4_translation(camera.position) * mat4_rotation(camera.rotation);
    
    camera.view = mat4_inverse(camera.transform);
}

#scope_file

#import "Basic";