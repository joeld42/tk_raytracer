
const vm = @import("vecmath_j.zig");

const std = @import("std");
const math = std.math;

const Vec3 = vm.Vec3;

const material = @import("material.zig");
const Material = material.Material;


pub const Ray = struct {
    orig : Vec3,
    dir : Vec3,

    pub inline fn at( ray: Ray, t: f32 ) Vec3 {
        var result : Vec3 = Vec3.add( ray.orig ,Vec3.mul_s( ray.dir, t ) );
        return result;
    }
};

pub const HitRecord = struct {
    point : Vec3,
    normal : Vec3,
    t : f32,
    front_face : bool,
    mtl : *const Material,
};


pub const Camera = struct {
    const Self = @This();

    origin : Vec3,
    lower_left_corner : Vec3,
    horizontal : Vec3,
    vertical : Vec3,

    pub fn init( 
            lookfrom : Vec3,
            lookat : Vec3,
            up : Vec3,
            vertical_fov : f32, aspect_ratio : f32
        ) Camera {

        //const aspect_ratio : f32 = 16.0 / 9.0;
        const theta = vertical_fov * (math.pi / 180.0);
        const h = math.tan( theta / 2.0 );
        const viewport_height : f32 = h;
        const viewport_width : f32 = aspect_ratio * viewport_height;
        //const focal_length : f32 = 1.0;

        const w = Vec3.normalize( Vec3.sub( lookfrom, lookat ));
        const u = Vec3.normalize( Vec3.cross( up, w ));
        const v = Vec3.cross( w, u );

        const origin = lookfrom;
        const horizontal = Vec3.mul_s( u, viewport_width );
        const vertical = Vec3.mul_s( v, viewport_height );    

        const half_h : Vec3 = Vec3.mul_s( horizontal, 0.5 );
        const half_v : Vec3 = Vec3.mul_s( vertical, 0.5 );
        //const cam_z : Vec3 = Vec3.init( 0, 0, focal_length );

        const o_minus_h = Vec3.sub( origin, half_h );
        const omh_minus_v = Vec3.sub( o_minus_h, half_v );    
        const lower_left_corner : Vec3 = Vec3.sub( omh_minus_v, w );

        return .{ 
            .origin = origin,
            .horizontal = horizontal,
            .vertical = vertical,
            .lower_left_corner = lower_left_corner
        };
    }

    pub fn genRay( self: Self, u : f32, v : f32 ) Ray {
        
        var rd : Vec3 = Vec3.add( self.lower_left_corner, Vec3.mul_s( self.horizontal, u ) );
        rd = Vec3.add( rd, Vec3.mul_s( self.vertical, v ) );
        rd = Vec3.sub( rd, self.origin );

        const r : Ray = .{ .orig = self.origin,
                            .dir = rd };
        return r;

    }

};