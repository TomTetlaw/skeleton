
build :: () {
    workspace := compiler_create_workspace();
    
    options := get_build_options();
    args := options.compile_time_command_line;
    
    options.output_executable_name = "skeleton";
    options.output_path = "build";
    options.intermediate_path = "build";
    options.debug_for_expansions = true;
    set_optimization(*options, .VERY_DEBUG);
    
    set_build_options(options, workspace);
    
    files := file_list("./");
    for files {
        if !contains(it, ".jai") continue;
        if contains(it, "first.jai") continue;
        
        add_build_file(it, workspace);
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