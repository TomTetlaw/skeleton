
Shader :: struct {
    id: u32;
    uniforms: [..] s32;
    hash_map: [] int;
    type: Shader_Type;
}

get_shader_location :: (shader: *Shader, name: string) -> s32 {
    hash_index := djb2_hash(name) % UNIFORM_MAP_SIZE;
    index := shader.hash_map[hash_index];
    if index == -1 return -1;
    
    loc := shader.uniforms[index];
    return loc;
}

set_shader_int :: (shader: *Shader, name: string, value: s32) {
    loc := get_shader_location(shader, name);
    glUniform1i(loc, value);
}

set_shader_vec2 :: (shader: *Shader, name: string, value: Vec2) {
    loc := get_shader_location(shader, name);
    glUniform2f(loc, value.x, value.y);
}

set_shader_vec4 :: (shader: *Shader, name: string, value: Vec4) {
    loc := get_shader_location(shader, name);
    glUniform4f(loc, value.x, value.y, value.z, value.w);
}

set_shader_mat4 :: (shader: *Shader, name: string, value: Mat4) {
    loc := get_shader_location(shader, name);
    glUniformMatrix4fv(loc, 1, GL_TRUE, cast (*float) *value);
}

set_shader_texture :: (shader: *Shader, name: string, value: u32, unit: u32) {
    loc := get_shader_location(shader, name);
    glActiveTexture(GL_TEXTURE0 + unit);
    glBindTexture(GL_TEXTURE_2D, value);
    glUniform1i(loc, xx unit);
}

create_shader :: (name: string, type: Shader_Type, shader_text: string) -> *Shader {
    make_shader_object :: (name: string, shader: string, prefix: string, shader_type : u32) -> u32 {
        shader_object := glCreateShader(shader_type);
        
        shaders: [2] *u8;
        lengths: [2] s32;
        
        shaders[0] = prefix.data;
        shaders[1] = shader.data;
        lengths[0] = xx prefix.count;
        lengths[1] = xx shader.count;
        
        glShaderSource(shader_object, 2, shaders.data, lengths.data);
        
        glCompileShader(shader_object);
        
        success : GLint;
        glGetShaderiv(shader_object, GL_COMPILE_STATUS, *success);
        
        if !success then {
            log_data: [4096] u8;
            glGetShaderInfoLog(shader_object, log_data.count, null, log_data.data);
            fatal_error("Error compiling shader file %: %", name, to_string(log_data.data));
            return 0;
        }
        
        return shader_object;
    }
    
    PREFIX_V := #string HERE
#version 330 core
#define VERTEX_SHADER 1
#define FRAGMENT_SHADER 0
#define INOUT out
        HERE;
    
    PREFIX_F := #string HERE
#version 330 core
#define VERTEX_SHADER 0
#define FRAGMENT_SHADER 1
#define INOUT in
        HERE;
    
    shader_v := make_shader_object(tprint("%_vertex_shader", name), shader_text, PREFIX_V, GL_VERTEX_SHADER);
    shader_f := make_shader_object(tprint("%_fragment_shader", name), shader_text, PREFIX_F, GL_FRAGMENT_SHADER);
    shader_p := glCreateProgram();
    
    glAttachShader(shader_p, shader_v);
    glAttachShader(shader_p, shader_f);
    glLinkProgram(shader_p);
    
    success : GLint = 0;
    glGetProgramiv(shader_p, GL_LINK_STATUS, *success);
    
    if !success {
        log_data: [4096] u8;
        glGetProgramInfoLog(shader_p, log_data.count, null, log_data.data);
        fatal_error("Error linking program object %: %", name, to_string(log_data.data));
        return *null_shader;
    }
    
    glDeleteShader(shader_v);
    glDeleteShader(shader_f);
    
    glValidateProgram(shader_p);
    glGetProgramiv(shader_p, GL_VALIDATE_STATUS, *success);
    
    if !success {
        log_data: [4096] u8;
        glGetProgramInfoLog(shader_p, log_data.count, null, log_data.data);
        fatal_error("Error validating program object %: %", name, to_string(log_data.data));
        return *null_shader;
    }
    
    shader := arena_push(*shaders);
    shader.id = shader_p;
    shader.hash_map = arena_push_n(*shader_arena, int, UNIFORM_MAP_SIZE);
    shader.type = type;
    
    for 0..UNIFORM_MAP_SIZE-1 shader.hash_map[it] = -1;
    
    active_uniform_count: s32;
    glGetProgramiv(shader_p, GL_ACTIVE_UNIFORMS, *active_uniform_count);
    for 0..active_uniform_count-1 {
        buffer: [128] u8;
        length: u32;
        size: s32;
        type: u32;
        glGetActiveUniform(shader_p, xx it, 128, *length, *size, *type, buffer.data);
        loc := glGetUniformLocation(shader_p, buffer.data);
        
        uniform_name := cast(string) buffer;
        uniform_name.count = c_style_strlen(buffer.data);
        
        hash_index := djb2_hash(uniform_name) % UNIFORM_MAP_SIZE;
        assert(shader.hash_map[hash_index] == -1);
        
        shader.hash_map[hash_index] = shader.uniforms.count;
        
        array_add(*shader.uniforms, loc);
    }
    
    return shader;
}

#scope_file

#import "Hash";
#import "Print_Vars";

UNIFORM_MAP_SIZE :: 2048;

shader_arena: Arena;
shaders: Typed_Arena(Shader);
null_shader: Shader;

#scope_export

Shader_Type :: enum {
    COLOURED_MESH;
}

shader_coloured_mesh: *Shader;

init_shader_system :: () {
    shaders = create_typed_arena(Shader);
    shader_arena = create_arena();
    
    shader_coloured_mesh = create_shader("shader_coloured_mesh", .COLOURED_MESH, SHADER_COLOURED_MESH_TEXT);
}

prepare_coloured_mesh_shader :: (shader: *Shader) {
    uniform_index := glGetUniformBlockIndex (shader.id, "Skinning_Transforms");
	glUniformBlockBinding (shader.id, uniform_index, 0);
}

SHADER_COLOURED_MESH_TEXT :: #run sprint(#string HERE
                                         INOUT vec2 frag_tex_coord;
                                         INOUT vec4 frag_colour;
                                         INOUT vec3 frag_normal;
                                         
#if VERTEX_SHADER
                                         
                                         layout(location = 0) in vec3 vertex_position;
                                         layout(location = 1) in vec2 vertex_tex_coord;
                                         layout(location = 2) in vec3 vertex_normal;
                                         layout(location = 3) in ivec4 bone_ids;
                                         layout(location = 4) in vec3 bone_weights;
                                         
                                         const int MAX_BONES  = %1;
                                         const int MAX_WEIGHTS = %2;
                                         
                                         layout (std140) uniform Skinning_Transforms
                                         {
                                             mat4 skinning_transforms[MAX_BONES];
                                         };
                                         
                                         uniform mat4 transform_matrix;
                                         uniform mat4 view_matrix;
                                         uniform mat4 projection_matrix;
                                         uniform vec4 base_colour;
                                         
                                         vec4 snap_ps1(vec4 position) {
                                             const vec2 res = vec2(450, 450);
                                             
                                             vec3 snapped = position.xyz / position.w;
                                             snapped.x = floor(res.x * snapped.x) / res.x;
                                             snapped.y = floor(res.y * snapped.y) / res.y;
                                             snapped.xyz *= position.w;
                                             return vec4(snapped, position.w);
                                         }
                                         
                                         void main() {
                                             frag_tex_coord = vertex_tex_coord;
                                             frag_colour = base_colour;
                                             
                                             vec3 model_position = vec3(0);
                                             vec3 model_normal = vec3(0);
                                             
                                             if (bone_ids.x == -1) {
                                                 model_position = vertex_position;
                                                 model_normal = vertex_normal;
                                             }
                                             
                                             for (int i = 0; i < MAX_WEIGHTS && bone_ids[i] != -1; i += 1) {
                                                 int bone_id = bone_ids[i];
                                                 float weight = 0;
                                                 if (i == MAX_WEIGHTS - 1) {
                                                     weight = 1.0 - (bone_weights.x+bone_weights.y+bone_weights.z);
                                                 } else {
                                                     weight = bone_weights[i];
                                                 }
                                                 mat4 skinning_matrix = skinning_transforms[bone_id];
                                                 vec3 pose_position = (skinning_matrix * vec4(vertex_position, 1)).xyz;
                                                 model_position += pose_position * weight;
                                                 vec3 pose_normal = (skinning_matrix * vec4(vertex_normal, 1)).xyz;
                                                 model_normal += pose_normal * weight;
                                             }
                                             
                                             vec4 position = projection_matrix * view_matrix * transform_matrix * vec4(model_position, 1);
                                             
                                             gl_Position = snap_ps1(position);
                                             
                                             frag_normal = model_normal;
                                         }
                                         
#endif
                                         
#if FRAGMENT_SHADER
                                         
                                         out vec4 output_colour;
                                         
                                         void main() {
                                             output_colour = vec4(frag_normal, 1) * frag_colour;
                                         }
                                         
#endif
                                         HERE, MAX_BONES, MAX_WEIGHTS);