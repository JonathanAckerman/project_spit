EXECUTABLE_NAME :: "project_spit";
USER_MODULES_PATH :: "../../user_modules";
ENTRY_POINT :: "main.jai";

#run {
    w := compiler_create_workspace("Target Program");
    if !w { print("Workspace creation failed.\n"); return; }
    
    options := get_build_options(w);
    options.output_executable_name = EXECUTABLE_NAME;
    new_path : [..] string;
    array_add(*new_path, ..options.import_path);
    array_add(*new_path, USER_MODULES_PATH);
    options.import_path = new_path;
    options.text_output_flags = 0;
    set_build_options(options, w);
    
    compiler_begin_intercept(w);
    add_build_file(ENTRY_POINT, w);
    //Entity_Storage.prebuild_step(w);
    
    while true {
        message := compiler_wait_for_message();
        if !message || message.kind == .COMPLETE then break;
        
        //Entity_Storage.build_step(message);
    }
    
    compiler_end_intercept(w);
    set_build_options_dc(.{do_output=false, write_added_strings=false});
}

//Entity_Storage :: #import "Entity_Storage"(BUILDING=true);
#import "Basic";
#import "Compiler";