
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
    glBindBufferBase(GL_UNIFORM_BUFFER, 0, skinning_buffer);
    
    glGenVertexArrays(1, *vertex_array);
    glBindVertexArray(vertex_array);
    
    glBindBuffer(GL_ARRAY_BUFFER, position_buffer);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vec3), xx 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, tex_coord_buffer);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 2, GL_FLOAT, GL_FALSE, size_of(Vec2), xx 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, tangent_normal_buffer);
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 4, GL_FLOAT, GL_FALSE, size_of(Vec4), xx 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, bone_ids_buffer);
    glEnableVertexAttribArray(3);
    glVertexAttribIPointer(3, 4, GL_SHORT, size_of(Bone_Ids), xx 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, bone_weights_buffer);
    glEnableVertexAttribArray(4);
    glVertexAttribPointer(4, 3, GL_FLOAT, GL_FALSE, size_of(Vec3), xx 0);
    
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
    
    pixels := u8.[200, 200, 200, 255];
    default_grey_texture = create_texture("default_grey", 1, 1, pixels.data);
}

draw_line :: (start: Vec3, end: Vec3, thickness: float, colour: Vec4) {
    direction := normalize(end - start);
    up := Vec3.{0, 1, 0};
    
    right := normalize(cross_product(up, direction)) * thickness * 0.5;
    forward := normalize(cross_product(direction, right)) * thickness * 0.5;
    
    positions: [8] Vec3;
    positions[0] = start + right + forward;
    positions[1] = start - right + forward;
    positions[2] = start - right - forward;
    positions[3] = start + right - forward;
    positions[4] = end + right + forward;
    positions[5] = end - right + forward;
    positions[6] = end - right - forward;
    positions[7] = end + right - forward;
    
    normals := Vec3.[.{},.{},.{},.{},.{},.{},.{},.{}];
    
    indices := u32.[
                    // Front face
                    0, 1, 5, 0, 5, 4,
                    // Back face
                    3, 2, 6, 3, 6, 7,
                    // Left face
                    1, 2, 6, 1, 6, 5,
                    // Right face
                    0, 3, 7, 0, 7, 4,
                    // Top face
                    0, 1, 2, 0, 2, 3,
                    // Bottom face
                    4, 5, 6, 4, 6, 7
                    ];
    
    tex_coords := Vec2.[.{0, 0}, .{0, 0}, .{0, 0}, .{0, 0}, .{0, 0}, .{0, 0}, .{0, 0}, .{0, 0}];
    
    first_vertex, first_index := write_render_buffers(positions, tex_coords, normals, indices, .[], .[]);
    
    command: Draw_Command;
    command.shader = shader_coloured_mesh;
    command.first_vertex = first_vertex;
    command.first_index = first_index;
    command.index_count = indices.count;
    command.transform = mat4_identity();
    command.colour = colour;
    command.flags = .NO_DEPTH_TEST | .NO_BACKFACE_CULL;
    
    add_render_command(command);
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

draw_mesh :: (mesh: *Mesh, transform: Mat4) {
    positions := mesh.positions;
    tex_coords := mesh.tex_coords;
    indices := mesh.indices;
    normals := mesh.normals;
    
    first_vertex, first_index := write_render_buffers(positions, tex_coords, normals, indices, .[], .[]);
    
    command: Draw_Command;
    command.shader = shader_coloured_mesh;
    command.first_vertex = first_vertex;
    command.first_index = first_index;
    command.index_count = indices.count;
    command.transform = transform;
    command.colour = .{1, 1, 1, 1};
    command.mesh = mesh;
    
    add_render_command(command);
}

draw_skinned_mesh :: (mesh: *Mesh, player: *Anim_Player, transform: Mat4) {
    positions := mesh.positions;
    tex_coords := mesh.tex_coords;
    indices := mesh.indices;
    normals := mesh.tangents_normals;
    
    first_vertex, first_index := write_render_buffers(positions, tex_coords, normals, indices, mesh.bone_ids, mesh.weights);
    
    glBindBuffer(GL_UNIFORM_BUFFER, skinning_buffer);
    skinning_transforms := player.pose.skinning_transforms;
    glBufferSubData(GL_UNIFORM_BUFFER, 0, skinning_transforms.count * size_of(Mat4), skinning_transforms.data);
    
    test_texture := load_texture("mesh/man/textures/man-test-texture.png");
    
    command: Draw_Command;
    command.shader = shader_coloured_mesh;
    command.first_vertex = first_vertex;
    command.first_index = first_index;
    command.index_count = indices.count;
    command.transform = transform;
    command.colour = .{1, 1, 1, 1};
    command.textures[0] = test_texture.id;
    command.mesh = mesh;
    
    add_render_command(command);
}

renderer_draw_frame :: () {
    glClearColor(0,0,0,0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    projection := mat4_projection(45.0*PI/180.0, 1366.0/768.0, 0.01, 1000.0);
    
    for commands {
        glUseProgram(it.shader.id);
        
        set_shader_mat4(it.shader, "transform_matrix", it.transform);
        set_shader_mat4(it.shader, "view_matrix", camera.view);
        set_shader_mat4(it.shader, "projection_matrix", projection);
        set_shader_vec4(it.shader, "base_colour", it.colour);
        set_shader_vec4(it.shader, "screen_params", .{1366, 768, 0, 0}); //@todo
        set_shader_vec3(it.shader, "camera_position", camera.position);
        
        if it.shader.type == {
            case .COLOURED_MESH;
            prepare_coloured_mesh_shader(it.mesh, it.shader);
        }
        
        for it.textures {
            glActiveTexture(GL_TEXTURE0 + cast (u32) it_index);
            if it == 0 {
                glBindTexture(GL_TEXTURE_2D, default_grey_texture.id);
            } else {
                glBindTexture(GL_TEXTURE_2D, it);
            }
        }
        
        if it.flags & .NO_DEPTH_TEST glDisable(GL_DEPTH_TEST);
        
        if it.flags & .NO_BACKFACE_CULL {
            glDisable(GL_CULL_FACE);
        }
        
        glDrawElementsBaseVertex(GL_TRIANGLES, xx it.index_count, GL_UNSIGNED_INT, cast(*void) (it.first_index * size_of(u32)), xx it.first_vertex);
        
        if it.flags & .NO_DEPTH_TEST glEnable(GL_DEPTH_TEST);
        
        if it.flags & .NO_BACKFACE_CULL {
            glEnable(GL_CULL_FACE);
        }
    }
    
    written_indices = 0;
    written_vertices = 0;
    commands.count = 0;
}

MAX_BONES :: 1000;
MAX_WEIGHTS :: 4;

#scope_file

MAX_DRAW_COMMANDS :: 1000;
MAX_VERTICES :: 200000;
MAX_INDICES :: 200000;

renderer_arena: Arena;

commands: [] Draw_Command;

add_render_command :: (command: Draw_Command)  #no_abc {
    if commands.count + 1 >= MAX_DRAW_COMMANDS fatal_error("out of draw commands");
    commands[commands.count] = command;
    commands.count += 1;
}

default_grey_texture: *Texture;

position_buffer: u32;
tex_coord_buffer: u32;
tangent_normal_buffer: u32;
index_buffer: u32;
bone_ids_buffer: u32;
bone_weights_buffer: u32;
skinning_buffer: u32;

vertex_array: u32;

written_vertices: int;
written_indices: int;

Draw_Command_Flags :: enum_flags {
    NO_DEPTH_TEST;
    NO_BACKFACE_CULL;
}

Draw_Command :: struct {
    shader: *Shader;
    first_vertex: int;
    first_index: int;
    index_count: int;
    textures: [8] u32;
    transform: Mat4;
    colour: Vec4;
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

write_render_buffers :: (positions: [] Vec3, tex_coords: [] Vec2, tangents_normals: [] Vec4, indices: [] u32, bone_ids: [] Bone_Ids, bone_weights: [] Vec3) -> int, int {
    assert(tex_coords.count == positions.count);
    assert(normals.count == positions.count);
    
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
    glBufferSubData(GL_ARRAY_BUFFER, written_vertices * size_of(Vec4), normals.count * size_of(Vec4),
                    normals.data);
    
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
    
    written_vertices += positions.count;
    written_indices += indices.count;
    
    return first_vertex, first_index;
}

#import "GL";