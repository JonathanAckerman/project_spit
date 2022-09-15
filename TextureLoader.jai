TEXTURES_PATH :: "C:/jai/sandbox/project_spit/assets/textures";
ERROR_TEXTURE_PATH :: "C:/jai/sandbox/project_spit/assets/textures/error.png";
ERROR_TEXTURE: Texture2D;
ERROR_ANIMATION: [..] Texture2D;

Shaders: ShaderReference;
ShaderReference :: struct
{
    waterShader: Shader;
    displacementMapTexture: Texture2D;
    displacementOffset: Vector2;
    displacementOffsetLoc: s32;
    displacementTexLoc: s32;
}

AnimationFrame :: struct
{
    using texture: *Texture2D;
    tint: Color = WHITE;
    size: Vector2;
}

Animations: AnimationsReference;
AnimationsReference :: struct
{
    table: Table(string, [..] Texture2D);
    path_table: Table(string, animation_ref_info);
    animation_ref_info :: struct { path: string; count: int; };
}

Animation :: struct
{
    frames: [..] AnimationFrame;
    duration: float;
    frameTimer: float;

    currentFrame := 0;
    shouldLoop := false;
    hasFinished := false;
}

file_structure_info :: struct
{
    family: string;         // eg: Items
    genus: string;          // eg: Other
    species: string;        // eg: blueprint
    animation_name: string; // eg: unroll
}

generate_animations_struct :: ()
{
    get_folder_data :: (info: *File_Visit_Info, data: *[..] file_structure_info) 
    {
        if info.is_directory
        {
            folder_name_size := info.full_name.count - TEXTURES_PATH.count;
            folder_name := slice(info.full_name, TEXTURES_PATH.count + 1, folder_name_size);

            file_struct_info: file_structure_info;
            success, left, right := split_from_left(folder_name, #char "/");
            file_struct_info.family = copy_string(left);
            success, left, right = split_from_left(right, #char "/");
            file_struct_info.genus = copy_string(left);
            if begins_with(right, "anims_")
            {
                success, left, right = split_from_left(right, #char "_");
            }

            if right != "" && contains_any_character(right, "/")
            {
                success, left, right = split_from_left(right, #char "/");
                file_struct_info.species = copy_string(left);
                file_struct_info.animation_name = copy_string(right);
                array_add(data, file_struct_info);
            }
        }
    }
    get_texture_data :: (info: *File_Visit_Info, data: *[..] string) 
    {
        if !info.is_directory
        {
            s := copy_string(info.short_name);
            s.count -= 4; // remove '.png' file extension
            array_add(data, s);
        }
    }

    data: [..] file_structure_info;
    visit_files(TEXTURES_PATH, true, *data, get_folder_data, false, true);

    for d, d_index: data
    {
        anim_path := tprint("%/%/%/anims_%/%", TEXTURES_PATH, d.family, d.genus, d.species, d.animation_name);
        filenames: [..] string;
        visit_files(anim_path, false, *filenames, get_texture_data, true, false);
        path_key := copy_string(tprint("%/%", d.species, d.animation_name));
        path_value: AnimationsReference.animation_ref_info;
        path_value.path = anim_path;
        path_value.count = filenames.count;
        table_add(*Animations.path_table, key=path_key, value=path_value);
    }
}

load_all_animations :: ()
{
    generate_animations_struct();
    ERROR_TEXTURE = LoadTexture(to_c_string(ERROR_TEXTURE_PATH));
    array_add(*ERROR_ANIMATION, ERROR_TEXTURE);
    for Animations.path_table
    {
        key, value := it_index, it;
        anim_data: [..] Texture2D;
        for i: 0..value.count - 1
        {
            array_add(*anim_data, LoadTexture(to_c_string(tprint("%/%.png", value.path, i))));
        }
        table_add(*Animations.table, key, anim_data);
        print("%\n", key);
    }
}

// generate_textures_struct :: ()
// {
//     get_data :: (info: *File_Visit_Info, data: *[..] string) 
//     {
//         if info.is_directory
//         {
//             folder_name_size := info.full_name.count - TEXTURES_PATH.count;
//             folder_name := slice(info.full_name, TEXTURES_PATH.count + 1, folder_name_size);

//             name := folder_name;
//             while contains_any_character(name, "/")
//             {
//                 hasSlash, left, name := split_from_left(name, #char "/");
//             }
//             if hasSlash
//             {
//                 found, index := array_find(data[0], left);
//                 if found then array_ordered_remove_by_index(*data[0], index);
//             }
            
//             array_add(data, copy_string(folder_name));
//         }
//         else
//         {
//             s := copy_string(info.short_name);
//             s.count -= 4;
//             array_add(data, s);
//         }
//     }

//     data: [..][..] string; // [0]: directory names, [1]: first dir textures, ...
//     array_resize(*data, 1);
//     visit_files(TEXTURES_PATH, true, *data[0], get_data, false, true);
    
//     for 1..data[0].count
//     {
//         arr: [..] string;
//         array_add(*data, arr);
//     }

//     for data[0]
//     {
//         sb: String_Builder;
//         print_to_builder(*sb, TEXTURES_PATH);
//         print_to_builder(*sb, "/");
//         s: string = copy_string(it);
//         print_to_builder(*sb, s);
//         path := builder_to_string(*sb);
//         visit_files(path, false, *data[it_index + 1], get_data, true, true);
//     }

//     for d, d_index: data[0]
//     {
//         for t, t_index: data[d_index + 1]
//         {
//             path := tprint("%/%/%.png", TEXTURES_PATH, d, t);
//             table_add(*Textures.path_table, key = t, value = path);
//         }
//     }
// }

// load_all_textures :: ()
// {
//     generate_textures_struct();
//     ERROR_TEXTURE = LoadTexture(to_c_string(ERROR_TEXTURE_PATH));
//     textures_info := type_info(type_of(Textures));
//     for Textures.path_table
//     {
//         key, value := it_index, it;
//         table_add(*Textures.table, key, LoadTexture(to_c_string(value)));
//     }

//     Textures.waterShader = LoadShader(null, to_c_string("./assets/shaders/displacementMap.fs"));
//     table_add(*Textures.table, "displacement_map", LoadTexture(to_c_string("./assets/shaders/displacement_map.png")));
//     Textures.displacementOffsetLoc = GetShaderLocation(Textures.waterShader, "displacementOffset");
//     Textures.displacementTexLoc    = GetShaderLocation(Textures.waterShader, "displacementSampler");
// }

load_all_shaders :: ()
{
    Shaders.waterShader = LoadShader(null, to_c_string("./assets/shaders/displacementMap.fs"));
    Shaders.displacementMapTexture = LoadTexture(to_c_string("./assets/shaders/displacement_map.png"));
    Shaders.displacementOffsetLoc  = GetShaderLocation(Shaders.waterShader, "displacementOffset");
    Shaders.displacementTexLoc     = GetShaderLocation(Shaders.waterShader, "displacementSampler");
}

#import "Basic";            // to_c_string()
#import "String";           // slice()
#import "Hash_Table";       // Table
#import "Raylib-Jai";       // Texture2D
#import "File_Utilities";   // File_Visit_Info
#import "Math";             // Vector2