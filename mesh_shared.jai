
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

Bone_Ids :: struct {
    a, b, c, d: s16;
}

Serialized_Animation :: struct {
    name: string;
    sample_count: int;
    bone_names: [..] string;
    positions: [..] Vec3;
    rotations: [..] Quaternion;
    scales: [..] Vec3;
}

#scope_file

#import "Math";