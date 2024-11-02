
Font :: struct {
    path: string;
    texture: *Texture;
    
    line_skip := 0.0;
    scale := 0.0;
    size := 0.0;
    char_width := 0.0;
    
    info: Stb_Font_Info;
    chars: []Stb_Packed_Char;
}

init_font_system :: () {
    fonts = create_typed_arena(Font);
}

load_font :: (path: string, size: float) -> *Font {
    for * fonts {
        if it.path == path && it.size == size return it;
    }
    
    file, success := read_entire_file(path);
    if !success {
        print("Font % failed to load", path);
        return *null_font;
    }
    
    font_info: Stb_Font_Info;
    stb_init_font(*font_info, file.data, stb_get_font_offset_for_index(file.data, 0));
    scale := stb_scale_for_pixel_height(*font_info, size);
    
    width, height: s32 = 512;
    
    mark := arena_push_mark(*working_arena);
    
    pixels: *u8 = arena_alloc(*working_arena, xx (width * height));
    char_data := arena_push_n(*working_arena, Stb_Packed_Char, 96);
    
    pack_context: Stb_Pack_Context;
    stb_pack_begin(*pack_context, pixels, width, height, width, 1, null);
    stb_pack_font_range(*pack_context, file.data, 0, size, 32, 96, char_data.data);
    stb_pack_end(*pack_context);
    
    texture := create_texture(tprint("%_%", path, size), width, height, pixels, .R);
    
    ascent, descent, line_gap: s32 = 0;
    stb_get_font_v_metrics(*font_info, *ascent, *descent, *line_gap);
    line_skip := (ascent - descent + line_gap) * scale;
    
    advance: s32 = 0;
    stb_get_codepoint_h_metrics(*font_info, #char "A", *advance, null);
    
    font := arena_push(*fonts);
    font.path = path;
    font.texture = texture;
    font.line_skip = line_skip;
    font.scale = scale;
    font.size = size;
    font.info = font_info;
    font.chars = char_data;
    font.char_width = advance * font.scale;
    
    arena_pop_mark(*working_arena, mark);
    
    return font;
}

get_string_size :: (font: *Font, s: string) -> Vec2 {
    width := 0;
    data := s.data;
    while <<data {
        advance: s32 = 0;
        stb_get_codepoint_h_metrics(*font.info, <<data, *advance, null);
        width += advance;
        data += 1;
    }
    
    ascent, descent, line_gap: s32 = 0;
    stb_get_font_v_metrics(*font.info, *ascent, *descent, *line_gap);
    
    return .{width * font.scale, font.line_skip};
}

#scope_file

fonts: Typed_Arena(Font);
null_font: Font;

#import "File";