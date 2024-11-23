
add_all_files :: (workspace: Workspace) {
    builder: String_Builder;
    
    files := file_list("./");
    for files {
        if !contains(it, ".jai") continue;
        if contains(it, "first.jai") continue;
        if contains(it, "font.jai") continue;
        
        add_build_file(it, workspace);
    }
}

set_common_options :: (options: *Build_Options) {
    options.output_path = "run_tree";
    options.intermediate_path = ".build/";
    options.backend = .LLVM;
    options.output_executable_name = "skeleton";
    options.debug_for_expansions = true;
    set_optimization(options, .VERY_DEBUG);
    options.text_output_flags = .OUTPUT_TIMING_INFO;
}

build_linux :: () {
    workspace := compiler_create_workspace("Linux Build");
    options := get_build_options(workspace);
    set_common_options(*options);
    
    options.os_target = .LINUX;
    set_build_options(options, workspace);
    
    add_all_files(workspace);
}

build_windows :: () {
    workspace := compiler_create_workspace("Windows Build");
    options := get_build_options(workspace);
    set_common_options(*options);
    
    options.os_target = .WINDOWS;
    options.use_natvis_compatible_types = true;
    set_build_options(options, workspace);
    
    add_all_files(workspace);
}

build :: () {
#if OS == .WINDOWS {
        build_windows();
    }
    else #if OS == .LINUX {
        build_linux();
    }
    else {
        report_error("Platform not supported.");
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