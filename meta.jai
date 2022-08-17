EXECUTABLE_NAME :: "project_spit";
USER_MODULES_PATH :: "../../user_modules";
ENTRY_POINT :: "main.jai";

#run {
    args := get_build_options().compile_time_command_line;
    for arg: args 
    {
        if arg == "help" {
            print("trim-pngs\n");
        }
        else if arg == "trim-pngs" {
            tools_workspace := compiler_create_workspace("Tools Program"); 
            if !tools_workspace { print("Workspace creation failed.\n"); return; }
            options := get_build_options(tools_workspace);
            options.text_output_flags = 0;
            set_build_options(options, tools_workspace);
            add_build_string("#load \"tools.jai\"; #run trim_textures_whitespace();", tools_workspace);
            set_build_options_dc(.{do_output=false, write_added_strings=false}, tools_workspace);
        }
    }

    target_workspace := compiler_create_workspace("Target Program"); {
        if !target_workspace { print("Workspace creation failed.\n"); return; }
        options := get_build_options(target_workspace); {
            new_path : [..] string;
            array_add(*new_path, ..options.import_path);
            array_add(*new_path, USER_MODULES_PATH);
            options.import_path = new_path;
            options.output_executable_name = EXECUTABLE_NAME;
            options.text_output_flags = 0;
        }
        set_build_options(options, target_workspace);
        add_build_file(ENTRY_POINT, target_workspace);
        set_build_options_dc(.{do_output=false, write_added_strings=false});
    }
}

#import "Basic";
#import "Compiler";