
camera: Camera;

init_renderer :: () {
    gl_load(*gl);
    gl_enable_debug_output();
    glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
    
    renderer_arena = create_arena();
    
    commands = arena_push_n(*renderer_arena, Draw_Command, MAX_DRAW_COMMANDS);
    commands.count = 0;
    
    position_buffer = create_buffer("position_buffer", GL_ARRAY_BUFFER, MAX_VERTICES * size_of(Vec3));
    tex_coord_buffer = create_buffer("tex_coord_buffer", GL_ARRAY_BUFFER, MAX_VERTICES * size_of(Vec2));
    tangent_normal_buffer = create_buffer("normal_buffer", GL_ARRAY_BUFFER, MAX_VERTICES * size_of(Vec4));
    index_buffer = create_buffer("index_buffer", GL_ELEMENT_ARRAY_BUFFER, MAX_INDICES * size_of(u32));
    bone_ids_buffer = create_buffer("bone_ids", GL_ARRAY_BUFFER, MAX_VERTICES * size_of(Bone_Ids));
    bone_weights_buffer = create_buffer("bone_weights", GL_ARRAY_BUFFER, MAX_VERTICES * size_of(Vec3));
    skinning_buffer = create_buffer("skinning_buffer", GL_UNIFORM_BUFFER, MAX_BONES * size_of(Mat4));
    
    // normal vao
    {
        glGenVertexArrays(1, *vertex_array);
        glBindVertexArray(vertex_array);
        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, index_buffer);
        
        glBindBuffer(GL_ARRAY_BUFFER, position_buffer);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vec3), xx 0);
        
        glBindBuffer(GL_ARRAY_BUFFER, tex_coord_buffer);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 2, GL_FLOAT, GL_TRUE, size_of(Vec2), xx 0);
        
        glBindBuffer(GL_ARRAY_BUFFER, tangent_normal_buffer);
        glEnableVertexAttribArray(2);
        glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, size_of(Vec4), xx 0);
        
        glBindBuffer(GL_ARRAY_BUFFER, bone_ids_buffer);
        glEnableVertexAttribArray(3);
        glVertexAttribIPointer(3, 4, GL_SHORT, size_of(Bone_Ids), xx 0);
        
        glBindBuffer(GL_ARRAY_BUFFER, bone_weights_buffer);
        glEnableVertexAttribArray(4);
        glVertexAttribPointer(4, 3, GL_FLOAT, GL_FALSE, size_of(Vec3), xx 0);
        
        glBindVertexArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    }
    
    // depth pass vao
    {
        glGenVertexArrays(1, *depth_pass_vao);
        glBindVertexArray(depth_pass_vao);
        
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, index_buffer);
        
        glBindBuffer(GL_ARRAY_BUFFER, position_buffer);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vec3), xx 0);
        
        glBindBuffer(GL_ARRAY_BUFFER, bone_ids_buffer);
        glEnableVertexAttribArray(3);
        glVertexAttribIPointer(3, 4, GL_SHORT, size_of(Bone_Ids), xx 0);
        
        glBindBuffer(GL_ARRAY_BUFFER, bone_weights_buffer);
        glEnableVertexAttribArray(4);
        glVertexAttribPointer(4, 3, GL_FLOAT, GL_FALSE, size_of(Vec3), xx 0);
        
        glBindVertexArray(0);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    }
    
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, skinning_buffer);
    
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    
    pixels := u8.[200, 200, 200, 255];
    default_grey_texture = create_texture("default_grey", 1, 1, pixels.data);
    
    glGenTextures(1, *shadow_map_texture);
    glBindTexture(GL_TEXTURE_2D, shadow_map_texture);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_DEPTH_COMPONENT, SHADOW_MAP_SIZE, SHADOW_MAP_SIZE, 0, GL_DEPTH_COMPONENT, GL_FLOAT, null);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    glGenFramebuffers(1, *shadow_map_frame_buffer);
    glBindFramebuffer(GL_FRAMEBUFFER, shadow_map_frame_buffer);
    glFramebufferTexture2D(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_TEXTURE_2D, shadow_map_texture, 0);
    glDrawBuffer(GL_NONE);
    glReadBuffer(GL_NONE);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

line_helper :: (start: Vec3, end: Vec3, thickness: float) -> int, int, int {
    direction := normalize(end - start);
    
    right, forward: Vec3;
    if (abs(dot_product(basis_up, direction)) > 0.99) {
        right = basis_right * thickness * 0.5;
        forward = basis_forward * thickness * 0.5;
    } else {
        right = normalize(cross_product(basis_up, direction)) * thickness * 0.5;
        forward = normalize(cross_product(direction, right)) * thickness * 0.5;
    }
    
    positions: [8] Vec3;
    positions[0] = start + right + forward;
    positions[1] = start - right + forward;
    positions[2] = start - right - forward;
    positions[3] = start + right - forward;
    positions[4] = end + right + forward;
    positions[5] = end - right + forward;
    positions[6] = end - right - forward;
    positions[7] = end + right - forward;
    
    indices := u32.[
                    0, 1, 5, 0, 5, 4,
                    3, 2, 6, 3, 6, 7,
                    1, 2, 6, 1, 6, 5,
                    0, 3, 7, 0, 7, 4,
                    0, 1, 2, 0, 2, 3,
                    4, 5, 6, 4, 6, 7
                    ];
    
    tangents_normals := arena_push_n(*frame_arena, Vec4, positions.count);
    tex_coords := arena_push_n(*frame_arena, Vec2, positions.count);
    
    first_vertex, first_index := write_render_buffers(positions, tex_coords, tangents_normals, indices);
    
    return first_vertex, first_index, indices.count;
}

draw_line :: (start: Vec3, end: Vec3, thickness: float, colour: Vec4) {
    first_vertex, first_index, num_indices := line_helper(start, end, 10);
    
    command: Draw_Command;
    command.shader = shader_coloured_mesh;
    command.first_vertex = first_vertex;
    command.first_index = first_index;
    command.index_count = num_indices;
    command.transform = mat4_identity();
    command.projection = mat4_projection(45.0*PI/180.0, 1366.0/768.0, NEAR_Z_PLANE, FAR_Z_PLANE);
    command.colour = colour;
    command.flags = .NO_DEPTH_TEST | .NO_BACKFACE_CULL;
    
    add_render_command(command);
}

draw_axes :: () {
    bases := Vec3.[basis_forward, basis_right, basis_up];
    colours := Vec4.[.{1, 0, 0, 1}, .{0, 1, 0, 1}, .{0, 0, 1, 1}];
    for bases {
        first_vertex, first_index, num_indices := line_helper(.{0, 0, 0}, it * 100, 5);
        
        command: Draw_Command;
        command.shader = shader_2d_mesh;
        command.first_vertex = first_vertex;
        command.first_index = first_index;
        command.index_count = num_indices;
        command.transform = mat4_identity();mat4_translation(.{(-1366/2)+400, (-768/2)+200, 0})*mat4_rotation(camera.rotation);
        origin := Vec2.{100, 100};
        size := Vec2.{300, 300};
        command.projection =  mat4_ortho(-400, 400, -400, 400, -999, 999);
        command.colour = colours[it_index];
        command.flags = .NO_BACKFACE_CULL;
        add_render_command(command);
    }
}

draw_pose :: (player: *Anim_Player, transform: Mat4) {
    colours := Vec4.[
                     .{1, 0, 0, 1},    // Red
                     .{0, 1, 0, 1},    // Green
                     .{0, 0, 1, 1},    // Blue
                     .{1, 1, 0, 1},    // Yellow
                     .{1, 0, 1, 1},    // Magenta
                     .{0, 1, 1, 1},    // Cyan
                     .{0.5, 0.5, 0.5, 1},  // Grey
                     .{1, 0.5, 0, 1},  // Orange
                     .{0.5, 0, 0.5, 1},  // Purple
                     .{0.5, 1, 0, 1},  // Lime
                     ];
    
    pose := *player.pose;
    for pose.bone_names {
        bone := find_bone(player.mesh.skeleton, it);
        
        parent_transform := transform * pose.parent_model_space_transforms[bone.id];
		world_space_transform := transform * pose.model_space_transforms[bone.id];
        
		start := Vec3.{
            parent_transform._14,
            parent_transform._24,
            parent_transform._34
        };
        
		end := Vec3.{
            world_space_transform._14,
            world_space_transform._24,
            world_space_transform._34
        };
        
        draw_line(start, end, 0.01, colours[it_index % 10]);
    }
}

draw_2d_quad :: (position: Vec2, size: Vec2, colour: Vec4) {
    draw_2d_textured_quad(position, size, colour, null);
}

draw_2d_textured_quad :: (position: Vec2, size: Vec2, colour: Vec4, texture: *Texture) {
    positions := Vec3.[
                       .{position.x, position.y, 0},
                       .{position.x + size.x, position.y, 0},
                       .{position.x + size.x, position.y + size.y, 0},
                       .{position.x, position.y + size.y, 0}
                       ];
    
    tex_coords := Vec2.[
                        .{0.0, 0.0},
                        .{1.0, 0.0},
                        .{1.0, 1.0},
                        .{0.0, 1.0}
                        ];
    
    indices := u32.[
                    0, 1, 2,
                    0, 2, 3
                    ];
    
    tangents_normals := Vec4.[
                              .{0.0, 0.0, 0.0, 0.0},
                              .{0.0, 0.0, 0.0, 0.0},
                              .{0.0, 0.0, 0.0, 0.0},
                              .{0.0, 0.0, 0.0, 0.0}
                              ];
    
    first_vertex, first_index := write_render_buffers(positions, tex_coords, tangents_normals, indices);
    
    command: Draw_Command;
    command.shader = shader_2d_textured;
    command.first_vertex = first_vertex;
    command.first_index = first_index;
    command.index_count = indices.count;
    command.transform = mat4_identity();
    command.projection = mat4_ortho(0, 1366, 0, 768, -999, 999);
    command.colour = colour;
    if texture command.textures[0] = texture.id;
    command.flags = .NO_DEPTH_WRITE;
    
    add_render_command(command);
}

draw_mesh :: (mesh: *Mesh, transform: Mat4) {
    positions := mesh.positions;
    tex_coords := mesh.tex_coords;
    indices := mesh.indices;
    tangents_normals := mesh.tangents_normals;
    
    first_vertex, first_index := write_render_buffers(positions, tex_coords, tangents_normals, indices);
    
    command: Draw_Command;
    
    base_colour := load_texture("mesh/maps/test/floor_diffuse.png");
    normal_map := load_texture("mesh/maps/test/floor_normal.png");
    rmaoh_map := load_texture("mesh/maps/test/floor_rmaoh.png");
    command.material_scale = 25;
    
    if (equal(mesh.path, "mesh/cube/cube.mesh")) {
        base_colour = load_texture("mesh/cube/textures/cube_diffuse.png");
        normal_map = load_texture("mesh/cube/textures/cube_normal.png");
        rmaoh_map = load_texture("mesh/cube/textures/cube_rmaoh.png");
        command.material_scale = 5;
    }
    
    command.shader = shader_coloured_mesh;
    command.first_vertex = first_vertex;
    command.first_index = first_index;
    command.index_count = indices.count;
    command.transform = transform;
    command.projection = mat4_projection(45.0*PI/180.0, 1366.0/768.0, NEAR_Z_PLANE, FAR_Z_PLANE);
    command.colour = .{1, 1, 1, 1};
    command.textures[0] = base_colour.id;
    command.textures[1] = normal_map.id;
    command.textures[2] = rmaoh_map.id;
    command.flags = .CASTS_SHADOWS;
    command.mesh = mesh;
    
    add_render_command(command);
}

draw_skinned_mesh :: (mesh: *Mesh, player: *Anim_Player, transform: Mat4) {
    positions := mesh.positions;
    tex_coords := mesh.tex_coords;
    indices := mesh.indices;
    tangents_normals := mesh.tangents_normals;
    
    first_vertex, first_index := write_render_buffers(positions, tex_coords, tangents_normals, indices, mesh.bone_ids, mesh.weights);
    
    glBindBuffer(GL_UNIFORM_BUFFER, skinning_buffer);
    skinning_transforms := player.pose.skinning_transforms;
    glBufferSubData(GL_UNIFORM_BUFFER, 0, skinning_transforms.count * size_of(Mat4), skinning_transforms.data);
    
    base_colour := load_texture("mesh/man/textures/man_diffuse.png");
    normal_map := load_texture("mesh/man/textures/man_normal.png");
    rmao_map := load_texture("mesh/man/textures/man_rmao.png");
    
    command: Draw_Command;
    command.shader = shader_coloured_mesh;
    command.first_vertex = first_vertex;
    command.first_index = first_index;
    command.index_count = indices.count;
    command.transform = transform;
    command.colour = .{1, 1, 1, 1};
    command.material_scale = 2.0;
    command.textures[0] = base_colour.id;
    command.textures[1] = normal_map.id;
    command.textures[2] = rmao_map.id;
    command.flags = .CASTS_SHADOWS;
    command.mesh = mesh;
    
    add_render_command(command);
}

calc_projection_corners :: (proj: Mat4, view: Mat4) -> [] Vec4 {
    inverse := mat4_inverse(proj * view);
    
    points := arena_push_n(*frame_arena, Vec4, 8);
    points[0] = inverse * Vec4.{-1.0, -1.0, -1.0, 1.0};
    points[1] = inverse * Vec4.{-1.0, -1.0,  1.0, 1.0};
    points[2] = inverse * Vec4.{-1.0,  1.0, -1.0, 1.0};
    points[3] = inverse * Vec4.{-1.0,  1.0,  1.0, 1.0};
    points[4] = inverse * Vec4.{ 1.0, -1.0, -1.0, 1.0};
    points[5] = inverse * Vec4.{ 1.0, -1.0,  1.0, 1.0};
    points[6] = inverse * Vec4.{ 1.0,  1.0, -1.0, 1.0};
    points[7] = inverse * Vec4.{ 1.0,  1.0,  1.0, 1.0};
    return points;
}

calc_light_space_matrix :: (near: float, far: float, view: Mat4) -> Mat4, Mat4, Mat4 {
    projection := mat4_projection(45.0*PI/180.0, 1366.0/768.0, near, far);
    
    corners := calc_projection_corners(projection, view);
    center: Vec3;
    for corners center += it.xyz;
    i := 1.0 / corners.count;
    center *= Vec3.{i, i, i};
    
    light_pos := Vec3.{21.951605, 21.838087, -14.048857};
    look_at_target := Vec3.{0, 0, 0};
    light_dir := normalize(look_at_target - light_pos);
    light_view := mat4_look_at(center + light_dir, center);
    
    scene_min_bounds := Vec3.{FLOAT32_MAX, FLOAT32_MAX, FLOAT32_MAX};
    scene_max_bounds := Vec3.{FLOAT32_MIN, FLOAT32_MIN, FLOAT32_MIN};
    
    for corners {
        corner_light_space := light_view * it;
        scene_min_bounds.x = min(scene_min_bounds.x, corner_light_space.x);
        scene_min_bounds.y = min(scene_min_bounds.y, corner_light_space.y);
        scene_min_bounds.z = min(scene_min_bounds.z, corner_light_space.z);
        
        scene_max_bounds.x = max(scene_max_bounds.x, corner_light_space.x);
        scene_max_bounds.y = max(scene_max_bounds.y, corner_light_space.y);
        scene_max_bounds.z = max(scene_max_bounds.z, corner_light_space.z);
    }
    
    z_pad := 10.0;
    if scene_min_bounds.z < 0 scene_min_bounds.z *= z_pad;
    else scene_min_bounds.z /= z_pad;
    
    if scene_max_bounds.z < 0 scene_max_bounds.z /= z_pad;
    else scene_max_bounds.z *= z_pad;
    
    light_proj := mat4_ortho(scene_min_bounds.x, scene_max_bounds.x, scene_min_bounds.y, scene_max_bounds.y, scene_min_bounds.z, scene_max_bounds.z);
    
    return light_proj * light_view, light_view, light_proj;
}

calc_light_space_matrices :: () -> [] Mat4 {
    light_space_matrices := arena_push_n(*frame_arena, Mat4, SHADOW_CASCADES.count + 1);
    
    for 0..SHADOW_CASCADES.count {
        if it == 0 light_space_matrices[it] = calc_light_space_matrix(NEAR_Z_PLANE, SHADOW_CASCADES[it], camera.view);
        else if it < SHADOW_CASCADES.count light_space_matrices[it] = calc_light_space_matrix(SHADOW_CASCADES[it - 1], SHADOW_CASCADES[it], camera.view);
        else
            light_space_matrices[it] = calc_light_space_matrix(SHADOW_CASCADES[it - 1], FAR_Z_PLANE, camera.view);
    }
    
    return light_space_matrices;
}

show_depth_buffer := false;
show_axes := true;

renderer_draw_frame :: () {
    if key_pressed(SDL_SCANCODE_F1) show_depth_buffer = !show_depth_buffer;
    if key_pressed(SDL_SCANCODE_F2) show_axes = !show_axes;
    
    if show_depth_buffer {
        t: Texture;
        t.id = shadow_map_texture;
        draw_2d_textured_quad(.{100, 100}, .{300, 300}, .{1, 1, 1, 1}, *t);
    }
    
    if show_axes {
        draw_axes();
    }
    
    projection := mat4_projection(45.0*PI/180.0, 1366.0/768.0, NEAR_Z_PLANE, FAR_Z_PLANE);
    view_matrix := camera.view;
    
    light_matrix, light_view, light_proj := calc_light_space_matrix(NEAR_Z_PLANE, FAR_Z_PLANE, projection);
    
    glClearColor(0,0,0,0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glViewport(0, 0, SHADOW_MAP_SIZE, SHADOW_MAP_SIZE);
    glBindFramebuffer(GL_FRAMEBUFFER, shadow_map_frame_buffer);
    glClear(GL_DEPTH_BUFFER_BIT);
    
    glUseProgram(shader_depth_pass.id);
    set_shader_mat4(shader_depth_pass, "light_view", light_view);
    set_shader_mat4(shader_depth_pass, "light_projection", light_proj);
    
    glBindVertexArray(depth_pass_vao);
    
    for commands {
        set_shader_mat4(shader_depth_pass, "transform_matrix", it.transform);
        
        if it.flags & .NO_DEPTH_WRITE glDepthMask(GL_FALSE);
        
        glDrawElementsBaseVertex(GL_TRIANGLES, xx it.index_count, GL_UNSIGNED_INT, cast(*void) (it.first_index * size_of(u32)), xx it.first_vertex);
        
        if it.flags & .NO_DEPTH_WRITE glDepthMask(GL_TRUE);
    }
    
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
    
    glViewport(0, 0, 1366, 768); // @todo
    glBindVertexArray(vertex_array);
    
    for commands {
        glUseProgram(it.shader.id);
        
        set_shader_mat4(it.shader, "transform_matrix", it.transform);
        set_shader_mat4(it.shader, "view_matrix", camera.view);
        set_shader_mat4(it.shader, "projection_matrix", it.projection);
        
        light_pos := Vec3.{-14.048857, -21.951605, 21.838087};
        look_at_target := Vec3.{0, 0, 0};
        light_dir := normalize(look_at_target - light_pos);
        set_shader_vec3(it.shader, "light_dir", light_dir);
        
        set_shader_mat4(it.shader, "light_matrix", light_matrix);
        set_shader_vec4(it.shader, "base_colour", it.colour);
        set_shader_vec4(it.shader, "screen_params", .{1366, 768, 0, 0}); //@todo
        set_shader_vec3(it.shader, "camera_position", camera.position);
        set_shader_float(it.shader, "material_scale", it.material_scale);
        
        if it.shader.type == {
            case .COLOURED_MESH;
            prepare_coloured_mesh_shader(it.mesh, it.shader);
        }
        
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, shadow_map_texture);
        
        for it.textures {
            glActiveTexture(GL_TEXTURE1 + cast (u32) it_index);
            if it == 0 {
                glBindTexture(GL_TEXTURE_2D, default_grey_texture.id);
            } else {
                glBindTexture(GL_TEXTURE_2D, it);
            }
        }
        
        if it.flags & .NO_DEPTH_TEST glDisable(GL_DEPTH_TEST);
        
        //if it.flags & .NO_BACKFACE_CULL {
        glDisable(GL_CULL_FACE);
        //}
        
        glDrawElementsBaseVertex(GL_TRIANGLES, xx it.index_count, GL_UNSIGNED_INT, cast(*void) (it.first_index * size_of(u32)), xx it.first_vertex);
        
        if it.flags & .NO_DEPTH_TEST glEnable(GL_DEPTH_TEST);
        
        //if it.flags & .NO_BACKFACE_CULL {
        glEnable(GL_CULL_FACE);
        //}
    }
    
    glBindVertexArray(0);
    
    written_indices = 0;
    written_vertices = 0;
    commands.count = 0;
}

MAX_BONES :: 1000;
MAX_WEIGHTS :: 4;

#scope_file

#import "GL";

MAX_DRAW_COMMANDS :: 20000;
MAX_VERTICES :: 2000000;
MAX_INDICES :: 2000000;

renderer_arena: Arena;

commands: [] Draw_Command;

add_render_command :: (command: Draw_Command)  #no_abc {
    if commands.count + 1 >= MAX_DRAW_COMMANDS fatal_error("out of draw commands");
    commands[commands.count] = command;
    commands.count += 1;
}

default_grey_texture: *Texture;

NEAR_Z_PLANE :: 0.1;
FAR_Z_PLANE :: 100.0;

SHADOW_CASCADES :: float.[ FAR_Z_PLANE / 50.0, FAR_Z_PLANE / 25.0, FAR_Z_PLANE / 10.0, FAR_Z_PLANE / 2.0 ];

SHADOW_MAP_SIZE :: 4096;
shadow_map_frame_buffer: u32;
shadow_map_texture: u32;

position_buffer: u32;
tex_coord_buffer: u32;
tangent_normal_buffer: u32;
index_buffer: u32;
bone_ids_buffer: u32;
bone_weights_buffer: u32;
skinning_buffer: u32;

vertex_array: u32;
depth_pass_vao: u32;

written_vertices: int;
written_indices: int;

Draw_Command_Flags :: enum_flags {
    NO_DEPTH_TEST;
    NO_DEPTH_WRITE;
    NO_BACKFACE_CULL;
    CASTS_SHADOWS; // must set command.mesh if this is set
}

Draw_Command :: struct {
    shader: *Shader;
    first_vertex: int;
    first_index: int;
    index_count: int;
    textures: [8] u32;
    transform: Mat4;
    projection: Mat4;
    colour: Vec4;
    material_scale: float;
    flags: Draw_Command_Flags;
    
    // extra info for certain draw calls
    mesh: *Mesh;
}

create_buffer :: (name: string, target: u32, size: int) -> u32 {
    id: u32;
    glGenBuffers(1, *id);
    glBindBuffer(target, id);
    glBufferData(target, xx size, null, GL_STATIC_DRAW);
    glObjectLabel(GL_BUFFER, id, xx name.count, name.data);
    return id;
}

write_render_buffers :: (positions: [] Vec3, tex_coords: [] Vec2, tangents_normals: [] Vec4, indices: [] u32, bone_ids: [] Bone_Ids = .[], bone_weights: [] Vec3 = .[]) -> int, int {
    assert(tex_coords.count == positions.count);
    assert(tangents_normals.count == positions.count);
    
    if written_vertices + positions.count >= MAX_VERTICES {
        fatal_error("Out of vertices: written %, wanted %, max is %", written_vertices, positions.count, MAX_VERTICES);
    }
    if written_indices + indices.count >= MAX_INDICES {
        fatal_error("Out of indices: written %, wanted %, max is %", written_indices, indices.count, MAX_INDICES);
    }
    
    first_vertex := written_vertices;
    first_index := written_indices;
    
    glBindBuffer(GL_ARRAY_BUFFER, position_buffer);
    glBufferSubData(GL_ARRAY_BUFFER, written_vertices * size_of(Vec3), positions.count * size_of(Vec3), positions.data);
    glBindBuffer(GL_ARRAY_BUFFER, tex_coord_buffer);
    glBufferSubData(GL_ARRAY_BUFFER, written_vertices * size_of(Vec2), tex_coords.count * size_of(Vec2), tex_coords.data);
    glBindBuffer(GL_ARRAY_BUFFER, tangent_normal_buffer);
    glBufferSubData(GL_ARRAY_BUFFER, written_vertices * size_of(Vec4), tangents_normals.count * size_of(Vec4),
                    tangents_normals.data);
    
    if (bone_ids.count > 0) {
        assert(bone_ids.count == positions.count);
        assert(bone_weights.count == positions.count);
        
        glBindBuffer(GL_ARRAY_BUFFER, bone_ids_buffer);
        glBufferSubData(GL_ARRAY_BUFFER, written_vertices * size_of(Bone_Ids), bone_ids.count * size_of(Bone_Ids),
                        bone_ids.data);
        glBindBuffer(GL_ARRAY_BUFFER, bone_weights_buffer);
        glBufferSubData(GL_ARRAY_BUFFER, written_vertices * size_of(Vec3), bone_weights.count * size_of(Vec3),
                        bone_weights.data);
    } else {
        empty_bone_ids := arena_push_n(*frame_arena, Bone_Ids, xx positions.count);
        for * empty_bone_ids it.* = .{-1, -1, -1, -1};
        empty_bone_weights := arena_push_n(*frame_arena, Vec3, xx positions.count);
        
        glBindBuffer(GL_ARRAY_BUFFER, bone_ids_buffer);
        glBufferSubData(GL_ARRAY_BUFFER, written_vertices * size_of(Bone_Ids), empty_bone_ids.count * size_of(Bone_Ids),
                        empty_bone_ids.data);
        glBindBuffer(GL_ARRAY_BUFFER, bone_weights_buffer);
        glBufferSubData(GL_ARRAY_BUFFER, written_vertices * size_of(Vec3), empty_bone_weights.count * size_of(Vec3),
                        empty_bone_weights.data);
    }
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, index_buffer);
    glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, written_indices * size_of(u32), indices.count * size_of(u32), indices.data);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
    
    written_vertices += positions.count;
    written_indices += indices.count;
    
    return first_vertex, first_index;
}