
deg2rad :: PI / 180.0;
rad2deg :: 180.0 / PI;
turn2rad :: 2 * PI;
turn2deg :: PI;
rad2turn :: 1.0 / 2 * PI;
deg2turn :: 1.0 / 360;

basis_forward :: Vec3.{1, 0, 0};
basis_right :: Vec3.{0, -1, 0};
basis_up :: Vec3.{0, 0, 1};

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

append :: (v: Vec3, w: float) -> Vec4 {
    return Vec4.{v.x, v.y, v.z, w};
}

mat4_inverse :: inverse;

mat4_projection :: make_projection_matrix;

mat4_scale :: (v: Vec3) -> Mat4 {
    m: Mat4 = ---;
    m._11 = -v.y;
    m._22 = v.z;
    m._33 = v.x;
    m._44 = 1;
    return m;
}

mat4_translation :: (v: Vec3) -> Mat4 {
    m := mat4_identity();
    m._14 = -v.y;
    m._24 = v.z;
    m._34 = v.x;
    return m;
}

mat4_axis_conversion :: Mat4.{
    0, 0, 1, 0,
    -1, 0, 0, 0,
    0, 1, 0, 0,
    0, 0, 0, 1,
};

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
    
    st := sin(angle * 0.5);
    ct := cos(angle * 0.5);
    
    q.x = axis.x * st;
    q.y = -axis.y * st;
    q.z = axis.z * st;
    q.w = ct;
    
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

#scope_file

#import "Basic";
#import "Math";