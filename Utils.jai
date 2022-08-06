round :: (f: float) -> float
{
    if f == 0 return 0;

    if f > 0
        return floor(f + 0.5);
    else
        return ceil(f - 0.5);
}

swap_and_pop :: (array_pointer: *[..] $T, object_pointer: *T)
{
    array := <<array_pointer;
    <<object_pointer = array[array.count - 1];
    array.count -= 1;
}

// trim_textures_whitespace :: ()
// {
//     // visit_files(TEXTURES_PATH, true, null, trim, true, true);

//     trim :: (info: *File_Visit_Info, data: void)
//     {
//         if !info.is_directory
//         {
//             file, open_success :=  file_open(info.full_name, for_writing=true, keep_existing_content=true);
//             if !open_success {
//                 print("Could not open file % for writing.\n", info.full_name);
//                 return;
//             }

//             data, read_success := read_entire_file(file);
//             if !read_success
//             {
//                 print("Could not read file % data.\n", info.full_name); 
//                 return;
//             }

//             for cast([] u8) data
//             {
//                 print("%", it);
//             }

//             // first_nonwhite_row: s64;
//             // {
//             //     // figure out the first nonwhite row
//             //     first_nonwhite_row = 0;
//             // }
//             // last_nonwhite_row: s64;
//             // {
//             //     // figure out the last nonwhite row
//             // }
//             // first_nonwhite_col: s64;
//             // {
//             //     // figure out the first nonwhite row
//             //     first_nonwhite_row = 0;
//             // }
//             // last_nonwhite_col: s64;
//             // {
//             //     // figure out the last nonwhite row
//             // }

//             // data: *void;

//             // for first_nonwhite_col..last_nonwhite_col

//             // success = file_write(*file, data);
//             // if !success {
//             //     print("Could not write to file %.\n", info.full_name);
//             //     return;
//             // }
            
//             file_close(*file);
//         }
//     }
// }

test_file_read :: ()
{
    filename := to_c_string(tprint("%/%", TEXTURES_PATH, "Items/fiber.png"));
    w, h, channels : s32;
    data := stbi_load(filename, *w, *h, *channels, 0);

    if data == null {
        print("Could not load file %.\n", "fiber.png");
        return;
    }

    first_nonwhite_row: *u8;
    last_nonwhite_row : *u8;
    first_nonwhite_col: *u8;
    last_nonwhite_col : *u8;

    line_it := data;
    EOF := data + w * h * channels;
    // find first row
    while line_it < EOF {
        pixel_it := line_it;
        EOL := line_it + w * size_of(u8);
        while pixel_it < EOL {
            p: Color;
            p.r = <<(pixel_it + size_of(u8) * 0);
            p.g = <<(pixel_it + size_of(u8) * 1);
            p.b = <<(pixel_it + size_of(u8) * 2);
            p.a = <<(pixel_it + size_of(u8) * 3);

            if p.a != 0 {
                first_nonwhite_row = line_it;
                break;
            }

            pixel_it += size_of(u8) * channels;
        }
        line_it += size_of(u8) * channels * w;
    }

    // find last row
    line_it = EOF;
    while line_it > data {
        pixel_it := line_it;
        BOL := line_it - w * size_of(u8);
        while pixel_it > BOL {
            p: Color;
            p.a = <<(pixel_it - size_of(u8) * 0);
            p.b = <<(pixel_it - size_of(u8) * 1);
            p.g = <<(pixel_it - size_of(u8) * 2);
            p.r = <<(pixel_it - size_of(u8) * 3);

            if p.a != 0 {
                last_nonwhite_row = BOL;
                break;
            }

            pixel_it -= size_of(u8) * channels;
        }
        line_it -= size_of(u8) * channels * w;
    }

    // find first col
    line_it = data;
    while line_it < EOF {
        pixel_it := line_it;
        EOR := line_it + w * (h - 1) * size_of(u8);
        while pixel_it < EOR {
            p: Color;
            p.r = <<(pixel_it + size_of(u8) * 0);
            p.g = <<(pixel_it + size_of(u8) * 1);
            p.b = <<(pixel_it + size_of(u8) * 2);
            p.a = <<(pixel_it + size_of(u8) * 3);

            if p.a != 0 {
                first_nonwhite_col = line_it;
                break;
            }

            pixel_it += size_of(u8) * channels * w;
        }
        line_it += size_of(u8) * channels;
    }

    // find last col
    line_it = EOF;
    while line_it > data {
        pixel_it := line_it;
        BOR := line_it - w * (h - 1) * size_of(u8);
        while pixel_it > BOR {
            p: Color;
            p.a = <<(pixel_it - size_of(u8) * 0);
            p.b = <<(pixel_it - size_of(u8) * 1);
            p.g = <<(pixel_it - size_of(u8) * 2);
            p.r = <<(pixel_it - size_of(u8) * 3);

            if p.a != 0 {
                last_nonwhite_col = BOR;
                break;
            }

            pixel_it -= size_of(u8) * channels;
        }
        line_it -= size_of(u8) * channels * w;
    }

    first_col_number := (first_nonwhite_col - data) / (size_of(u8) * channels);
    first_pixel := first_nonwhite_row + first_col_number * size_of(u8) * channels;
    last_col_number := (last_nonwhite_col - data) / (size_of(u8) * channels);
    last_pixel := last_nonwhite_row + last_col_number * size_of(u8) * channels;

    new_width := (last_nonwhite_col - first_nonwhite_col) / (size_of(u8) * channels);
    new_height := (last_nonwhite_row - first_nonwhite_row) / (size_of(u8) * channels);

    iter := data;
    pic_iter := first_pixel;
    NEOF := data + size_of(u8) * channels * new_width * new_height;
    while iter < NEOF {
        <<iter = <<pic_iter;
        iter += size_of(u8);
        pic_iter += size_of(u8);
    }

    stbi_write_png(to_c_string("fiber_test.png"), xx new_width, xx new_height, channels, data, xx new_width);

    stbi_image_free(data);
}