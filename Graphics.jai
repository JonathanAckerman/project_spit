draw_texture_centered :: (info: TextureInfo, center: Vector2, forward: Vector2, size: Vector2, scale: float)
{
    x := forward.x;
    y := ifx RAYLIB then -forward.y else forward.y;
    rot := atan2(y, x);
    drawpos: Vector2;
    if RAYLIB {
        reverse_ray_bullshit_vector := rotate_vector(size/2, atan2(forward.y, forward.x));
        drawpos = center - reverse_ray_bullshit_vector;
    } else {
        drawpos = center - size/2;
    }

    // for some reason 'size' & 'scale' need to be separate concepts, thanks ray
    DrawTextureEx(info.texture, drawpos, -rad2deg(rot), scale, info.tint);
}