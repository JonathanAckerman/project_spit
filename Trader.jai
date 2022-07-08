Building :: struct
{
    position: Vector2;
    center: Vector2;
    size: int;
    bldg_type: Bldg_Type;

    Bldg_Type :: enum
    {
        TRADER;
        SHOP;
    }

    union
    {
        using trader: struct
        {
            want: Resource_ID;
            have: Resource_ID;
        }

        using shop: struct
        {
            resource: Resource_ID;
            amount: int;
            item: Item;
        }
    }
}
