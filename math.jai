
deg2rad :: PI / 180.0;
rad2deg :: 180.0 / PI;

Vec2 :: Vector2;
Vec3 :: Vector3;
Vec4 :: Vector4;
Mat4 :: Matrix4;

vec3_rotate :: (v: Vec3, q: Quaternion) -> Vec3 {
    rotate(*v, q);
    return v;
}

mat4_identity :: () -> Mat4 {
    m: Mat4 = ---;
    identity(*m);
    return m;
}

mat4_look_at :: (pos: Vec3, dir: Vec3) -> Mat4 {
    return make_look_at_matrix(pos, dir, .{0, 1, 0}, false);
}

mat4_ortho :: orthographic_projection_matrix;

mat4_inverse :: inverse;
mat4_projection :: make_projection_matrix;
mat4_translation :: make_translation_matrix4;
mat4_scale :: make_scale_matrix4;
mat4_rotation :: (q: Quaternion) -> Mat4 {
    m := mat4_identity();
    set_rotation(*m, q);
    return m;
}

mat4_transpose :: transpose;

quat_from_matrix :: get_rotation;

nlerp_shortest :: (a: Quaternion, b: Quaternion, t: float) -> Quaternion
{
    first := a;
    second := b;
    if dot(first, second) < 0
        second = -second;
    return nlerp(first, second, t);
}

quat_axis_angle :: (axis: Vec3, angle: float) -> Quaternion {
    q: Quaternion;
    set_from_axis_and_angle(*q, axis.x, axis.y, axis.z, angle);
    return q;
}

mat4_decompose :: (m: Mat4) -> Vector3, Quaternion, Vector3 {
	translation := Vec3.{
        m._14,
        m._24,
        m._34
    };
    
	rotation := quat_from_matrix(m);
    
	scale := Vec3.{
        length(Vec3.{m._11, m._21, m._31}),
        length(Vec3.{m._12, m._22, m._32}),
        length(Vec3.{m._13, m._23, m._33})
    };
    
	return translation, rotation, scale;
}

mat4_euler_rotation :: (rotation: Vec3) -> Mat4 {
    cX := cos(rotation.x);
    sX := sin(rotation.x);
    cY := cos(rotation.y);
    sY := sin(rotation.y);
    cZ := cos(rotation.z);
    sZ := sin(rotation.z);
    
    m: Mat4 = ---;
    
    m._11 = cY * cZ;
    m._12 = -cY * sZ;
    m._13 = sY;
    m._14 = 0;
    
    m._21 = sX * sY * cZ + cX * sZ;
    m._22 = -sX * sY * sZ + cX * cZ;
    m._23 = -sX * cY;
    m._24 = 0;
    
    m._31 = -cX * sY * cZ + sX * sZ;
    m._32 = cX * sY * sZ + sX * cZ;
    m._33 = cX * cY;
    m._34 = 0;
    
    m._41 = 0;
    m._42 = 0;
    m._43 = 0;
    m._44 = 1;
    
    return m;
}

#scope_file

#import "Basic";
#import "Math";