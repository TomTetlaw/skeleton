
build :: () {
    workspace := compiler_create_workspace();
    
    options := get_build_options();
    args := options.compile_time_command_line;
    
    debug_mesh_compiler := false;
    for args {
        if equal(it, "dmc") debug_mesh_compiler = true;
    }
    
    options.output_executable_name = "skeleton";
    options.output_path = "build";
    options.intermediate_path = "build";
    options.debug_for_expansions = true;
    set_optimization(*options, .VERY_DEBUG);
    
    set_build_options(options, workspace);
    
    add_build_string(tprint("DEBUG_MESH_COMPILER :: %;\n", debug_mesh_compiler), workspace);
    
    files := file_list("./");
    for files {
        if !contains(it, ".jai") continue;
        
        if contains(it, "first.jai") continue;
        if !debug_mesh_compiler && contains(it, "mesh_compiler.jai") continue;
        
        add_build_file(it, workspace);
    }
    
    if !debug_mesh_compiler {
        fbx_files := file_list("mesh_source_data");
        for fbx_files {
            if !contains(it, ".fbx") continue;
            compile_mesh(it, "build/mesh");
        }
    }
    
    set_build_options_dc(.{do_output = false});
}

#run build();

#scope_file

#import "Basic";
#import "Compiler";
#import "String";
#import "File";
#import "File_Utilities";
#import "Process";

#load "mesh_compiler.jai";
#load "math.jai";
#load "mesh_shared.jai";