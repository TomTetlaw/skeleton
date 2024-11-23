
Bone_Ids :: struct {
    a, b, c, d: s16;
}

Bone :: struct {
    id: int;
    name: string;
    local_bind_transform: Mat4;
    inverse_bind_transform: Mat4;
    parent: *Bone;
}

Skeleton :: struct {
    bones: [] Bone;
    bone_name_map: [] int;
}

Mesh :: struct {
    path: string;
    positions: [] Vec3;
    tex_coords: [] Vec2;
    tangents_normals: [] Vec4;
    indices: [] u32;
    
    weights: [] Vec3;
    bone_ids: [] Bone_Ids;
    skeleton: *Skeleton;
    
    min_bounds: Vec3;
    max_bounds: Vec3;
}

Animation :: struct {
    path: string;
    name: string;
    bone_names: [] string;
    bone_count: int;
    sample_count: int;
    positions: [] Vec3;
    rotations: [] Quaternion;
    scales: [] Vec3;
}

init_mesh_system :: () {
    meshes = create_typed_arena(Mesh);
    mesh_arena = create_arena();
    
    animations = create_typed_arena(Animation);
    animation_arena = create_arena();
}

load_mesh :: (path: string) -> *Mesh {
    for * meshes if equal(it.path, path) return it;
    
    file, success := file_open(path);
    defer if success file_close(*file);
    
    if !success return *null_mesh;
    
    header := file_read_mesh_header(*file);
    if !equal(header.magic, "MESH") {
        print("Failed to load: % is not a mesh file!", path);
        return *null_mesh;
    }
    
    positions := file_read_array(*file, *mesh_arena, Vec3, header.num_vertices);
    tex_coords := file_read_array(*file, *mesh_arena, Vec2, header.num_vertices);
    tangents_normals := file_read_array(*file, *mesh_arena, Vec4, header.num_vertices);
    weights := file_read_array(*file, *mesh_arena, Vec3, header.num_vertices);
    bone_ids := file_read_array(*file, *mesh_arena, Bone_Ids, header.num_vertices);
    indices := file_read_array(*file, *mesh_arena, u32, header.num_indices);
    serialized_bones := file_read_bones(*file, *mesh_arena, header.num_bones);
    
    min_bounds := Vec3.{FLOAT32_MAX, FLOAT32_MAX, FLOAT32_MAX};
    max_bounds := Vec3.{FLOAT32_MIN, FLOAT32_MIN, FLOAT32_MIN};
    
    for positions {
        min_bounds.x = min(min_bounds.x, it.x);
        min_bounds.y = min(min_bounds.y, it.y);
        min_bounds.z = min(min_bounds.z, it.z);
        
        max_bounds.x = max(max_bounds.x, it.x);
        max_bounds.y = max(max_bounds.y, it.y);
        max_bounds.z = max(max_bounds.z, it.z);
    }
    
    bones := arena_push_n(*mesh_arena, Bone, xx header.num_bones);
    bone_name_map := arena_push_n(*mesh_arena, int, BONE_NAME_MAP_SIZE);
    
    for * bone_name_map {
        it.* = -1;
    }
    
    for serialized_bones {
        bone: Bone;
        bone.id = it.id;
        bone.name = it.name;
        
        bone.local_bind_transform = it.transform;
        
        if it.parent == -1 {
            bone.parent = null;
            bone.inverse_bind_transform = bone.local_bind_transform;
        } else {
            bone.parent = *bones[it.parent];
            bone.inverse_bind_transform = bone.parent.inverse_bind_transform * bone.local_bind_transform;
        }
        
        hash := djb2_hash(it.name) % BONE_NAME_MAP_SIZE;
        assert(bone_name_map[hash] == -1);
        
        bone_name_map[hash] = it_index;
        
        bones[it_index] = bone;
    }
    
    for * bones {
        it.inverse_bind_transform = mat4_inverse(it.inverse_bind_transform);
    }
    
    skeleton := arena_push(*mesh_arena, Skeleton);
    skeleton.bones = bones;
    skeleton.bone_name_map = bone_name_map;
    
    mesh := arena_push(*meshes);
    mesh.path = path;
    mesh.positions = positions;
    mesh.tex_coords = tex_coords;
    mesh.tangents_normals = tangents_normals;
    mesh.indices = indices;
    mesh.weights = weights;
    mesh.bone_ids = bone_ids;
    mesh.skeleton = skeleton;
    mesh.min_bounds = min_bounds;
    mesh.max_bounds = max_bounds;
    
    return mesh;
}

find_bone :: (skeleton: *Skeleton, name: string) -> *Bone {
    hash := djb2_hash(name) % BONE_NAME_MAP_SIZE;
    return *skeleton.bones[skeleton.bone_name_map[hash]];
}

load_animation :: (path: string) -> *Animation {
    for * animations if equal(it.path, path) return it;
    
    file, success := file_open(path);
    defer if success file_close(*file);
    
    if !success return *null_animation;
    
    header := file_read_anim_header(*file);
    if !equal(header.magic, "ANIM") {
        print("Failed to load: % is not an anim file!", path);
        return *null_animation;
    }
    
    name := file_read_string(*file, *animation_arena);
    
    bone_names := arena_push_n(*animation_arena, string, xx header.bone_count);
    for 0..header.bone_count-1 {
        bone_names[it] = file_read_string(*file, *animation_arena);
    }
    
    positions := file_read_array(*file, *animation_arena, Vec3, header.bone_count * header.sample_count);
    rotations := file_read_array(*file, *animation_arena, Quaternion, header.bone_count * header.sample_count);
    scales := file_read_array(*file, *animation_arena, Vec3, header.bone_count * header.sample_count);
    
    anim := arena_push(*animations);
    anim.name = name;
    anim.path = path;
    anim.sample_count = header.sample_count;
    anim.bone_count = header.bone_count;
    anim.bone_names = bone_names;
    anim.positions = positions;
    anim.rotations = rotations;
    anim.scales = scales;
    
    return anim;
}

#scope_file

#import "Basic";
#import "Sort";
#import "File";

BONE_NAME_MAP_SIZE :: 2048;

Mesh_Header :: struct {
    magic: string;
    num_vertices: int;
    num_indices: int;
    num_bones: int;
}

Anim_Header :: struct {
    magic: string;
    sample_count: int;
    bone_count: int;
}

Serialized_Bone :: struct {
    id: s16;
    parent: s16;
    name: string;
    transform: Mat4;
}

Serialized_Animation :: struct {
    name: string;
    sample_count: int;
    bone_names: [..] string;
    positions: [..] Vec3;
    rotations: [..] Quaternion;
    scales: [..] Vec3;
}

file_read_bones :: (file: *File, arena: *Arena, count: int) -> [] Serialized_Bone {
    bones := arena_push_n(arena, Serialized_Bone, xx count);
    
    for 0..count-1 {
        id: s16;
        file_read(file, *id, size_of(s16));
        
        parent: s16;
        file_read(file, *parent, size_of(s16));
        
        name := file_read_string(file, arena);
        
        transform: Mat4;
        file_read(file, transform.floats.data, size_of(float) * 16);
        
        bones[it] = Serialized_Bone.{id, parent, name, transform};
    }
    
    return bones;
}

file_read_mesh_header :: (file: *File) -> Mesh_Header {
    header: Mesh_Header;
    header.magic = file_read_string(file, *mesh_arena);
    file_read(file, *header.num_vertices, size_of(int));
    file_read(file, *header.num_indices, size_of(int));
    file_read(file, *header.num_bones, size_of(int));
    return header;
}

file_read_anim_header :: (file: *File) -> Anim_Header {
    header: Anim_Header;
    header.magic = file_read_string(file, *animation_arena);
    file_read(file, *header.sample_count, size_of(int));
    file_read(file, *header.bone_count, size_of(int));
    return header;
}

null_mesh: Mesh;
null_animation: Animation;

meshes: Typed_Arena(Mesh);
mesh_arena: Arena;

animations: Typed_Arena(Animation);
animation_arena: Arena;