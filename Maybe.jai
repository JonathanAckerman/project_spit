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

set :: (m: Maybe($T), v: T)
{
    m.value = v;
    m.exists = true;
}