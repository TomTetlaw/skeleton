
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

set_shader_float :: (shader: *Shader, name: string, value: float) {
    loc := get_uniform_location(shader, name);
    if (loc == -1) return;
    
    glUniform1f(loc, value);
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
        
        write_entire_file(tprint("debug/%.shader_text", name), tprint("%\n%\n", shader, prefix));
        
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
    
    PREFIX_V :: #string HERE
#version 450 core
#define VERTEX_SHADER 1
#define FRAGMENT_SHADER 0
#define INOUT out
#define FLAT_INOUT flat out
        HERE;
    
    PREFIX_F :: #string HERE
#version 450 core
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
    TEXTURED;
    DEPTH_PASS;
    MESH_2D;
}

shader_coloured_mesh: *Shader;
shader_2d_textured: *Shader;
shader_depth_pass: *Shader;
shader_2d_mesh: *Shader;

init_shader_system :: () {
    shaders = create_typed_arena(Shader);
    shader_arena = create_arena();
    
    shader_coloured_mesh = create_shader("shader_coloured_mesh", .COLOURED_MESH, SHADER_COLOURED_MESH_TEXT);
    shader_2d_textured = create_shader("shader_2d_textured", .TEXTURED, SHADER_TEXTURED_TEXT);
    shader_2d_mesh = create_shader("shader_2d_mesh", .MESH_2D, SHADER_2D_MESH_TEXT);
    shader_depth_pass = create_shader("shader_depth_pass", .DEPTH_PASS, SHADER_DEPTH_PASS_TEXT);
    
    uniform_index := glGetUniformBlockIndex (shader_coloured_mesh.id, "Skinning_Transforms");
    glUniformBlockBinding (shader_coloured_mesh.id, uniform_index, 0);
}

prepare_coloured_mesh_shader :: (mesh: *Mesh, shader: *Shader) {
    set_shader_vec3(shader, "mesh_min_bounds", mesh.min_bounds);
    set_shader_vec3(shader, "mesh_max_bounds", mesh.max_bounds);
    set_shader_texture(shader, "shadow_map", 0);
    set_shader_texture(shader, "diffuse_map", 1);
    set_shader_texture(shader, "normal_map", 2);
    set_shader_texture(shader, "rmaoh_map", 3);
}

prepare_2d_textured_shader :: (shader: *Shader) {
    set_shader_texture(shader, "diffuse_map", 0);
}

SHADER_COLOURED_MESH_TEXT :: #run sprint(#string HERE
#if VERTEX_SHADER
                                         layout(location = 0) in vec3 vertex_position;
                                         layout(location = 1) in vec2 vertex_tex_coord;
                                         layout(location = 2) in vec4 vertex_tangent_normal;
                                         layout(location = 3) in ivec4 bone_ids;
                                         layout(location = 4) in vec3 bone_weights;
                                         
                                         %1
                                         
                                         const int MAX_BONES  = %2;
                                         const int MAX_WEIGHTS = %3;
                                         
                                         layout (std140) uniform Skinning_Transforms
                                         {
                                             mat4 skinning_transforms[MAX_BONES];
                                         };
                                         
                                         uniform mat4 transform_matrix;
                                         uniform mat4 view_matrix;
                                         uniform mat4 projection_matrix;
                                         uniform mat4 light_matrix;
                                         uniform vec4 base_colour;
                                         
                                         void main() {
                                             vec3 position = vertex_position;
                                             vec3 normal = unpack_normal(vertex_tangent_normal.xy);
                                             vec3 tangent = unpack_tangent(vertex_tangent_normal.zw);
                                             
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
                                             vec4 ndc_position = MVP * vec4(model_position, 1);
                                             
                                             gl_Position = ndc_position;// snap_ps1(MVP, ndc_position, mesh_min_bounds, mesh_max_bounds, screen_params.xy);
                                             
                                             vec4 world_position = transform_matrix * vec4(model_position, 1);
                                             frag_position = world_position.xyz;
                                             frag_light_space_position = light_matrix * vec4(model_position, 1);
                                             frag_normal = model_normal.xyz;
                                             frag_tangent = model_tangent.xyz;
                                             frag_tex_coord = vertex_tex_coord;
                                             frag_colour = base_colour;
                                         }
                                         
#endif
                                         
#if FRAGMENT_SHADER
                                         %1
                                         
                                         out vec4 output_colour;
                                         
                                         void main() {
                                             vec2 tex_coord = frag_tex_coord * material_scale;
                                             tex_coord = vec2(tex_coord.x, tex_coord.y);
                                             
                                             vec3 diffuse = pow(texture(diffuse_map, tex_coord).rgb, vec3(2.2));
                                             
                                             vec3 colour = diffuse * frag_colour.xyz;
                                             
                                             vec3 bitangent = cross(frag_normal, frag_tangent);
                                             mat3 TBN = mat3(frag_tangent, bitangent, frag_normal);
                                             vec3 normal = texture(normal_map, tex_coord).xyz * 2 - 1;
                                             normal = normalize(TBN * normal);
                                             normal = normalize(mix(frag_normal, normal, 0.5));
                                             
                                             vec4 rmaoh = texture(rmaoh_map, tex_coord);
                                             
                                             Material mat;
                                             mat.roughness = 1 * rmaoh.r;
                                             mat.metallic = 1 * rmaoh.g;
                                             mat.ambient_occlusion = 1 * rmaoh.b;
                                             
                                             vec3 light_colour = vec3(1.0, 1.0, 0.8);
                                             
                                             colour = lighting_directional(frag_light_space_position, frag_position, normal, colour, mat, camera_position, light_dir, light_colour);
                                             
                                             output_colour = vec4(colour, 1);
                                         }
                                         
#endif
                                         HERE, SHADER_SHARED_TEXT, MAX_BONES, MAX_WEIGHTS);

SHADER_TEXTURED_TEXT :: #run sprint(#string HERE
#if VERTEX_SHADER
                                    layout(location = 0) in vec3 vertex_position;
                                    layout(location = 1) in vec2 vertex_tex_coord;
                                    layout(location = 2) in vec4 vertex_tangent_normal;
                                    
                                    %1
                                    
                                    uniform mat4 transform_matrix;
                                    uniform mat4 projection_matrix;
                                    uniform vec4 base_colour;
                                    
                                    void main() {
                                        vec3 position = vertex_position;
                                        vec3 normal = unpack_normal(vertex_tangent_normal.xy);
                                        vec3 tangent = unpack_tangent(vertex_tangent_normal.zw);
                                        
                                        mat4 MVP = projection_matrix * transform_matrix;
                                        vec4 ndc_position = MVP * vec4(position, 1);
                                        
                                        gl_Position = ndc_position;
                                        frag_tex_coord = vertex_tex_coord;
                                        frag_colour = base_colour;
                                    }
                                    
#endif
                                    
#if FRAGMENT_SHADER
                                    %1
                                    
                                    out vec4 output_colour;
                                    
                                    void main() {
                                        output_colour = frag_colour * texture(diffuse_map, frag_tex_coord);
                                    }
                                    
#endif
                                    HERE, SHADER_SHARED_TEXT);

SHADER_2D_MESH_TEXT :: #run sprint(#string HERE
#if VERTEX_SHADER
                                   layout(location = 0) in vec3 vertex_position;
                                   layout(location = 1) in vec2 vertex_tex_coord;
                                   layout(location = 2) in vec4 vertex_tangent_normal;
                                   
                                   %1
                                   
                                   uniform mat4 transform_matrix;
                                   uniform mat4 projection_matrix;
                                   uniform vec4 base_colour;
                                   
                                   void main() {
                                       vec3 position = vertex_position;
                                       vec3 normal = unpack_normal(vertex_tangent_normal.xy);
                                       vec3 tangent = unpack_tangent(vertex_tangent_normal.zw);
                                       
                                       mat4 MVP = projection_matrix * transform_matrix;
                                       vec4 ndc_position = MVP * vec4(position, 1);
                                       
                                       gl_Position = ndc_position;
                                       frag_tex_coord = vertex_tex_coord;
                                       frag_colour = base_colour;
                                   }
                                   
#endif
                                   
#if FRAGMENT_SHADER
                                   %1
                                   
                                   out vec4 output_colour;
                                   
                                   void main() {
                                       output_colour = frag_colour;
                                   }
                                   
#endif
                                   HERE, SHADER_SHARED_TEXT);

SHADER_SHARED_TEXT :: #string HERE
INOUT vec2 frag_tex_coord;
INOUT vec4 frag_colour;
INOUT vec3 frag_position;
INOUT vec3 frag_normal;
INOUT vec3 frag_tangent;
INOUT vec4 frag_light_space_position;

uniform vec4 screen_params;
uniform vec3 camera_position;
uniform vec3 mesh_min_bounds;
uniform vec3 mesh_max_bounds;
uniform vec3 light_dir;

uniform sampler2D shadow_map;

uniform sampler2D diffuse_map;
uniform sampler2D normal_map;
uniform sampler2D rmaoh_map;
uniform float material_scale;

#define PI 3.14159265359

struct Material {
    float roughness;
    float metallic;
    float ambient_occlusion;
};

float distribution_ggx(vec3 N, vec3 H, float roughness) {
    float a2 = roughness * roughness * roughness * roughness;
    float NdotH = max (dot (N, H), 0.0);
    float denom = (NdotH * NdotH * (a2 - 1.0) + 1.0);
    return a2 / (PI * denom * denom);
}

float geometry_schlick_ggx(float NdotV, float roughness) {
    float r = (roughness + 1.0);
    float k = (r * r) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k);
}

float geometry_smith(vec3 N, vec3 V, vec3 L, float roughness) {
    return geometry_schlick_ggx(max (dot (N, L), 0.0), roughness) *
        geometry_schlick_ggx(max (dot (N, V), 0.0), roughness);
}

vec3 fresnel_schlick(float cos_theta, vec3 F0) {
    return F0 + (1.0 - F0) * pow(1.0 - cos_theta, 5.0);
}

float shadow_calculation(vec4 light_space_position, vec3 object_normal, vec3 light_dir)
{
    vec3 proj_coord = light_space_position.xyz / light_space_position.w;
    proj_coord = proj_coord * 0.5 + 0.5;
    float closest = texture(shadow_map, proj_coord.xy).r; 
    float current = proj_coord.z;
    float bias = max(0.005, 0.05 * (1.0 - dot(object_normal, light_dir)));
    float shadow = current - bias > closest  ? 1.0 : 0.3;
    return shadow;
}

vec3 lighting_directional(vec4 light_space_position, vec3 object_pos, vec3 object_normal, vec3 object_colour, Material material, vec3 camera_pos, vec3 light_dir, vec3 light_colour) {
    vec3 N = normalize(object_normal);
    vec3 V = normalize(camera_pos - object_pos);
    
    vec3 F0 = vec3(.04);
    F0 = mix(F0, object_colour, material.metallic);
    
    vec3 L = normalize(-light_dir);
    vec3 H = normalize(V + L);
    
    float NDF = distribution_ggx(N, H, material.roughness);
    float G = geometry_smith(N, V, L, material.roughness);
    vec3 F = fresnel_schlick(max(dot(H, V), 0.0), F0);
    
    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - material.metallic;
    
    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;
    
    float NdotL = max(dot(N, L), 0.0);
    vec3 Lo = (kD * object_colour / PI + specular) * light_colour * NdotL;
    
    float shadow = shadow_calculation(light_space_position, object_normal, light_dir);
    
    vec3 ambient = vec3(0.03) * object_colour * material.ambient_occlusion;
    vec3 colour = ambient + Lo * (1.0 - shadow);
    
    colour = colour / (colour + vec3(1.0));
    colour = pow(colour, vec3(1.0/2.2));
    
    return colour;
}
/*
vec3 lighting_point(vec4 light_space_position, vec3 object_pos, vec3 object_normal, vec3 object_colour, Material material, vec3 camera_pos, vec3 light_pos, vec3 light_colour) {
    vec3 N = normalize(object_normal);
    vec3 V = normalize(camera_pos - object_pos);
    
    vec3 F0 = vec3(.04);
    F0 = mix(F0, object_colour, material.metallic);
    
    vec3 L = normalize(light_pos - object_pos);
    vec3 H = normalize(V + L);
    float distance = length(light_pos - object_pos);
    float attenuation = 1.0 / (distance * distance);
    vec3 radiance = light_colour * attenuation;
    
    float NDF = distribution_ggx(N, H, material.roughness);
    float G = geometry_smith(N, V, L, material.roughness);
    vec3 F = fresnel_schlick(max(dot(H, V), 0.0), F0);
    
    vec3 kS = F;
    vec3 kD = vec3(1.0) - kS;
    kD *= 1.0 - material.metallic;
    
    vec3 numerator = NDF * G * F;
    float denominator = 4.0 * max(dot(N, V), 0.0) * max(dot(N, L), 0.0) + 0.0001;
    vec3 specular = numerator / denominator;
    
    float NdotL = max(dot(N, L), 0.0);
    vec3 Lo = (kD * object_colour / PI + specular) * radiance * NdotL;
    
    float shadow = shadow_calculation(light_space_position, object_normal, light_dir);
    
    vec3 ambient = vec3(0.03) * object_colour * material.ambient_occlusion;
    vec3 colour = ambient + Lo * (1.0 - shadow);
    
    colour = colour / (colour + vec3(1.0));
    colour = pow(colour, vec3(1.0/2.2));
    
    return colour;
}
*/

vec2 get_screen_size(mat4 MVP, vec3 min_bounds, vec3 max_bounds, vec2 viewport_size) {
    vec4 clip_min = MVP * vec4(min_bounds, 1);
    vec4 clip_max = MVP * vec4(max_bounds, 1);
    
    vec3 ndc_min = clip_min.xyz / clip_min.w;
    vec3 ndc_max = clip_max.xyz / clip_max.w;
    
    vec2 screen_min = (ndc_min.xy * 0.5 + 0.5) * viewport_size;
    vec2 screen_max = (ndc_max.xy * 0.5 + 0.5) * viewport_size;
    
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

SHADER_DEPTH_PASS_TEXT :: #run sprint(#string HERE
#if VERTEX_SHADER
                                      layout(location = 0) in vec3 vertex_position;
                                      layout(location = 3) in ivec4 bone_ids;
                                      layout(location = 4) in vec3 bone_weights;
                                      
                                      const int MAX_BONES  = %1;
                                      const int MAX_WEIGHTS = %2;
                                      
                                      layout (std140) uniform Skinning_Transforms
                                      {
                                          mat4 skinning_transforms[MAX_BONES];
                                      };
                                      
                                      uniform mat4 transform_matrix;
                                      uniform mat4 light_view;
                                      uniform mat4 light_projection;
                                      
                                      void main() {
                                          vec3 position = vertex_position;
                                          
                                          vec3 model_position = vec3(0);
                                          
                                          if (bone_ids.x == -1) {
                                              model_position = vertex_position;
                                          } else {
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
                                                  model_position += pose_position * weight;
                                              }
                                          }
                                          
                                          mat4 MVP = light_projection * light_view * transform_matrix;
                                          vec4 ndc_position = MVP * vec4(model_position, 1);
                                          
                                          gl_Position = ndc_position;
                                      }
                                      
#endif
                                      
#if FRAGMENT_SHADER
                                      
                                      void main () {
                                      }
                                      
#endif
                                      
                                      HERE, MAX_BONES, MAX_WEIGHTS);