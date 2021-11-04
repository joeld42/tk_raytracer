// mostly copied from 
// https://github.com/michal-z/zig-gamedev/blob/main/libs/common/vectormath.zig
// for learning. I'll just replace this with that file eventually

const std = @import("std");
const assert = std.dbg.assert;
const math = std.math;

const epsilon : f32  = 0.00001;

pub const Vec3 = extern struct {
    v: [3]f32,

    pub inline fn init( x: f32, y : f32, z: f32 ) Vec3 {
        return .{ .v = [_]f32{ x, y, z  } };
    }

    pub inline fn initZero() Vec3 {
        const static = struct {
            const zero = init( 0.0, 0.0, 0.0 );
        };
        return static.zero;
    }

    pub inline fn checkZero( a:Vec3 ) bool {
        const s = 0.0000001;
        return ( (@fabs(a.v[0]) < s ) and (@fabs(a.v[1]) < s ) and (@fabs(a.v[2]) < s ) );
    }

    pub inline fn dot( a: Vec3, b: Vec3 ) f32 {
        return a.v[0] * b.v[0] + a.v[1] * b.v[1] + a.v[2]*b.v[2];
    }

    pub inline fn cross( a: Vec3, b:Vec3 ) f32 {
        return . {
            .v = [_]f32{
                a.v[1] * b.v[2] - a.v[2] * b.v[1],
                a.v[2] * b.v[0] - a.v[0] * b.v[2],
                a.v[0] * b.v[1] - a.v[1] * b.v[0]
            },
        };
    }

    pub inline fn add( a: Vec3, b: Vec3 ) Vec3 {
        return .{ .v = [_]f32{ a.v[0] + b.v[0], a.v[1] + b.v[1], a.v[2]+b.v[2] }};
    }

    pub inline fn sub( a: Vec3, b: Vec3 ) Vec3 {
        return .{ .v = [_]f32{ a.v[0] - b.v[0], a.v[1] - b.v[1], a.v[2]-b.v[2] }};
    }

    pub inline fn mul( a: Vec3, b: Vec3 ) Vec3 {
        return .{ .v = [_]f32{ a.v[0]*b.v[0], a.v[1]*b.v[1], a.v[2]*b.v[2] }};
    }

    pub inline fn mul_s( a: Vec3, s: f32 ) Vec3 {
        return .{ .v = [_]f32{ a.v[0]*s, a.v[1]*s, a.v[2]*s }};
    }


    pub inline fn length( a:Vec3 ) f32 {
        return math.sqrt(dot(a, a ));
    }

    pub inline fn lengthSq( a: Vec3 ) f32 {
        return dot(a, a);
    }

    pub inline fn normalize(a: Vec3) Vec3 {
        const len = length(a);
        // assert(!math.approxEq(f32, len, 0.0, epsilon));
        const rcplen = 1.0 / len;
        return .{ .v = [_]f32{ rcplen * a.v[0], rcplen * a.v[1], rcplen * a.v[2] } };
    }

    pub inline fn reflect( v : Vec3, n : Vec3 ) Vec3 {
        return  Vec3.sub( v, Vec3.mul_s( n, 2.0 * Vec3.dot( v, n ) ) );
    }

    pub inline fn refract( uv : Vec3, n : Vec3, etai_over_etat : f32 ) Vec3 {
        const cos_theta = math.min( Vec3.dot( Vec3.mul_s( uv, -1.0), n ), 1.0 );
        const r_out_perp = Vec3.mul_s( Vec3.add( Vec3.mul_s( n, cos_theta ), uv ), etai_over_etat );
        const r_out_parallel_mag = -math.sqrt( math.fabs(1.0 - Vec3.lengthSq( r_out_perp ) ));
        const r_out_parallel = Vec3.mul_s( n, r_out_parallel_mag );
        return Vec3.add( r_out_perp, r_out_parallel );
    }

};