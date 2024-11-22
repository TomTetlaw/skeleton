
add_all_files :: (workspace: Workspace) {
    files := file_list("./");
    for files {
        if !contains(it, ".jai") continue;
        if contains(it, "first.jai") continue;
        if contains(it, "font.jai") continue;
        
        add_build_file(it, workspace);
    }
}

set_common_options :: (options: *Build_Options) {
    options.backend = .LLVM;
    options.output_executable_name = "skeleton";
    options.debug_for_expansions = true;
    set_optimization(options, .VERY_DEBUG);
    options.text_output_flags = .OUTPUT_TIMING_INFO;
}

build_linux :: () {
    make_directory_if_it_does_not_exist("./linux_build");

    workspace := compiler_create_workspace("Linux Build");
    options := get_build_options(workspace);
    set_common_options(*options);
    
    options.os_target = .LINUX;
    options.output_path = "linux_build";
    options.intermediate_path = "./.build/";
    set_build_options(options, workspace);
    
    add_all_files(workspace);

    copy_directory("./run_tree/", "./linux_build/");
}

build_windows :: () {
    make_directory_if_it_does_not_exist("./windows_build");

    workspace := compiler_create_workspace("Windows Build");
    options := get_build_options(workspace);
    set_common_options(*options);
    
    options.os_target = .WINDOWS;
    options.use_natvis_compatible_types = true;
    options.output_path = "windows_build";
    options.intermediate_path = "./.build/";
    set_build_options(options, workspace);
    
    add_all_files(workspace);

    copy_directory("./run_tree/", "./windows_build/");
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