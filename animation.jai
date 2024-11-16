
Anim_Player :: struct {
    mesh: *Mesh;
    anim: *Animation;
    
    playing: bool;
    pose: Anim_Pose;
    
    speed := 0.01;
    fps := 30;
}

Anim_Pose :: struct {
    // the length of this array will be equal
    // to the number of bones in the skeleton
    model_space_transforms: [] Mat4;
    parent_model_space_transforms: [] Mat4;
    skinning_transforms: [] Mat4;
}

update_animation :: (player: *Anim_Player) {
    if !player.playing return;
    
    update_pose(player, *frame_arena, g_time, *player.pose);
}

update_pose :: (player: *Anim_Player, arena: *Arena, time: float, pose: *Anim_Pose) {
    mesh := player.mesh;
    anim := player.anim;
    
    time = fmod_cycling(time * player.speed * player.fps, xx anim.sample_count);
    frame_index := cast(int) time;
    lerp_t := time - frame_index;
    
    pose.parent_model_space_transforms = arena_push_n(arena, Mat4, xx anim.bone_count);
    pose.model_space_transforms = arena_push_n(arena, Mat4, xx anim.bone_count);
    pose.skinning_transforms = arena_push_n(arena, Mat4, xx anim.bone_count);
    
    arena_push_mark_defer(arena);
    
    positions := arena_push_n(arena, Vec3, xx anim.bone_count);
    rotations:= arena_push_n(arena, Quaternion, xx anim.bone_count);
    scales := arena_push_n(arena, Vec3, xx anim.bone_count);
    bones := arena_push_n(arena, *Bone, xx anim.bone_count);
    
    for anim.bone_names {
        i0 := ((it_index * anim.sample_count) + frame_index);
        i1 := (i0 + 1) % anim.sample_count;
        positions[it_index] = lerp(anim.positions[i0], anim.positions[i1], lerp_t);
        rotations[it_index] = slerp(anim.rotations[i0], anim.rotations[i1], lerp_t);
        scales[it_index] = lerp(anim.scales[i0], anim.scales[i1], lerp_t);
    }
    
    for anim.bone_names {
        bone := find_bone(player.mesh.skeleton, it);
        
        local_transform := mat4_translation(positions[it_index]) *
            mat4_scale(scales[it_index]) * mat4_rotation(rotations[it_index]);
        
        if bone.parent {
            pose.model_space_transforms[it_index] = pose.model_space_transforms[bone.parent.id] * local_transform;
            pose.parent_model_space_transforms[it_index] = pose.model_space_transforms[bone.parent.id];
        }
        else {
            pose.model_space_transforms[it_index] = local_transform;
            pose.parent_model_space_transforms[it_index] = mat4_identity();
        }
        
        pose.skinning_transforms[it_index] = pose.model_space_transforms[it_index] * bone.inverse_bind_transform;
    }
}

#scope_file

#import "Basic";