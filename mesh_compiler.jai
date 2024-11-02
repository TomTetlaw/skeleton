
compile_mesh :: (path: string, dest: string) {
    print("compiling mesh % -> %\n", path, dest);
    
    scene := aiImportFile(path.data, MESH_PREPROCESS_FLAGS);
    if !scene {
        print("Failed to compile mesh %\n", path);
        return;
    }
    
    Node :: struct {
        id: int;
        transform: Mat4;
        parent: *Node;
    }
    
    build_bone_name_list :: (scene: *aiScene) -> [..] string {
        names: [..] string;
        
        num_meshes := cast(int) scene.mNumMeshes;
        for m: 0..num_meshes-1 {
            mesh := scene.mMeshes[m];
            num_bones := cast(int) mesh.mNumBones;
            for b: 0..num_bones-1 {
                new_bone := mesh.mBones[b];
                array_add_if_unique(*names, to_string(new_bone.mName));
            }
        }
        
        return names;
    }
    
    build_node_list :: (scene: *aiScene) -> Table(string, Node), Table(int, Mat4) {
        process_node :: (name_list: *[..] string, node: *aiNode, next_id: *int, node_name_map: *Table, mesh_transform_map: *Table) {
            name := to_string(node.mName);
            transform := to_mat4(node.mTransformation);
            
            num_meshes := cast(int) node.mNumMeshes;
            for m: 0..num_meshes-1 {
                mesh_index := node.mMeshes[m];
                if !table_contains(mesh_transform_map, mesh_index) {
                    table_add(mesh_transform_map, mesh_index, transform);
                }
            }
            
            is_bone_node := array_find(<<name_list, name);
            if (num_meshes == 0 && is_bone_node) {
                if !table_contains(node_name_map, name) {
                    n: Node;
                    n.id = <<next_id;
                    n.transform = transform;
                    <<next_id += 1;
                    table_add(node_name_map, name, n);
                }
            }
            
            num_children := cast(int) node.mNumChildren;
            for 0..num_children-1 {
                process_node(name_list, node.mChildren[it], next_id, node_name_map, mesh_transform_map);
            }
        }
        
        find_parents :: (node: *aiNode, node_name_map: *Table) {
            name := to_string(node.mName);
            n := table_find_pointer(node_name_map, name);
            if n && node.mParent {
                parent_name := to_string(node.mParent.mName);
                p := table_find_pointer(node_name_map, parent_name);
                if p n.parent = p;
            }
            
            num_children := cast(int) node.mNumChildren;
            for 0..num_children-1 {
                find_parents(node.mChildren[it], node_name_map);
            }
        }
        
        initial_id := 0;
        node_name_map: Table(string, Node);
        mesh_transform_map: Table(int, Mat4);
        bone_name_list := build_bone_name_list(scene);
        process_node(*bone_name_list, scene.mRootNode, *initial_id, *node_name_map, *mesh_transform_map);
        find_parents(scene.mRootNode, *node_name_map);
        
        return node_name_map, mesh_transform_map;
    }
    
    build_bone_list :: (scene: *aiScene, node_name_map: *Table) -> Table(string, Serialized_Bone), Table(s16, string) {
        bone_name_map: Table(string, Serialized_Bone);
        bone_id_map: Table(s16, string);
        
        num_meshes := cast(int) scene.mNumMeshes;
        for m: 0..num_meshes-1 {
            mesh := scene.mMeshes[m];
            num_bones := cast(int) mesh.mNumBones;
            for b: 0..num_bones-1 {
                new_bone := mesh.mBones[b];
                
                bone, found := table_find(*bone_name_map, to_string(new_bone.mName));
                if !found {
                    n := table_find_pointer(node_name_map, to_string(new_bone.mName));
                    bone: Serialized_Bone;
                    bone.id = xx n.id;
                    if n.parent bone.parent = xx n.parent.id;
                    else bone.parent = -1;
                    bone.name = to_string(new_bone.mName);
                    bone.transform = n.transform;
                    table_add(*bone_name_map, bone.name, bone);
                    table_add(*bone_id_map, bone.id, bone.name);
                }
            }
        }
        
        return bone_name_map, bone_id_map;
    }
    
    node_name_map, mesh_transform_map := build_node_list(scene);
    bone_name_map, bone_id_map  := build_bone_list(scene, *node_name_map);
    
    print_heirarchy :: (scene: *aiScene, node: *aiNode, spaces := 0) {
        node_transform := to_mat4(node.mTransformation);
        print_spaces(spaces);
        print("node: % [%, %, %]\n", to_string(node.mName), node_transform._03, node_transform._13, node_transform._23);
        
        num_meshes := cast(int) node.mNumMeshes;
        for 0..num_meshes-1 {
            mesh_index := node.mMeshes[it];
            mesh := scene.mMeshes[mesh_index];
            print_spaces(spaces + 1);
            print("mesh: %\n", to_string(mesh.mName));
            
            num_bones := mesh.mNumBones;
            for b: 0..num_bones-1 {
                bone := mesh.mBones[b];
                bone_offset := to_mat4(bone.mOffsetMatrix);
                print_spaces(spaces + 2);
                print("bone: % [%, %, %]\n", to_string(bone.mName), bone_offset._03, bone_offset._13, bone_offset._23);
            }
        }
        
        num_children := cast(int) node.mNumChildren;
        for 0..num_children-1 {
            print_heirarchy(scene, node.mChildren[it], spaces + 1);
        }
    }
    
    // print_heirarchy(scene, scene.mRootNode);
    
    positions: [..] Vec3;
    colours: [..] Vec4;
    tex_coords: [..] Vec2;
    normals: [..] Vec3;
    indices: [..] u32;
    weights: [..] Vec3;
    bone_ids: [..] Bone_Ids;
    
    num_meshes := cast(int) scene.mNumMeshes;
    
    index_base := 0;
    
    total_vertex_count := 0;
    
    for mesh_index: 0..num_meshes-1 {
        mesh := scene.mMeshes[mesh_index];
        vertex_count := mesh.mNumVertices;
        total_vertex_count += vertex_count;
        
        face_count := cast(int) mesh.mNumFaces;
        
        transform, found := table_find(*mesh_transform_map, mesh_index);
        if !found transform = mat4_identity();
        
        section_positions := NewArray(Vec3, vertex_count);
        section_colours := NewArray(Vec4, vertex_count);
        section_tex_coords := NewArray(Vec2, vertex_count);
        section_normals := NewArray(Vec3, vertex_count);
        section_indices := NewArray(u32, face_count * 3);
        section_weights := NewArray(Vec3, vertex_count);
        section_bone_ids := NewArray(Bone_Ids, vertex_count);
        
        for 0..vertex_count-1 {
            section_bone_ids[it] = .{-1, -1, -1, -1};
        }
        
        for face_index: 0..face_count-1 {
            face := mesh.mFaces[face_index];
            i0 := face.mIndices[0];
            i1 := face.mIndices[1];
            i2 := face.mIndices[2];
            
            section_positions[i0] = (transform * append(to_vec3(mesh.mVertices[i0]), 1)).xyz;
            section_positions[i1] = (transform * append(to_vec3(mesh.mVertices[i1]), 1)).xyz;
            section_positions[i2] = (transform * append(to_vec3(mesh.mVertices[i2]), 1)).xyz;
            
            if mesh.mColors[0] {
                section_colours[i0] = to_vec4(mesh.mColors[0][i0]);
                section_colours[i1] = to_vec4(mesh.mColors[0][i1]);
                section_colours[i2] = to_vec4(mesh.mColors[0][i2]);
            } else {
                section_colours[i0] = .{1, 1, 1, 1};
                section_colours[i1] = .{1, 1, 1, 1};
                section_colours[i2] = .{1, 1, 1, 1};
            }
            
            section_normals[i0] = to_vec3(mesh.mNormals[i0]);
            section_normals[i1] = to_vec3(mesh.mNormals[i1]);
            section_normals[i2] = to_vec3(mesh.mNormals[i2]);
            
            if mesh.mTextureCoords[0] {
                section_tex_coords[i0] = to_vec2(mesh.mTextureCoords[0][i0]);
                section_tex_coords[i1] = to_vec2(mesh.mTextureCoords[0][i1]);
                section_tex_coords[i2] = to_vec2(mesh.mTextureCoords[0][i2]);
            } else {
                section_tex_coords[i0] = per_triangle_uv(section_positions[i0], section_positions[i0], section_positions[i1], section_positions[i2]);
                section_tex_coords[i1] = per_triangle_uv(section_positions[i1], section_positions[i0], section_positions[i1], section_positions[i2]);
                section_tex_coords[i2] = per_triangle_uv(section_positions[i2], section_positions[i0], section_positions[i1], section_positions[i2]);
            }
            
            section_indices[face_index * 3 + 0] = xx index_base + i0;
            section_indices[face_index * 3 + 1] = xx index_base + i1;
            section_indices[face_index * 3 + 2] = xx index_base + i2;
        }
        
        array_add(*positions, ..section_positions);
        array_add(*colours, ..section_colours);
        array_add(*tex_coords, ..section_tex_coords);
        array_add(*normals, ..section_normals);
        array_add(*indices, ..section_indices);
        
        index_base += vertex_count;
        
        num_bones := cast(int) mesh.mNumBones;
        
        for bone_index: 0..num_bones-1 {
            new_bone := mesh.mBones[bone_index];
            
            bone, found := table_find(*bone_name_map, to_string(new_bone.mName));
            if !found continue;
            
            num_weights := cast(int) new_bone.mNumWeights;
            for weight_index: 0..num_weights-1 {
                weight := new_bone.mWeights[weight_index];
                
                if (section_bone_ids[weight.mVertexId].a < 0) {
                    section_weights[weight.mVertexId].x = weight.mWeight;
                    section_bone_ids[weight.mVertexId].a = bone.id;
                } else if (section_bone_ids[weight.mVertexId].b < 0) {
                    section_weights[weight.mVertexId].y = weight.mWeight;
                    section_bone_ids[weight.mVertexId].b = bone.id;
                } else if (section_bone_ids[weight.mVertexId].c < 0) {
                    section_weights[weight.mVertexId].z = weight.mWeight;
                    section_bone_ids[weight.mVertexId].c = bone.id;
                } else {
                    section_bone_ids[weight.mVertexId].d = bone.id;
                }
            }
        }
        
        array_add(*weights, ..section_weights);
        array_add(*bone_ids, ..section_bone_ids);
    }
    
    final_bones: [..] Serialized_Bone;
    for bone_name_map {
        parent_name, found := table_find(*bone_id_map, it.parent);
        
        parent: *Serialized_Bone;
        if found parent := table_find_pointer(*bone_name_map, parent_name);
        
        local_transform: Mat4 = ---;
        if parent local_transform = mat4_inverse(parent.transform) * it.transform;
        else local_transform = it.transform;
        
        bone: Serialized_Bone;
        bone.id = it.id;
        bone.parent = it.parent;
        bone.name = it.name;
        bone.transform = local_transform;
        
        array_add(*final_bones, bone);
    }
    
    bubble_sort(final_bones, (a, b) => cast(s64) (a.id - b.id));
    
    animations: [..] Serialized_Animation;
    num_animations := cast(int) scene.mNumAnimations;
    for anim_index: 0..num_animations-1 {
        animation := scene.mAnimations[anim_index];
        
        a: Serialized_Animation;
        a.name = to_string(animation.mName);
        
        sample_count := 0;
        num_channels := cast(int) animation.mNumChannels;
        for channel_index: 0..num_channels-1 {
            channel := animation.mChannels[channel_index];
            num_positions := cast(int) channel.mNumPositionKeys;
            num_rotations := cast(int) channel.mNumRotationKeys;
            num_scales := cast(int) channel.mNumScalingKeys;
            samples := max(num_positions, max(num_rotations, num_scales));
            sample_count = max(sample_count, samples);
        }
        
        a.sample_count = sample_count;
        
        for channel_index: 0..num_channels-1 {
            channel := animation.mChannels[channel_index];
            
            c: Serialized_Channel;
            
            bone := table_find_pointer(*bone_name_map, to_string(channel.mNodeName));
            if !bone {
                print("Animation channel % referenced a non-existant bone!\n", to_string(channel.mNodeName));
                continue;
            }
            
            c.bone_id = bone.id;
            
            num_positions := cast(int) channel.mNumPositionKeys;
            num_rotations := cast(int) channel.mNumRotationKeys;
            num_scales := cast(int) channel.mNumScalingKeys;
            
            for sample_index: 0..sample_count-1 {
                k: Serialized_Keyframe;
                
                position_key := channel.mPositionKeys[min(sample_index, num_positions-1)];
                rotation_key := channel.mRotationKeys[min(sample_index, num_rotations-1)];
                scale_key := channel.mScalingKeys[min(sample_index, num_scales-1)];
                
                k.position = to_vec3(position_key.mValue);
                k.rotation = to_quaternion(rotation_key.mValue);
                k.scale = to_vec3(scale_key.mValue);
                
                array_add(*c.frames, k);
            }
            
            array_add(*a.channels, c);
        }
        
        array_add(*animations, a);
    }
    
    _, base := path_decomp(path);
    mesh_out_dir := tprint("%/%", dest, base);
    binary_mesh_out_path := tprint("%/%.mesh", mesh_out_dir, base);
    text_mesh_out_path := tprint("%/%.mesh_text", mesh_out_dir, base);
    
    make_directory_if_it_does_not_exist(mesh_out_dir);
    
    write_binary_mesh_file(binary_mesh_out_path, positions, colours, tex_coords, normals, weights, bone_ids, indices, final_bones);
    write_text_mesh_file(text_mesh_out_path, positions, colours, tex_coords, normals, weights, bone_ids, indices, final_bones);
    
    for * animations {
        text_anim_out_path := tprint("%/%.anim_text", mesh_out_dir, it.name);
        write_text_anim_file(text_anim_out_path, it);
    }
}

#scope_file

#import "Basic";
#import "Hash_Table";
#import "Sloppy_Math";
#import "Sort";

write_binary_mesh_file :: (path: string, positions: [] Vec3, colours: [] Vec4, tex_coords: [] Vec2, normals: [] Vec3, weights: [] Vec3, bone_ids: [] Bone_Ids, indices: [] u32, bones: [] Serialized_Bone) {
    file := file_open(path, true);
    header := Mesh_Header.{ "MESH", positions.count, indices.count, bones.count };
    file_write_string(*file, header.magic);
    file_write(*file, *header.num_vertices, size_of(int));
    file_write(*file, *header.num_indices, size_of(int));
    file_write(*file, *header.num_bones, size_of(int));
    file_write_array(*file, *positions);
    file_write_array(*file, *colours);
    file_write_array(*file, *tex_coords);
    file_write_array(*file, *normals);
    file_write_array(*file, *weights);
    file_write_array(*file, *bone_ids);
    file_write_array(*file, *indices);
    file_write_bones(*file, *bones);
    file_close(*file);
}

write_text_mesh_file :: (path: string, positions: [] Vec3, colours: [] Vec4, tex_coords: [] Vec2, normals: [] Vec3, weights: [] Vec3, bone_ids: [] Bone_Ids, indices: [] u32, bones: [] Serialized_Bone) {
    builder: String_Builder;
    append(*builder, tprint("num_verts = %, num_indices = %, num_bones = %\n", positions.count, indices.count, bones.count));
    append(*builder, "\n");
    
    for positions {
        append(*builder, tprint("% % %\n", it.x, it.y, it.z));
    }
    append(*builder, "\n");
    
    for colours {
        append(*builder, tprint("% % % %\n", it.x, it.y, it.z, it.w));
    }
    append(*builder, "\n");
    
    for tex_coords {
        append(*builder, tprint("% %\n", it.x, it.y));
    }
    append(*builder, "\n");
    
    for normals {
        append(*builder, tprint("% % %\n", it.x, it.y, it.z));
    }
    append(*builder, "\n");
    
    for bone_ids {
        append(*builder, tprint("% % % %\n", it.a, it.b, it.c, it.d));
    }
    append(*builder, "\n");
    
    for weights {
        append(*builder, tprint("% % %\n", it.x, it.y, it.z));
    }
    append(*builder, "\n");
    
    for indices {
        append(*builder, tprint("%\n", it));
    }
    append(*builder, "\n");
    
    for bones {
        append(*builder, tprint("% % %\n", it.id, it.name, it.parent));
        
        append(*builder, tprint("% % % %\n", it.transform.v[0].x, it.transform.v[0].y, it.transform.v[0].z, it.transform.v[0].w));
        append(*builder, tprint("% % % %\n", it.transform.v[1].x, it.transform.v[1].y, it.transform.v[1].z, it.transform.v[1].w));
        append(*builder, tprint("% % % %\n", it.transform.v[2].x, it.transform.v[2].y, it.transform.v[2].z, it.transform.v[2].w));
        append(*builder, tprint("% % % %\n", it.transform.v[3].x, it.transform.v[3].y, it.transform.v[3].z, it.transform.v[3].w));
    }
    
    append(*builder, "\n");
    
    write_entire_file(path, builder_to_string(*builder));
}

write_text_anim_file :: (path: string, anim: *Serialized_Animation) {
    builder: String_Builder;
    
    append(*builder, tprint("name = %\n", anim.name));
    append(*builder, tprint("sample_count = %\n\n", anim.sample_count));
    
    for anim.channels {
        append(*builder, tprint("\n bone_id = %\n", it.bone_id));
        for frame: it.frames {
            append(*builder, tprint("  position = % % %\n", frame.position.x, frame.position.y, frame.position.z));
            append(*builder, tprint("  rotation = % % % %\n", frame.rotation.x, frame.rotation.y, frame.rotation.z, frame.rotation.w));
            append(*builder, tprint("  scale = % % %\n", frame.scale.x, frame.scale.y, frame.scale.z));
        }
    }
    
    write_entire_file(path, builder_to_string(*builder));
}

print_spaces :: (n: int) {
    for 0..n-1 print(" ");
}

file_write_string :: (file: *File, s: string) {
    count := s.count;
    file_write(file, *count, size_of(int));
    file_write(file, s.data, count);
}

file_write_array :: (file: *File, v: *[] $T) {
    file_write(file, v.data, size_of(T) * v.count);
}

file_write_bones :: (file: *File, bones: *[] Serialized_Bone) {
    for <<bones {
        file_write(file, *it.id, size_of(s16));
        file_write(file, *it.parent, size_of(s16));
        file_write_string(file, it.name);
        file_write(file, it.transform.floats.data, size_of(float) * 16);
    }
}

NewArray :: ($T: Type, n: int) -> [] T {
    return .{n,alloc(size_of(T)*n)};
}

to_vec2 :: (v: aiVector3D) -> Vec2 { return .{v.x, v.y}; }
to_vec3 :: (v: aiVector3D) -> Vec3 { return .{v.x, v.y, v.z}; }
to_vec4 :: (v: aiColor4D) -> Vec4 { return .{v.x, v.y, v.z, v.w}; }
to_mat4 :: (m: aiMatrix4x4) -> Mat4 {
    out: Mat4 = ---;
    for 0..15 out.floats[it] = m.floats[it];
    return out;
}
to_quaternion :: (q: aiQuaternion) -> Quaternion {
    return .{q.x, q.y, q.z, q.w};
}

per_triangle_uv :: (position: Vec3, v0: Vec3, v1: Vec3, v2: Vec3) -> Vec2 {
    uv: Vec2;
    
    // Find min and max bounds of the triangle's X and Z coordinates
    minX := min(v0.x, min(v1.x, v2.x));
    minZ := min(v0.z, min(v1.z, v2.z));
    maxX := max(v0.x, max(v1.x, v2.x));
    maxZ := max(v0.z, max(v1.z, v2.z));
    
    // Normalize the current vertex's X and Z position within the triangle's bounds
    uv.x = (position.x - minX) / (maxX - minX);
    uv.y = (position.z - minZ) / (maxZ - minZ);
    
    // Clamp the UVs to ensure they remain within the 0-1 range
    uv.x = clamp(uv.x, 0.0, 1.0);
    uv.y = clamp(uv.y, 0.0, 1.0);
    
    return uv;
}

MESH_PREPROCESS_FLAGS :: #run -> u32 {
    aiProcess_CalcTangentSpace :u32:   0x1;
    aiProcess_JoinIdenticalVertices :u32:   0x2;
    aiProcess_Triangulate :u32:   0x8;
    aiProcess_SplitLargeMeshes :u32:   0x80;
    aiProcess_LimitBoneWeights :u32:   0x200;
    aiProcess_ValidateDataStructure :u32:   0x400;
    aiProcess_ImproveCacheLocality :u32:   0x800;
    aiProcess_RemoveRedundantMaterials :u32:   0x1000;
    aiProcess_SortByPType :u32:   0x8000;
    aiProcess_GenSmoothNormals :u32:   0x40;
    aiProcess_GenUVCoords :u32:   0x40000;
    aiProcess_FindInstances :u32:   0x100000;
    aiProcess_FindDegenerates :u32:   0x10000;
    aiProcess_FindInvalidData :u32:   0x20000;
    aiProcess_OptimizeMeshes  :u32:   0x200000;
    aiProcess_OptimizeGraph :u32: 0x400000;
    aiProcess_PopulateArmatureData :u32: 0x4000;
    
    aiProcessPreset_TargetRealtime_MaxQuality ::
        aiProcess_CalcTangentSpace |
        aiProcess_JoinIdenticalVertices |
        aiProcess_Triangulate |
        aiProcess_GenSmoothNormals |
        aiProcess_SplitLargeMeshes |
        aiProcess_LimitBoneWeights |
        aiProcess_ValidateDataStructure |
        aiProcess_ImproveCacheLocality |
        aiProcess_RemoveRedundantMaterials |
        aiProcess_SortByPType |
        aiProcess_FindDegenerates |
        aiProcess_FindInvalidData |
        aiProcess_GenUVCoords |
        aiProcess_FindInstances |
        aiProcess_OptimizeMeshes |
        aiProcess_OptimizeGraph |
        aiProcess_PopulateArmatureData;
    
    return cast(u32) aiProcessPreset_TargetRealtime_MaxQuality;
};

/*
 * AssImp bindings for Jai.
 *
 * For all documentation of data structures, members and such, refer to the AssImp header files
 * or AssImp documentation.
 *
 */

AISTRING_MAXLEN :: 1024;

AI_SCENE_FLAGS_INCOMPLETE :: 0x1;
AI_SCENE_FLAGS_VALIDATED :: 0x2;
AI_SCENE_FLAGS_VALIDATION_WARNING :: 0x4;
AI_SCENE_FLAGS_NON_VERBOSE_FORMAT :: 0x8;
AI_SCENE_FLAGS_TERRAIN :: 0x10;
AI_SCENE_FLAGS_ALLOW_SHARED :: 0x20;

AI_MAX_FACE_INDICES :: 0x7fff;
AI_MAX_BONE_WEIGHTS :: 0x7fffffff;
AI_MAX_VERTICES :: 0x7fffffff;
AI_MAX_FACES :: 0x7fffffff;
AI_MAX_NUMBER_OF_COLOR_SETS :: 0x8;
AI_MAX_NUMBER_OF_TEXTURE_COORDS :: 0x8;

HINTMAXTEXTURELEN :: 9;

aiVector2D :: Vector2;
aiVector3D :: Vector3;
aiMatrix4x4 :: Matrix4;
aiColor3D :: Vector3;
aiColor4D :: Vector4;
aiQuaternion :: Quaternion;

aiString :: struct {
    count           : u32;
    data            : [AISTRING_MAXLEN]u8;
}

to_string :: inline (ais: aiString) -> string {
    ss : string;
    ss.count = ais.count;
    ss.data = xx *ais.data;
    return ss;
}

to_string :: inline (ais: *aiString) -> string {
    ss : string;
    ss.count = ais.count;
    ss.data = xx *ais.data;
    return ss;
}

aiSkeletonBone :: struct {
    mParent: s32;
    mArmature: *aiNode;
    mNode: *aiNode;
    mNumWeights: u32;
    mMeshId: *aiMesh;
    mWeights: *aiVertexWeight;
    mOffsetMatrix: aiMatrix4x4;
    mLocalMatrix: aiMatrix4x4;
}

aiSkeleton :: struct {
    mName: aiString;
    mNumBones: u32;
    mBones: **aiSkeletonBone;
}


aiScene :: struct {
    mFlags          : u32;
    mRootNode       : *aiNode;
    mNumMeshes      : u32;
    mMeshes         : **aiMesh;
    mNumMaterials   : u32;
    mMaterials      : **aiMaterial;
    mNumAnimations  : u32;
    mAnimations     : **aiAnimation;
    mNumTextures    : u32;
    mTextures       : **aiTexture;
    mNumLights      : u32;
    mLights         : **aiLight;
    mNumCameras     : u32;
    mCameras        : **aiCamera;
    mMetaData       : *aiMetadata;
    mName : aiString;
    mNumSkeletons: u32;
    mSkeletons: **aiSkeleton;
}

aiMetadataType :: enum u32 {
    AI_BOOL         :: 0;
    AI_INT32        :: 1;
    AI_UINT64       :: 2;
    AI_FLOAT        :: 3;
    AI_DOUBLE       :: 4;
    AI_AISTRING     :: 5;
    AI_AIVECTOR3D   :: 6;
    AI_META_MAX     :: 7;
}

aiMetadataEntry :: struct {
    mType           : aiMetadataType;
    mData           : *void;
}

aiMetadata :: struct {
    mNumProperties  : u32;
    mKeys           : *aiString;
    mValues         : *aiMetadataEntry;
}

to_string :: (t: aiMetadataEntry) -> string {
    using t;
    if mType == {
        case .AI_BOOL; 
        if << cast(*bool)mData == true {
            return "True";
        } else {
            return "False";
        }
        case .AI_INT32;
        return tprint("%", <<cast(*s32)mData);
        case .AI_UINT64;
        return tprint("%", <<cast(*u64)mData);
        case .AI_FLOAT;
        return tprint("%", <<cast(*float32)mData);
        case .AI_DOUBLE;
        return tprint("%", <<cast(*float64)mData);
        case .AI_AISTRING;
        return tprint("%", to_string(cast(*aiString)mData));
        case .AI_AIVECTOR3D;
        return tprint("{%, %, %}", (cast(*aiVector3D)mData).x, (cast(*aiVector3D)mData).y, (cast(*aiVector3D)mData).z);
        case;
        return "Unknown";
        
    }
}

aiNode :: struct {
    mName           : aiString;
    mTransformation : Matrix4;
    mParent         : *aiNode;
    mNumChildren    : u32;
    mChildren       : **aiNode;
    mNumMeshes      : u32;
    mMeshes         : *u32;
    mMetaData       : *aiMetadata;
}

aiMesh :: struct {
    mPrimitiveTypes : u32;
    mNumVertices    : u32;
    mNumFaces       : u32;
    mVertices       : *aiVector3D;
    mNormals        : *aiVector3D;
    mTangents       : *aiVector3D;
    mBitangents     : *aiVector3D;
    mColors         : [AI_MAX_NUMBER_OF_COLOR_SETS]*aiColor4D;
    mTextureCoords  : [AI_MAX_NUMBER_OF_TEXTURE_COORDS]*aiVector3D;
    mNumUVComponents: [AI_MAX_NUMBER_OF_TEXTURE_COORDS]u32;
    mFaces          : *aiFace;
    mNumBones       : u32;
    mBones          : **aiBone;
    mMaterialIndex  : u32;
    mName           : aiString;
    mNumAnimMeshes  : u32;
    mAnimMeshes     : **aiAnimMesh;
    mMethod         : u32;
    mAABB           : aiAABB;
    mTextureCoordsNames : **aiString;
}

aiAABB :: struct {
    mMin            : aiVector3D;
    mMax            : aiVector3D;
}

aiAnimMesh :: struct {
    mName           : aiString;
    mVertices       : *aiVector3D;
    mNormals        : *aiVector3D;
    mTangents       : *aiVector3D;
    mBitangents     : *aiVector3D;
    mColors         : [AI_MAX_NUMBER_OF_COLOR_SETS]*aiColor4D;
    mTextureCoords  : [AI_MAX_NUMBER_OF_TEXTURE_COORDS]*aiVector3D;
    mNumVertices    : u32;
    mWeight         : float32;
}

aiVertexWeight :: struct {
    mVertexId       : u32;
    mWeight         : float32;
}

aiFace :: struct {
    mNumIndices     : u32;
    mIndices        : *u32;
}

aiBone :: struct {
    mName           : aiString;
    mNumWeights     : u32;
    mArmature       : *aiNode;
    mNode           : *aiNode;
    mWeights        : *aiVertexWeight;
    mOffsetMatrix   : aiMatrix4x4;
}

aiMaterial :: struct {
    mProperties     : **aiMaterialProperty;
    mNumProperties  : u32;
    mNumAllocated   : u32;
}

aiMaterialProperty :: struct {
    mKey            : aiString;
    mSemantic       : u32;
    mIndex          : u32;
    mDataLength     : u32;
    mType           : aiPropertyTypeInfo;
    mData           : *u8;
}

aiPropertyTypeInfo :: enum {
    aiPTI_Float     :: 0x1;
    aiPTI_Double    :: 0x2;
    aiPTI_String    :: 0x3;
    aiPTI_Integer   :: 0x4;
    aiPTI_Buffer    :: 0x5;
}


aiAnimation :: struct {
    mName           : aiString;
    mDuration       : float64;
    mTicksPerSecond : float64;
    mNumChannels    : u32;
    mChannels       : **aiNodeAnim;
    mNumMeshChannels: u32;
    mMeshChannels   : **aiMeshAnim;
    mNumMorphMeshChannels: u32;
    mMorphMeshChannels: **aiMeshMorphAnim;
}

aiAnimInterpolation :: enum s32 {
    aiAnimInterpolation_Step;
    aiAnimInterpolation_Linear;
    aiAnimInterpolation_Spherical_Linear;
    aiAnimInterpolation_Cubic_Spline;
}

aiNodeAnim :: struct {
    mNodeName: aiString;
    mNumPositionKeys: u32;
    mPositionKeys: *aiVectorKey;
    mNumRotationKeys: u32;
    mRotationKeys: *aiQuatKey;
    mNumScalingKeys: u32;
    mScalingKeys: *aiVectorKey;
    mPreState: aiAnimBehaviour;
    mPostState: aiAnimBehaviour;
}

aiMeshAnim :: struct {
    mNodeName       : aiString;
    mNumPostitionKeys: u32;
    mPositionKeys   : *aiVectorKey;
    mNumRotationKeys: u32;
    mRotationKeys   : *aiQuatKey;
    mNumScalingKeys : u32;
    mScalingKeys    : *aiVectorKey;
    mPreState       : aiAnimBehaviour;
    mPostState      : aiAnimBehaviour;
}

aiAnimBehaviour :: enum u32 {
    aiAnimBehaviour_DEFAULT  :: 0x0;
    aiAnimBehaviour_CONSTANT :: 0x1;
    aiAnimBehaviour_LINEAR   :: 0x2;
    aiAnimBehaviour_REPEAT   :: 0x3;
}

aiVectorKey :: struct {
    mTime           : float64;
    mValue          : aiVector3D;
}

aiQuatKey :: struct {
    mTime           : float64;
    mValue          : aiQuaternion;
}

aiMeshMorphAnim :: struct {
    mName           : aiString;
    mNumKeys        : u32;
    mKeys           : *aiMeshMorphKey;
}

aiMeshMorphKey :: struct {
    mTime           : float64;
    mValues         : *u32;
    mWeights        : *float64;
    mNumValuesAndWeights : u32;
}

aiTexture :: struct {
    mWidth          : u32;
    mHeight         : u32;
    achFormatHint   : [HINTMAXTEXTURELEN]u8;
    pcData          : *aiTexel;
    mFileName       : aiString;
}

aiTexel :: struct {
    b               : u8;
    g               : u8;
    r               : u8;
    a               : u8;   
}

aiLight :: struct {
    mName           : aiString;
    mType           : aiLightSourceType;
    mPosition       : aiVector3D;
    mDirection      : aiVector3D;
    mUp             : aiVector3D;
    mAttenuationConstant : float32;
    mAttenuationLinear   : float32;
    mAttenuationQuadratic: float32;
    mColorDiffuse   : aiColor3D;
    mColorSpecular  : aiColor3D;
    mColorAmbient   : aiColor3D;
    mAngleInnerCone : float32;
    mSize           : aiVector2D;
}

aiLightSourceType :: enum {
    aiLightSource_UNDEFINED     :: 0x0;
    aiLightSource_DIRECTIONAL   :: 0x1;
    aiLightSource_POINT         :: 0x2;
    aiLightSource_SPOT          :: 0x3;
    aiLightSource_AMBIENT       :: 0x4;
    aiLightSource_AREA          :: 0x5;
}

aiCamera :: struct {
    mName           : aiString;
    mPosition       : aiVector3D;
    mUp             : aiVector3D;
    mLookAt         : aiVector3D;
    mHorizontalFOV  : float32;
    mClipPlaneNear  : float32;
    mClipPlaneFar   : float32;
    mAspect         : float32;
}

aiImportFile     :: (pFile: *u8, pFlags: u32) -> *aiScene #foreign assimp;
aiGetErrorString :: () -> *u8 #foreign assimp;
aiReleaseImport  :: (pScene: *aiScene) #foreign assimp;

assimp :: #library "lib/assimp";