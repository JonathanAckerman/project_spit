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