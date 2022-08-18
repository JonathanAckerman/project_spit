TEXTURES_PATH :: "C:/jai/sandbox/project_spit/assets/textures";
ERROR_TEXTURE_PATH :: "C:/jai/sandbox/project_spit/assets/textures/error.png";
ERROR_TEXTURE: Texture2D;

Textures: struct
{
    table: Table(string, Texture2D);
    path_table: Table(string, string);

    outlineShader: Shader;
    outlineSize := 2.0;
    outlineSizeLoc: s32;
    textureSizeLoc: s32;
}

TextureInfo :: struct
{
    using texture: *Texture2D;
    tint: Color = WHITE;
    size: Vector2;
}

generate_textures_struct :: ()
{
    get_data :: (info: *File_Visit_Info, data: *[..] string) 
    {
        if info.is_directory
        {
            array_add(data, copy_string(info.short_name));
        }
        else
        {
            s := copy_string(info.short_name);
            s.count -= 4;
            array_add(data, s);
        }
    }

    data: [..][..] string; // [0]: directory names, [1]: first dir textures, ...
    array_resize(*data, 1);
    visit_files(TEXTURES_PATH, false, *data[0], get_data, false, true);
    
    for 1..data[0].count
    {
        arr: [..] string;
        array_add(*data, arr);
    }

    for data[0]
    {
        sb: String_Builder;
        print_to_builder(*sb, TEXTURES_PATH);
        print_to_builder(*sb, "/");
        s: string = copy_string(it);
        print_to_builder(*sb, s);
        path := builder_to_string(*sb);
        visit_files(path, false, *data[it_index + 1], get_data, true, true);
    }

    for d, d_index: data[0]
    {
        for t, t_index: data[d_index + 1]
        {
            path := tprint("%/%/%.png", TEXTURES_PATH, d, t);
            table_add(*Textures.path_table, key = tprint("%", t), value = path);
        }
    }

    builder: String_Builder;
    for d, d_index: data[0]
    {
        for t, t_index: data[d_index + 1]
        {
            print_to_builder(*builder, "%/%/%.png\n", TEXTURES_PATH, d, t);
        }
    }
    result := builder_to_string(*builder);
}

load_all_textures :: ()
{
    generate_textures_struct();
    ERROR_TEXTURE = LoadTexture(to_c_string(ERROR_TEXTURE_PATH));
    textures_info := type_info(type_of(Textures));
    for Textures.path_table
    {
        key, value := it_index, it;
        table_add(*Textures.table, key, LoadTexture(to_c_string(value)));
    }

    Textures.outlineShader = LoadShader(null, to_c_string("./assets/shaders/outlineShader.fs"));
    outlineColor : [4] float = .[1.0, 0.0, 0.0, 1.0 ];
    outlineColorLoc: s32;
    // Get shader locations
    Textures.outlineSizeLoc = GetShaderLocation(Textures.outlineShader, "outlineSize");
    outlineColorLoc = GetShaderLocation(Textures.outlineShader, "outlineColor");
    Textures.textureSizeLoc = GetShaderLocation(Textures.outlineShader, "textureSize");
    // Set shader values (they can be changed later)
    SetShaderValue(Textures.outlineShader, Textures.outlineSizeLoc, *Textures.outlineSize, cast(s32) ShaderUniformDataType.SHADER_UNIFORM_FLOAT);
    SetShaderValue(Textures.outlineShader, outlineColorLoc, *outlineColor, cast(s32) ShaderUniformDataType.SHADER_UNIFORM_VEC4);
}

#import "Basic";            // to_c_string()
#import "Hash_Table";       // Table
#import "Raylib-Jai";       // Texture2D
#import "File_Utilities";   // File_Visit_Info