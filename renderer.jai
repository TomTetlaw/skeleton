
camera: Camera;

init_renderer :: () {
    gl_load(*gl);
    gl_enable_debug_output();
    glEnable(GL_DEBUG_OUTPUT_SYNCHRONOUS);
    
    renderer_arena = create_arena();
    
    commands = arena_push_n(*renderer_arena, Draw_Command, MAX_DRAW_COMMANDS);
    commands.count = 0;
    
    position_buffer = create_buffer("position_buffer", GL_ARRAY_BUFFER, MAX_VERTICES * size_of(Vec3));
    colour_buffer = create_buffer("colour_buffer", GL_ARRAY_BUFFER, MAX_VERTICES * size_of(Vec4));
    tex_coord_buffer = create_buffer("tex_coord_buffer", GL_ARRAY_BUFFER, MAX_VERTICES * size_of(Vec2));
    normal_buffer = create_buffer("normal_buffer", GL_ARRAY_BUFFER, MAX_VERTICES * size_of(Vec3));
    index_buffer = create_buffer("index_buffer", GL_ELEMENT_ARRAY_BUFFER, MAX_INDICES * size_of(u32));
    
    glGenVertexArrays(1, *vertex_array);
    glBindVertexArray(vertex_array);
    
    glBindBuffer(GL_ARRAY_BUFFER, position_buffer);
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, size_of(Vec3), xx 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, colour_buffer);
    glEnableVertexAttribArray(1);
    glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, size_of(Vec4), xx 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, tex_coord_buffer);
    glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, size_of(Vec2), xx 0);
    
    glBindBuffer(GL_ARRAY_BUFFER, normal_buffer);
    glEnableVertexAttribArray(3);
    glVertexAttribPointer(3, 3, GL_FLOAT, GL_FALSE, size_of(Vec3), xx 0);
    
    glEnable(GL_DEPTH_TEST);
    glDepthFunc(GL_LESS);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_BACK);
}

draw_line :: (start: Vec3, end: Vec3, thickness: float, colour: Vec4) {
    direction := normalize(end - start);
    up := Vec3.{0, 1, 0};
    right := normalize(cross_product(up, direction));
    
    right = right * thickness * 0.5;
    
    positions: [6] Vec3;
    positions[0] = .{start.x + right.x, start.y + right.y, start.z + right.z};
    positions[1] = .{start.x - right.x, start.y - right.y, start.z - right.z};
    positions[2] = .{end.x + right.x, end.y + right.y, end.z + right.z};
    positions[3] = .{end.x + right.x, end.y + right.y, end.z + right.z};
    positions[4] = .{start.x - right.x, start.y - right.y, start.z - right.z};
    positions[5] = .{end.x - right.x, end.y - right.y, end.z - right.z};
    
    tex_coords := Vec2.[.{0, 0}, .{0, 0}, .{0, 0}, .{0, 0}, .{0, 0}, .{0, 0}];
    colours := Vec4.[colour, colour, colour, colour, colour, colour];
    normals := Vec3.[.{0, 0, 0}, .{0, 0, 0}, .{0, 0, 0}, .{0, 0, 0}, .{0, 0, 0}, .{0, 0, 0}];
    indices := u32.[0, 1, 2, 3, 4, 5];
    
    first_vertex, first_index := write_render_buffers(positions, colours, tex_coords, normals, indices);
    
    command: Draw_Command;
    command.shader = shader_coloured_mesh;
    command.first_vertex = first_vertex;
    command.first_index = first_index;
    command.index_count = indices.count;
    command.transform = mat4_identity();
    command.colour = .{1, 1, 1, 1};
    command.flags = .NO_DEPTH_TEST | .NO_BACKFACE_CULL;
    
    add_render_command(command);
}

draw_skeleton :: (skeleton: *Skeleton, transform: Mat4, colour: Vec4) {
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
    
	for * skeleton.bones {
		parent_transform: Mat4 = ---;
        parent := it.parent;
        
		if parent parent_transform = transform * parent.model_space_transform;
		else parent_transform = transform;
        
		world_space_transform := transform * it.model_space_transform;
        
		start := Vec3.{
            parent_transform._03,
            parent_transform._13,
            parent_transform._23
        };
        
		end := Vec3.{
            world_space_transform._03,
            world_space_transform._13,
            world_space_transform._23
        };
        
        name := it.name;
        pname := ifx it.parent then it.parent.name else "";
        
		draw_line(start, end, 0.5, colours[it_index%9]);
	}
}

draw_mesh :: (mesh: *Mesh, transform: Mat4) {
    positions := mesh.positions;
    colours := mesh.colours;
    tex_coords := mesh.tex_coords;
    indices := mesh.indices;
    normals := mesh.normals;
    
    first_vertex, first_index := write_render_buffers(positions, colours, tex_coords, normals, indices);
    
    command: Draw_Command;
    command.shader = shader_coloured_mesh;
    command.first_vertex = first_vertex;
    command.first_index = first_index;
    command.index_count = indices.count;
    command.transform = transform;
    command.colour = .{1, 1, 1, 1};
    
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
        
        if it.shader.type == {
            case .COLOURED_MESH;
            prepare_coloured_mesh_shader(it.shader);
        }
        
        for it.textures {
            glActiveTexture(GL_TEXTURE0 + cast (u32) it_index);
            glBindTexture(GL_TEXTURE_2D, it);
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

position_buffer: u32;
colour_buffer: u32;
tex_coord_buffer: u32;
normal_buffer: u32;
index_buffer: u32;

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
}

create_buffer :: (name: string, target: u32, size: int) -> u32 {
    id: u32;
    glGenBuffers(1, *id);
    glBindBuffer(target, id);
    glBufferData(target, xx size, null, GL_STATIC_DRAW);
    glObjectLabel(GL_BUFFER, id, xx name.count, name.data);
    return id;
}

write_render_buffers :: (positions: [] Vec3, colours: [] Vec4, tex_coords: [] Vec2, normals: [] Vec3, indices: [] u32) -> int, int {
    assert(colours.count == positions.count);
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
    glBindBuffer(GL_ARRAY_BUFFER, colour_buffer);
    glBufferSubData(GL_ARRAY_BUFFER, written_vertices * size_of(Vec4), colours.count * size_of(Vec4), colours.data);
    glBindBuffer(GL_ARRAY_BUFFER, tex_coord_buffer);
    glBufferSubData(GL_ARRAY_BUFFER, written_vertices * size_of(Vec2), tex_coords.count * size_of(Vec2), tex_coords.data);
    glBindBuffer(GL_ARRAY_BUFFER, normal_buffer);
    glBufferSubData(GL_ARRAY_BUFFER, written_vertices * size_of(Vec3), normals.count * size_of(Vec3),
                    normals.data);
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, index_buffer);
    glBufferSubData(GL_ELEMENT_ARRAY_BUFFER, written_indices * size_of(u32), indices.count * size_of(u32), indices.data);
    
    written_vertices += positions.count;
    written_indices += indices.count;
    
    return first_vertex, first_index;
}

#import "GL";