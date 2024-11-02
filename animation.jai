
Anim_Player :: struct {
    mesh: *Mesh;
    anim: *Animation;
    
    speed := 1.0;
    fps := 30.0;
}

Anim_Pose :: struct {
    // the length of this array will be equal
    // to the number of bones in the skeleton
    transforms: [] Mat4;
}

make_pose :: (player: *Anim_Player, arena: *Arena, time: float) -> Anim_Pose {
    mesh := player.mesh;
    anim := player.anim;
    
    time = fmod_cycling(time * player.speed * player.fps, xx anim.sample_count);
    frame_index := cast(int) time;
    lerp_t := time - frame_index;
    
    transforms := arena_push_n(arena, Mat4, xx anim.bone_count);
    
    arena_push_mark_defer(arena);
    
    positions := arena_push_n(arena, Vec3, xx anim.bone_count);
    rotations:= arena_push_n(arena, Quaternion, xx anim.bone_count);
    scales := arena_push_n(arena, Vec3, xx anim.bone_count);
    bones := arena_push_n(arena, *Bone, xx anim.bone_count);
    
    for 0..anim.bone_count-1 {
        bone := find_bone(mesh.skeleton, anim.bone_names[it]);
        bones[it] = bone;
    }
    
    for 0..anim.bone_count-1 {
        index := (it * anim.sample_count) + frame_index;
        positions[it] = lerp(anim.positions[index], anim.positions[index + 1], lerp_t);
        rotations[it] = slerp(anim.rotations[index], anim.rotations[index + 1], lerp_t);
        scales[it] = lerp(anim.scales[index], anim.scales[index + 1], lerp_t);
    }
    
    for bones {
        local_transform := mat4_translation(positions[it_index]) *
            mat4_scale(scales[it_index]) * mat4_rotation(rotations[it_index]);
        
        parent := it.parent;
        if parent transforms[it_index] = transforms[parent.id] * local_transform;
        else transforms[it_index] = local_transform;
    }
    
    for * transforms {
        bone := bones[it_index];
        <<it = it * bone.inverse_transform;
    }
    
    pose: Anim_Pose;
    pose.transforms = transforms;
    return pose;
}

#scope_file

#import "Basic";