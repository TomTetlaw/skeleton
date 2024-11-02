
Mesh_Header :: struct {
    magic: string;
    num_vertices: int;
    num_indices: int;
    num_bones: int;
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
    channels: [..] Serialized_Channel;
}

Serialized_Channel :: struct {
    bone_id: s16;
    frames: [..] Serialized_Keyframe;
}

Serialized_Keyframe :: struct {
    position: Vec3;
    rotation: Quaternion;
    scale: Vec3;
}

#scope_file

#import "Math";