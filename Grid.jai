GridTile :: struct
{
    x: float;
    y: float;
}

Grid :: struct
{
    chunkSize :: 20;
    tileSize :: 100;
    grid: [chunkSize][chunkSize] GridTile;

    left := () => 0;
    right := () => chunkSize * tileSize;
    top := () => 0;
    bottom := () => chunkSize * tileSize;
}