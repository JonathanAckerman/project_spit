Maybe :: struct(T: Type)
{
    value: T = ---;
    exists: bool;
}

NewMaybe :: (thing: $T) -> Maybe(T)
{
    m: Maybe(T);
    m.exists = true;
    m.value = thing;
    return m;
}

Nothing :: ($T: Type = void) -> Maybe(T)
{
    return Maybe(T).{};
}