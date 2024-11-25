
Texture :: struct {
    id: u32;
    path: string;
    width, height: int;
}

init_texture_system :: () {
    textures = create_typed_arena(Texture);
}

load_texture :: (path: string) -> *Texture {
    for * textures {
        if equal(it.path, path) return it;
    }
    
    width, height, channels: s32;
    pixels := stb_load_image(path.data, *width, *height, *channels, 4);
    if !pixels return *null_texture;
    
    id: u32;
    glGenTextures(1, *id);
    glBindTexture(GL_TEXTURE_2D, id);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, xx width, xx height, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_REPEAT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glGenerateMipmap(GL_TEXTURE_2D);
    glObjectLabel(GL_TEXTURE, id, xx path.count, path.data);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    stb_image_free(pixels);
    
    texture := arena_push(*textures);
    texture.id = id;
    texture.path = path;
    texture.width = xx width;
    texture.height = xx height;
    
    return texture;
}

Texture_Format :: enum {
    RGBA;
    RGB;
    R;
}

create_texture :: (name: string, width: int, height: int, pixels: *u8, format: Texture_Format = .RGBA) -> *Texture {
    pixel_format, internal_format: u32;
    if format == {
        case .RGBA;
        pixel_format = GL_RGBA;
        internal_format = GL_RGBA8;
        case .RGB;
        pixel_format = GL_RGB;
        internal_format = GL_RGB8;
        case .R;
        pixel_format = GL_RED;
        internal_format = GL_R8;
    }
    
    id: u32;
    glGenTextures(1, *id);
    glBindTexture(GL_TEXTURE_2D, id);
    glTexImage2D(GL_TEXTURE_2D, 0, xx internal_format, xx width, xx height, 0, xx pixel_format, GL_UNSIGNED_BYTE, pixels);
    glGenerateMipmap(GL_TEXTURE_2D);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR_MIPMAP_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glGenerateMipmap(GL_TEXTURE_2D);
    glObjectLabel(GL_TEXTURE, id, xx name.count, name.data);
    glBindTexture(GL_TEXTURE_2D, 0);
    
    texture := arena_push(*textures);
    texture.id = id;
    texture.path = name;
    texture.width = width;
    texture.height = height;
    return texture;
}

#scope_file

textures: Typed_Arena(Texture);

null_texture := Texture.{0, "", 0, 0};

#import "Basic";
#import "String";