Maybe :: struct(T: Type)
{
    value: T = ---; //@TODO: consider using?
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

set :: (m: Maybe($T), v: T)
{
    m.value = v;
    m.exists = true;
}