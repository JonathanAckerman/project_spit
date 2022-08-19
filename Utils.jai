round :: (f: float) -> float
{
    if f == 0 return 0;

    if f > 0
        return floor(f + 0.5);
    else
        return ceil(f - 0.5);
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