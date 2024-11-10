
lerp :: (a: $T, b: T, t: float) -> T {
    return a * (1 - t) + b * t;
}

deg2rad :: PI / 180.0;
rad2deg :: 180.0 / PI;

Vec2 :: struct {
    x, y: float;
}

operator+ :: (a: Vec2, b: Vec2) -> Vec2 { return .{a.x + b.x, a.y + b.y}; }
operator- :: (a: Vec2, b: Vec2) -> Vec2 { return .{a.x - b.x, a.y - b.y}; }
operator* :: (a: Vec2, b: Vec2) -> Vec2 { return .{a.x * b.x, a.y * b.y}; }
operator* :: (a: Vec2, b: float) -> Vec2 { return .{a.x * b, a.y * b}; }

length :: (a: Vec2) -> float { return sqrt(a.x*a.x + a.y*a.y); }
dot :: (a: Vec2, b: Vec2) -> float { return a.x*b.x + a.y*b.y; }
distance :: (a: Vec2, b: Vec2) -> float { return length(a - b); }
lerp :: (a: Vec2, b: Vec2, t: float) -> Vec2 { return .{lerp(a.x, b.x, t), lerp(a.y, b.y, t)}; }

Vec3 :: struct {
    x, y, z: float;
}

operator+ :: (a: Vec3, b: Vec3) -> Vec3 { return .{a.x + b.x, a.y + b.y, a.z + b.z}; }
operator- :: (a: Vec3, b: Vec3) -> Vec3 { return .{a.x - b.x, a.y - b.y, a.z - b.z}; }
operator* :: (a: Vec3, b: Vec3) -> Vec3 { return .{a.x * b.x, a.y * b.y, a.z * b.z}; }
operator* :: (a: Vec3, b: float) -> Vec3 { return .{a.x * b, a.y * b, a.z * b}; }

operator- :: (a: Vec3) -> Vec3 { return .{-a.x, -a.y, -a.z}; }

length :: (a: Vec3) -> float { return sqrt(a.x*a.x + a.y*a.y + a.z*a.z); }
dot :: (a: Vec3, b: Vec3) -> float { return a.x*b.x + a.y*b.y + a.z*b.z; }
distance :: (a: Vec3, b: Vec3) -> float { return length(a - b); }

cross :: (a: Vec3, b: Vec3) -> Vec3 {
    return .{
        a.y * b.z - a.z * b.y,
        a.z * b.x - a.x * b.z,
        a.x * b.y - a.y * b.x
    };
}

Vec4 :: struct {
    x, y, z, w: float;
    
#place x; xyz: Vec3;
}

operator+ :: (a: Vec4, b: Vec4) -> Vec4 { return .{a.x + b.x, a.y + b.y, a.z + b.z, a.w + b.w}; }
operator- :: (a: Vec4, b: Vec4) -> Vec4 { return .{a.x - b.x, a.y - b.y, a.z - b.z, a.w - b.w}; }
operator* :: (a: Vec4, b: Vec4) -> Vec4 { return .{a.x * b.x, a.y * b.y, a.z * b.z, a.w * b.w}; }
operator* :: (a: Vec4, b: float) -> Vec4 { return .{a.x * b, a.y * b, a.z * b, a.w * b}; }

length :: (a: Vec4) -> float { return sqrt(a.x*a.x + a.y*a.y + a.z*a.z + a.w*a.w); }
dot :: (a: Vec4, b: Vec4) -> float { return a.x*b.x + a.y*b.y + a.z*b.z + a.w*b.w; }
distance :: (a: Vec4, b: Vec4) -> float { return length(a - b); }

normalize :: (a: $T) -> T {
    l := length(a);
    if l == 0 return a;
    ilength := 1.0 / l;
    return a * ilength;
}

Mat4 :: struct {
    _00, _01, _02, _03 : float;
    _10, _11, _12, _13 : float;
    _20, _21, _22, _23 : float;
    _30, _31, _32, _33 : float;
    
#place _00; v: [4] Vec4 = ---; // These are row vectors.
#place _00; coef: [4][4] float   = ---;
#place _00; floats: [16] float   = ---;
}

mat4_identity :: () -> Mat4 {
    out: Mat4;
    out._00 = 1;
    out._11 = 1;
    out._22 = 1;
    out._33 = 1;
    return out;
}

mat4_translation :: (v: Vec3) -> Mat4 {
    m := mat4_identity();
    
    m._03 = v.x;
    m._13 = v.y;
    m._23 = -v.z;
    
    return m;
}

mat4_scale :: (v: Vec3) -> Mat4 {
    m := mat4_identity();
    
    m._00 = v.x;
    m._11 = v.y;
    m._22 = v.z;
    
    return m;
}

mat4_euler_rotation :: (angles: Vec3) -> Mat4 {
    x := mat4_identity();
    y := mat4_identity();
    z := mat4_identity();
    
    x._11 = cos(angles.x);
    x._12 = -sin(angles.x);
    x._21 = sin(angles.x);
    x._22 = cos(angles.x);
    
    y._00 = cos(angles.y);
    y._02 = sin(angles.y);
    y._20 = -sin(angles.y);
    y._22 = cos(angles.y);
    
    z._00 = cos(angles.z);
    z._01 = -sin(angles.z);
    z._10 = sin(angles.z);
    z._11 = cos(angles.z);
    
    return z * y * x;
}

vec3_rotate :: (v: Vec3, m: Mat4) -> Vec3 {
    result: Vec3;
    result.x = m._00 * v.x + m._01 * v.y + m._02 * v.z + m._03 * 1;
    result.y = m._10 * v.x + m._11 * v.y + m._12 * v.z + m._13 * 1;
    result.z = m._20 * v.x + m._21 * v.y + m._22 * v.z + m._23 * 1;
    return result;
}

mat4_rotation :: (q: Quaternion) -> Mat4 {
    m: Mat4;
    
    xs := q.x * 2;
    ys := q.y * 2;
    zs := q.z * 2;
    
    wx := q.w * xs;
    wy := q.w * ys;
    wz := q.w * zs;
    
    _xx := q.x * xs;
    xy := q.x * ys;
    xz := q.x * zs;
    
    yy := q.y * ys;
    yz := q.y * zs;
    zz := q.z * zs;
    
    m._00 = 1.0 - (yy + zz);
    m._01 = xy - wz;
    m._02 = xz + wy;
    
    m._10 = xy + wz;
    m._11 = 1.0 - (_xx + zz);
    m._12 = yz - wx;
    
    m._20 = xz - wy;
    m._21 = yz + wx;
    m._22 = 1.0 - (_xx + yy);
    
    m._33 = 1;
    
    return m;
}

mat4_inverse :: (m: Mat4) -> Mat4, bool {
    matr := m; 
    
    k, l, ll: int = ---;
    icol := 0;
    irow := 0;
    
    indxc: [4] int = ---;
    indxr: [4] int = ---;
    ipiv:  [4] int;
    
    ident := mat4_identity();
    
    for i: 0..3 {
        big : float64 = 0.0;
        for j: 0..3 {
            if ipiv[j] != 1 {  // @Cleanup: Invert this nesting w/ a continue.
                for k: 0..3 {
                    if ipiv[k] == 0 {
                        if abs(matr.coef[j][k]) >= big {
                            big = abs(matr.coef[j][k]);
                            irow=j;
                            icol=k;
                        }
                    } else {
                        if ipiv[k] > 1  return ident, false;
                    }
                }
            }
        }
        
        ipiv[icol] += 1;
        
        if irow != icol {
            for l: 0..3 Swap(*matr .coef[irow][l], *matr .coef[icol][l]);
            for l: 0..3 Swap(*ident.coef[irow][l], *ident.coef[icol][l]);
        }
        
        indxr[i] = irow;
        indxc[i] = icol;
        
        if matr.coef[icol][icol] == 0.0  return ident, false;
        pivinv : float64 = 1 / matr.coef[icol][icol];
        matr.coef[icol][icol] = 1;
        
        //
        // @Robustness: The auto-casts here on pivinv are losing us
        // precision. How do we notate that we want the * to happen
        // as float64 even though the thing on the left is float32?
        //               -jblow, 1 February 2017.
        //
        // WARNING: I may have destabilized the results of this routine!!!
        //
        
        // Do not use *= here, because we want to do the multiply in float64,
        // then cast to float32.
        for l: 0..3 { matr .coef[icol][l] = cast(float32)(matr .coef[icol][l] * pivinv); }
        for l: 0..3 { ident.coef[icol][l] = cast(float32)(ident.coef[icol][l] * pivinv); }
        
        for ll: 0..3 {
            if ll != icol {
                dum := matr.coef[ll][icol];
                matr.coef[ll][icol] = 0;
                
                for l: 0..3 { matr .coef[ll][l] -= xx (matr .coef[icol][l]*dum); }
                for l: 0..3 { ident.coef[ll][l] -= xx (ident.coef[icol][l]*dum); }
            }
        }
    }
    
    for < l: 3..0 {
        if indxr[l] != indxc[l] {
            for k: 0..3 {
                Swap(*matr.coef[k][indxr[l]], *matr.coef[k][indxc[l]]);
            }
        }
    }
    
    return ident, true;
}

get_rotation :: (using m: Mat4) -> Quaternion {  // @Polymorph: Make it work on Matrix4 || Matrix3.
    
    // Algorithm in Ken Shoemake's article in 1987 SIGGRAPH course notes
    // article "Quaternion Calculus and Fast Animation".
    
    // @Cleanup: We are kinda cheating here because AnyMatrix3 doesn't
    // define coef[], because we don't have a way to do that with 'interface'
    // yet. Something to think about ... !
    
    q: Quaternion = ---;
    trace := _00 + _11 + _22;
    
    if trace > 0 {
        // |w| > 1/2, may as well choose w > 1/2
        s := sqrt(trace + 1);  // 2w
        
        q.w = s * 0.5;
        s = 0.5 / s;       // 1/(4w)
        
        q.x = (coef[2][1] - coef[1][2]) * s;
        q.y = (coef[0][2] - coef[2][0]) * s;
        q.z = (coef[1][0] - coef[0][1]) * s;
    } else {
        // |w| <= 1/2
        i := 0;
        if (coef[1][1] > coef[0][0]) i = 1;
        if (coef[2][2] > coef[i][i]) i = 2;
        
        j := (1 << i) & 3; // i + 1 modulo 3.
        k := (1 << j) & 3;
        
        s := sqrt(coef[i][i] - coef[j][j] - coef[k][k] + 1);
        
        q.component[i] = s * 0.5;
        s = 0.5 / s;
        q.component[j] = (coef[i][j] + coef[j][i]) * s;
        q.component[k] = (coef[k][i] + coef[i][k]) * s;
        q.w = (coef[k][j] - coef[j][k]) * s;
    }
    
    //assert(coef[3][3] == 1.0);
    //if (coef[3][3] != 1.0) q = q.scale(1.0 / sqrt(coef[3][3]));
    
    normalize_or_identity(*q);
    return q;
}

mat4_decompose :: (m: Mat4) -> Vec3, Quaternion, Vec3 {
    translation := Vec3.{
        m._03,
        m._13,
        m._23
    };
    
	rotation := get_rotation(m);
    
	scale := Vec3.{
        length(Vec3.{m._11, m._21, m._31}),
        length(Vec3.{m._12, m._22, m._32}),
        length(Vec3.{m._13, m._23, m._33}),
    };
    
	return translation, rotation, scale;
}

multiply :: (m: Mat4, n: Mat4) -> Mat4 {
    result: Mat4 = ---;
    
    result._00 = m._00 * n._00 + m._01 * n._10 + m._02 * n._20 + m._03 * n._30;
    result._01 = m._00 * n._01 + m._01 * n._11 + m._02 * n._21 + m._03 * n._31;
    result._02 = m._00 * n._02 + m._01 * n._12 + m._02 * n._22 + m._03 * n._32;
    result._03 = m._00 * n._03 + m._01 * n._13 + m._02 * n._23 + m._03 * n._33;
    
    result._10 = m._10 * n._00 + m._11 * n._10 + m._12 * n._20 + m._13 * n._30;
    result._11 = m._10 * n._01 + m._11 * n._11 + m._12 * n._21 + m._13 * n._31;
    result._12 = m._10 * n._02 + m._11 * n._12 + m._12 * n._22 + m._13 * n._32;
    result._13 = m._10 * n._03 + m._11 * n._13 + m._12 * n._23 + m._13 * n._33;
    
    result._20 = m._20 * n._00 + m._21 * n._10 + m._22 * n._20 + m._23 * n._30;
    result._21 = m._20 * n._01 + m._21 * n._11 + m._22 * n._21 + m._23 * n._31;
    result._22 = m._20 * n._02 + m._21 * n._12 + m._22 * n._22 + m._23 * n._32;
    result._23 = m._20 * n._03 + m._21 * n._13 + m._22 * n._23 + m._23 * n._33;
    
    result._30 = m._30 * n._00 + m._31 * n._10 + m._32 * n._20 + m._33 * n._30;
    result._31 = m._30 * n._01 + m._31 * n._11 + m._32 * n._21 + m._33 * n._31;
    result._32 = m._30 * n._02 + m._31 * n._12 + m._32 * n._22 + m._33 * n._32;
    result._33 = m._30 * n._03 + m._31 * n._13 + m._32 * n._23 + m._33 * n._33;
    
    return result;
}

multiply :: (m: Mat4, v: Vec4) -> Vec4 {
    result: Vec4 = ---;
    result.x = m._00 * v.x + m._01 * v.y + m._02 * v.z + m._03 * v.w;
    result.y = m._10 * v.x + m._11 * v.y + m._12 * v.z + m._13 * v.w;
    result.z = m._20 * v.x + m._21 * v.y + m._22 * v.z + m._23 * v.w;
    result.w = m._30 * v.x + m._31 * v.y + m._32 * v.z + m._33 * v.w;
    return result;
}

append :: (v: Vec3, w: float) -> Vec4 {
    return .{v.x, v.y, v.z, w};
}

operator * :: (a: Mat4, b: Vec4) -> Vec4 {
    return inline multiply(a, b);
}

operator * :: (a: Mat4, b: Mat4) -> Mat4 {
    return inline multiply(a, b);
}

mat4_projection :: (fov: float, aspect: float, z_near: float, z_far: float) -> Mat4 {
    result := mat4_identity();
    
    tan_theta := tan(fov * 0.5);
    cot_theta := 1 / tan_theta;
    
    f := z_far;
    n := z_near;
    denom := 1 / (f - n);
    
    result._00 = cot_theta / aspect;
    result._11 = cot_theta;
    result._22 = -(f + n) * denom;
    result._23 = -2 * f * n * denom;
    result._32 = -1;
    result._33 = 0;
    
    return result;
}

cross_product :: (a: Vec3, b: Vec3) -> Vec3 {
    n: Vec3 = ---;
    
    n.x = a.y * b.z - a.z * b.y;
    n.y = a.z * b.x - a.x * b.z;
    n.z = a.x * b.y - a.y * b.x;
    
    return n;
}

rotate :: (v: Vec3, q: Quaternion) -> Vec3 {
    v3 := Vec3.{q.xyz.x, q.xyz.y, q.xyz.z};
    t := cross_product(v3, v) * 2.0;
    return v + t * q.w + cross_product(v3, t);
}

#scope_file

#import "Basic";
#import "Math";