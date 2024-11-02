
Bone :: struct {
    id: int;
    name: string;
    local_transform: Mat4;
    model_space_transform: Mat4;
    parent: *Bone;
}

Skeleton :: struct {
    bones: [] Bone;
    bone_name_map: [] int;
}

Mesh :: struct {
    path: string;
    positions: [] Vec3;
    colours: [] Vec4;
    tex_coords: [] Vec2;
    normals: [] Vec3;
    indices: [] u32;
    weights: [] Vec3;
    bone_ids: [] Bone_Ids;
    skeleton: *Skeleton;
}

init_mesh_system :: () {
    meshes = create_typed_arena(Mesh);
    mesh_arena = create_arena();
}

load_mesh :: (path: string) -> *Mesh {
    for * meshes if equal(it.path, path) return it;
    
    file, success := file_open(path);
    defer if success file_close(*file);
    
    if !success return *null_mesh;
    
    header := file_read_mesh_header(*file, *mesh_arena);
    if !equal(header.magic, "MESH") {
        return *null_mesh;
    }
    
    positions := file_read_array(*file, *mesh_arena, Vec3, header.num_vertices);
    colours := file_read_array(*file, *mesh_arena, Vec4, header.num_vertices);
    tex_coords := file_read_array(*file, *mesh_arena, Vec2, header.num_vertices);
    normals := file_read_array(*file, *mesh_arena, Vec3, header.num_vertices);
    weights := file_read_array(*file, *mesh_arena, Vec3, header.num_vertices);
    bone_ids := file_read_array(*file, *mesh_arena, Bone_Ids, header.num_vertices);
    indices := file_read_array(*file, *mesh_arena, u32, header.num_indices);
    
    serialized_bones := file_read_bones(*file, *mesh_arena, header.num_bones);
    bones := arena_push_n(*mesh_arena, Bone, xx header.num_bones);
    bone_name_map := arena_push_n(*mesh_arena, int, 512);
    
    for serialized_bones {
        bone: Bone;
        bone.id = it.id;
        bone.name = it.name;
        bone.local_transform = it.transform;
        
        if it.parent == -1 {
            bone.parent = null;
            bone.model_space_transform = it.transform;
        } else {
            bone.parent = *bones[it.parent];
            bone.model_space_transform = bone.parent.model_space_transform * it.transform;
        }
        
        hash := get_hash(it.name) % 512;
        bone_name_map[hash] = it_index;
        bones[it_index] = bone;
    }
    
    skeleton := arena_push(*mesh_arena, Skeleton);
    skeleton.bones = bones;
    skeleton.bone_name_map = bone_name_map;
    
    mesh := arena_push(*meshes);
    mesh.path = path;
    mesh.positions = positions;
    mesh.colours = colours;
    mesh.tex_coords = tex_coords;
    mesh.normals = normals;
    mesh.indices = indices;
    mesh.weights = weights;
    mesh.bone_ids = bone_ids;
    mesh.skeleton = skeleton;
    
    return mesh;
}

#scope_file

#import "Basic";
#import "Sort";

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

file_read_mesh_header :: (file: *File, arena: *Arena) -> Mesh_Header {
    header: Mesh_Header;
    header.magic = file_read_string(file, arena);
    file_read(file, *header.num_vertices, size_of(int));
    file_read(file, *header.num_indices, size_of(int));
    file_read(file, *header.num_bones, size_of(int));
    return header;
}

null_mesh: Mesh;

meshes: Typed_Arena(Mesh);
mesh_arena: Arena;