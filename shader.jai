
Shader :: struct {
    id: u32;
    uniforms: [..] s32;
    hash_map: [] int;
    type: Shader_Type;
}

get_uniform_location :: (shader: *Shader, name: string) -> s32 {
    hash_index := djb2_hash(name) % UNIFORM_MAP_SIZE;
    index := shader.hash_map[hash_index];
    if index == -1 return -1;
    
    loc := shader.uniforms[index];
    return loc;
}

set_shader_int :: (shader: *Shader, name: string, value: s32) {
    loc := get_uniform_location(shader, name);
    if (loc == -1) return;
    
    glUniform1i(loc, value);
}

set_shader_vec2 :: (shader: *Shader, name: string, value: Vec2) {
    loc := get_uniform_location(shader, name);
    if (loc == -1) return;
    
    glUniform2f(loc, value.x, value.y);
}

set_shader_vec3 :: (shader: *Shader, name: string, value: Vec3) {
    loc := get_uniform_location(shader, name);
    if (loc == -1) return;
    
    glUniform3f(loc, value.x, value.y, value.z);
}

set_shader_vec4 :: (shader: *Shader, name: string, value: Vec4) {
    loc := get_uniform_location(shader, name);
    if (loc == -1) return;
    
    glUniform4f(loc, value.x, value.y, value.z, value.w);
}

set_shader_mat4 :: (shader: *Shader, name: string, value: Mat4) {
    loc := get_uniform_location(shader, name);
    if (loc == -1) return;
    
    glUniformMatrix4fv(loc, 1, GL_TRUE, cast (*float) *value);
}

set_shader_texture :: (shader: *Shader, name: string, unit: u32) {
    loc := get_uniform_location(shader, name);
    if (loc == -1) return;
    
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
#define FLAT_INOUT flat out
        HERE;
    
    PREFIX_F := #string HERE
#version 330 core
#define VERTEX_SHADER 0
#define FRAGMENT_SHADER 1
#define INOUT in
#define FLAT_INOUT flat in
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
    
    uniform_index := glGetUniformBlockIndex (shader_coloured_mesh.id, "Skinning_Transforms");
	glUniformBlockBinding (shader_coloured_mesh.id, uniform_index, 0);
}

prepare_coloured_mesh_shader :: (mesh: *Mesh, shader: *Shader) {
    set_shader_vec3(shader, "mesh_min_bounds", mesh.min_bounds);
    set_shader_vec3(shader, "mesh_max_bounds", mesh.max_bounds);
}

SHADER_SHARED_TEXT :: #string HERE
INOUT vec2 frag_tex_coord;
INOUT vec4 frag_colour;
INOUT vec3 frag_position;
INOUT vec3 frag_normal;

uniform vec4 screen_params;
uniform vec3 camera_position;
uniform vec3 mesh_min_bounds;
uniform vec3 mesh_max_bounds;

vec3 ambient_lighting(vec3 light_dir, vec3 light_colour, vec3 camera_pos, vec3 object_pos, vec3 object_colour, vec3 object_normal, vec3 params) {
    vec3 normal = normalize(object_normal);
    vec3 dir = normalize(-light_dir);
    vec3 view = normalize(camera_pos - object_pos);
    
    vec3 ambient = params.x * light_colour;
    
    float diff = max(dot(normal, dir), 0.0);
    vec3 diffuse = diff * light_colour;
    
    vec3 half_dir = normalize(dir + view);
    float spec = pow(max(dot(object_normal, half_dir), 0.0), params.z);
    vec3 specular = params.y * spec * light_colour;
    
    vec3 lighting = ambient + diffuse + specular;
    vec3 result = lighting * object_colour;
    
    return result;
}

vec2 get_screen_size(mat4 MVP, vec3 min_bounds, vec3 max_bounds, vec2 screen_size) {
    vec4 clip_min = MVP * vec4(min_bounds, 1);
    vec4 clip_max = MVP * vec4(max_bounds, 1);
    
    vec3 ndc_min = clip_min.xyz / clip_min.w;
    vec3 ndc_max = clip_max.xyz / clip_max.w;
    
    vec2 screen_min = (ndc_min.xy * 0.5 + 0.5) * screen_size;
    vec2 screen_max = (ndc_max.xy * 0.5 + 0.5) * screen_size;
    
    return screen_max - screen_min;
}

vec4 snap_ps1(mat4 MVP, vec4 position, vec3 min_bounds, vec3 max_bounds, vec2 screen_size) {
    vec2 res = vec2(50);
    
    vec2 snapped = position.xy / position.w;
    snapped.x = floor(snapped.x * res.x) / res.x;
    snapped.y = floor(snapped.y * res.y) / res.y;
    snapped *= position.w;
    return vec4(snapped, position.zw);
}

vec3 unpack_normal(vec2 normal) {
    float z = sqrt(1.0 - dot(normal, normal));
    return vec3(normal.xy, z);
}

vec3 unpack_tangent(vec2 tangent) {
    float z = sqrt(1.0 - dot(tangent, tangent));
    return vec3(tangent.xy, z);
}

HERE

SHADER_COLOURED_MESH_TEXT :: #run sprint(#string HERE
                                         %1
#if VERTEX_SHADER
                                         layout(location = 0) in vec3 vertex_position;
                                         layout(location = 1) in vec2 vertex_tex_coord;
                                         layout(location = 2) in vec4 vertex_tangent_normal;
                                         layout(location = 3) in ivec4 bone_ids;
                                         layout(location = 4) in vec3 bone_weights;
                                         
                                         const int MAX_BONES  = %2;
                                         const int MAX_WEIGHTS = %3;
                                         
                                         layout (std140) uniform Skinning_Transforms
                                         {
                                             mat4 skinning_transforms[MAX_BONES];
                                         };
                                         
                                         uniform mat4 transform_matrix;
                                         uniform mat4 view_matrix;
                                         uniform mat4 projection_matrix;
                                         uniform vec4 base_colour;
                                         
                                         void main() {
                                             vec3 position = vertex_position;
                                             vec3 normal = unpack_normal(vertex_tangent_normal.xy);
                                             vec3 tangent = unpack_tangent(vertex_tangent_normal.zw);
                                             vec3 bitangent = cross(normal, tangent) * sign(dot(cross(normal, tangent), bitangent)));
                                             mat3 TBN = mat3(tangent, bitangent, normal);
                                             vec3 bump_normal = texture2D(bump_map, vertex_tex_coord) * 2 + 1;
                                             bump_normal = TBN * bump_normal;
                                             
                                             vec3 model_position = vec3(0);
                                             vec3 model_normal = vec3(0);
                                             vec3 model_tangent = vec3(0);
                                             
                                             if (bone_ids.x == -1) {
                                                 model_position = vertex_position;
                                                 model_normal = normal;
                                                 model_tangent = tangent;
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
                                                 
                                                 vec3 pose_position = (skinning_matrix * vec4(position, 1)).xyz;
                                                 vec3 pose_normal = (skinning_matrix * vec4(normal, 1)).xyz;
                                                 vec3 pose_tangent = (skinning_matrix * vec4(tangent, 1)).xyz;
                                                 
                                                 model_position += pose_position * weight;
                                                 model_normal += pose_normal * weight;
                                                 model_tangent += pose_tangent * weight;
                                             }
                                             
                                             mat4 MVP = projection_matrix * view_matrix * transform_matrix;
                                             vec4 position = MVP * vec4(model_position, 1);
                                             
                                             gl_Position = position;// snap_ps1(MVP, position, mesh_min_bounds, mesh_max_bounds, screen_params.xy);
                                             
                                             vec4 world_position = vec4(model_position, 1) * transform_matrix;
                                             frag_position = world_position.xyz;
                                             frag_normal = (vec4(model_normal, 1) * transform_matrix).xyz;
                                             frag_tex_coord = vertex_tex_coord;
                                             frag_colour = base_colour;
                                         }
                                         
#endif
                                         
#if FRAGMENT_SHADER
                                         
                                         out vec4 output_colour;
                                         
                                         uniform sampler2D base_texture;
                                         
                                         void main() {
                                             vec3 light_dir =  vec3(0, -1, 0);
                                             vec3 light_colour = vec3(1.0, 1.0, 0.9);
                                             vec3 params = vec3(0.1, 0.0, 0.0);
                                             vec2 tex_coord = vec2(frag_tex_coord.x, frag_tex_coord.y);
                                             vec3 colour = texture(base_texture, tex_coord).xyz * frag_colour.xyz;
                                             
                                             //colour = ambient_lighting(light_dir, light_colour, camera_position, frag_position, colour, frag_normal, params);
                                             
                                             colour *= max(dot(normalize(frag_normal), normalize(light_dir)), 0);
                                             
                                             output_colour = vec4(colour, 1);
                                         }
                                         
#endif
                                         HERE, SHADER_SHARED_TEXT, MAX_BONES, MAX_WEIGHTS);