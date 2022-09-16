// trim_textures_whitespace :: ()
// {
//     generate_animations_struct();

//     for texture: Animations.path_table
//     {
//         filename := to_c_string(texture);
//         w, h, channels : s32;
//         data := stbi_load(filename, *w, *h, *channels, 0);

//         xmin : s64 = w;
//         xmax := 0;
//         ymin : s64 = h;
//         ymax := 0;

//         iter := data;
//         x    := 0;
//         y    := 0;
//         EOF  := data + w * h * channels;
//         while iter != EOF {
//             p: Color;
//             p.r = <<(iter + size_of(u8) * 0);
//             p.g = <<(iter + size_of(u8) * 1);
//             p.b = <<(iter + size_of(u8) * 2);
//             p.a = <<(iter + size_of(u8) * 3);

//             if p.a != 0 {
//                 if x < xmin then xmin = x;
//                 if x > xmax then xmax = x; 
//                 if y < ymin then ymin = y;
//                 if y > ymax then ymax = y;
//             }

//             iter += size_of(u8) * channels;
//             x += 1;
//             x = x % w;
//             if x == 0 then y += 1;
//         }

//         new_width  := (xmax - xmin) + 1;
//         new_height := (ymax - ymin) + 1;

//         new_data := cast(*u8) alloc(size_of(u8) * channels * new_width * new_height);
//         newEOF   := new_data + size_of(u8) * channels * new_width * new_height;
//         from     := data + size_of(u8) * channels * (xmin + (ymin * w));
//         to       := new_data;
//         x = 0;
//         while to < newEOF {
//             <<to = <<from;
//             to += size_of(u8);
//             x += 1;
//             x = x % new_width * size_of(u8) * channels;
//             if x == 0 then from += (w - new_width) * channels + 1;
//             else from += size_of(u8);
//         }

//         stbi_write_png(filename, xx new_width, xx new_height, channels, new_data, xx new_width * channels);

//         stbi_image_free(data);
//     }
// }



// #load "TextureLoader.jai";      // generate_animations_struct()
// #import "stb_image";            // stbi_load(), stbi_image_free()
// #import "stb_image_write";      // stbi_write_png()