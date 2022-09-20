round :: (f: float) -> float
{
    if f == 0 return 0;

    if f > 0
        return floor(f + 0.5);
    else
        return ceil(f - 0.5);
}

last :: (array: [] $T) -> T
{
    return array[array.count - 1];
}

valid_neighboring_offsets :: (cur_index: int, width: int) -> [] int
{
    // assume xmin=0, ymin=0, height=width
    result: [..] int;
    for j: -1..1
    {
        for i: -1..1
        {
            x := cur_index % width;
            y := cur_index / width;

            if x + i >= 0 && x + i < width &&
                y + j >= 0 && y + j < width
            {
                array_add(*result, j * width + i);
            }
        }
    }
    return result;
}

rad2deg :: (radians) => radians * 180/PI;
deg2rad :: (degrees) => degrees * PI/180;

rotate_vector :: (v: Vector2, radians: float) -> Vector2
{
    return xy(v.x * cos(radians) - v.y * sin(radians), v.x * sin(radians) + v.y * cos(radians));
}

// @Note: end is one past the end ala C++
array_rotate :: (first: *$T, new_first: *T, end: *T) -> *T
{
    if first == new_first then return end;
    if new_first == end then return first;

    read := new_first;
    write := first;
    next_read := first;

    while (read != end)
    {
        if write == next_read then next_read = read;
        Swap(write, read);
        read += 1;
        write += 1;
    }

    array_rotate(write, next_read, end);
    return write;
}

xprint :: (args: ..Any) -> string {
    builder: String_Builder; defer free_buffers(*builder); // pretty sure you don't need to free_buffers anymore?
    for args print_to_builder(*builder, tprint("%", it));
    return builder_to_string(*builder);
}