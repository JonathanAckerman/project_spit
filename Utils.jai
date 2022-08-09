round :: (f: float) -> float
{
    if f == 0 return 0;

    if f > 0
        return floor(f + 0.5);
    else
        return ceil(f - 0.5);
}
