const std = @import("std");
const vm = @import("vecmath");
const mem = std.mem;

const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const math = std.math;
const Vec3 = vm.Vec3;


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
};

pub const Sphere = struct {
    center : Vec3,
    radius : f32,
};

pub const Scene = struct {
    const Self = @This();

    sphereList : ArrayList(Sphere),

    pub fn init( alloc : *Allocator ) Scene {
        return .{ .sphereList = ArrayList(Sphere).init(alloc) };
    }

    pub fn deinit(self: Self) void {
        self.sphereList.deinit();
    }
};

pub fn writePixel(  file : std.fs.File, pixel : Vec3  ) anyerror!void {
    var ir : u8 = @floatToInt( u8, 255.999 * pixel.v[0] );
    var ig : u8 = @floatToInt( u8, 255.999 * pixel.v[1] );
    var ib : u8 = @floatToInt( u8, 255.999 * pixel.v[2] );
    _ = try file.writer().print("{d} {d} {d}\n", .{ ir, ig, ib } );
}

pub fn sphereIsectRay( ray : Ray, sphere : Sphere, t_min : f32, t_max : f32 ) ?HitRecord {

    const oc = Vec3.sub( ray.orig, sphere.center );
    const a = Vec3.lengthSq( ray.dir );
    const half_b = Vec3.dot( oc, ray.dir );
    const c = Vec3.lengthSq( oc ) - sphere.radius*sphere.radius;
    const discriminant = half_b*half_b - a*c;
    if (discriminant < 0) {
        return null;
    }             
    const sqrt_d = math.sqrt( discriminant );

    // Find the closest root in the accepted range
    var root = ( -half_b - sqrt_d ) / a;
    if ( (root < t_min) or (t_max < root) ) {
        root = (-half_b + sqrt_d) / a;
        if (root < t_min) {
            return null;
        }
    }

    const p = ray.at( root );
    const n = Vec3.mul_s( (Vec3.sub(p, sphere.center) ), 1.0/sphere.radius);
    const front = Vec3.dot( ray.dir, n ) < 0.0;
    return HitRecord {
        .t = root,
        .point = p,
        .normal = if (front) n else Vec3.mul_s( n, -1.0 ),
        .front_face = front
    };
}

pub fn sceneIsectRay( ray : Ray, scene : Scene, t_min : f32, t_max : f32 ) ?HitRecord {    
    var best_hit : ?HitRecord = null;

    // Check any spheres in the scene
    for ( scene.sphereList.items) |sph| {
        var maybe_hit : ?HitRecord = sphereIsectRay( ray, sph, t_min, t_max );
        if ( maybe_hit != null) {
            const hit = maybe_hit.?;
            if (best_hit == null) {
                best_hit = hit;
            } else {
                const curr_best_hit = best_hit.?;
                if (hit.t < curr_best_hit.t) {
                    best_hit = hit;
                }
            }
        }
    }
    return best_hit;
}

pub fn traceRay( ray : Ray, scene : Scene ) Vec3 {

    // const sph = Sphere {
    //     .center = Vec3.init( 0, 0, -1 ),
    //     .radius = 0.5,
    // };

    const hit : ?HitRecord = sceneIsectRay( ray, scene, 0.0, 100.0 );
    if (hit != null) {
        const hitSph = hit.?;
        const N = hitSph.normal;
        //std.log.info("N is {d} {d} {d} len {d}",
        //                .{ N.v[0], N.v[1], N.v[2], N.length() } );
        return Vec3.mul_s( Vec3.init( N.v[0]+1, N.v[1]+1, N.v[2]+1), 0.5 );
    }

    // if (t > 0.0) {
    //     var N = Vec3.normalize( Vec3.sub( ray.at( t ), Vec3.init( 0, 0,-1) ) );
    //     return Vec3.mul_s( Vec3.init( N.v[0]+1, N.v[1]+1, N.v[2]+1), 0.5 );
    // }

    // Background, sky color    
    var dir_n : Vec3 = Vec3.normalize( ray.dir );
    var sky_t : f32 = 0.5 * (dir_n.v[1] + 1.0);

    const static = struct {
            const sky = Vec3.init( 0.5, 0.7, 1.0 );
            const ground = Vec3.init( 1.0, 1.0, 1.0 );
            //const sky = Vec3.init( 1.0, 0.0, 0.0 );
            //const ground = Vec3.init( 0.0, 0.0, 1.0 );
        };

    return Vec3.add( Vec3.mul_s( static.ground, 1.0 - sky_t ),
                     Vec3.mul_s( static.sky, sky_t ) );
}

pub fn traceScene( alloc : *Allocator ) anyerror!void {

    // Image
    const aspect_ratio : f32 = 16.0 / 9.0;
    const image_width: usize = 400;
    const image_height: usize = @floatToInt( usize, @intToFloat( f32, image_width) / aspect_ratio );

    const maxcol : f32 = @intToFloat( f32, image_width-1 );
    const maxrow : f32 = @intToFloat( f32, image_height-1 );

    // Camera
    const viewport_height : f32 = 2.0;
    const viewport_width : f32 = aspect_ratio * viewport_height;
    const focal_length : f32 = 1.0;

    const origin = Vec3.initZero();
    const horizontal = Vec3.init( viewport_width, 0, 0 );
    const vertical = Vec3.init( 0, viewport_height, 0 );    

    // lower_left_corner = origin - horizontal/2 - vertical/2 - vec3(0,0, focal_len );
    const half_h : Vec3 = Vec3.mul_s( horizontal, 0.5 );
    const half_v : Vec3 = Vec3.mul_s( vertical, 0.5 );
    std.log.info("half_v is {d} {d} {d}", .{ half_v.v[0], half_v.v[1], half_v.v[2] } );
    const cam_z : Vec3 = Vec3.init( 0, 0, focal_length );

    const o_minus_h = Vec3.sub( origin, half_h );
    const omh_minus_v = Vec3.sub( o_minus_h, half_v );    
    const lower_left_corner : Vec3 = Vec3.sub( omh_minus_v, cam_z );

    std.log.info( "LLC is {d} {d} {d}", . { lower_left_corner.v[0], lower_left_corner.v[1], lower_left_corner.v[2] });

    // Scene
    const sph = Sphere {
        .center = Vec3.init( 0, 0, -1 ),
        .radius = 0.5,
    };
    var scene = Scene.init( alloc );
    defer scene.deinit();
    try scene.sphereList.append( sph );

    // Scene output
    const file = try std.fs.cwd().createFile(
        "image.ppm", .{ .read = true },
    );
    defer file.close();

    _ = try file.writer().print("P3\n", .{} );
    _ = try file.writer().print("{d} {d}\n255\n", .{  image_width, image_height  });

    var j : usize = image_height-1;
    while ( true ) : ( j = j - 1) {
        var i : usize = 0;
        if (j % 10 == 0) {
            std.log.info("Scanlines remaining: {d}", .{j} );
        }
        while ( i < image_width ) : (i += 1 ) {

            var u : f32 = @intToFloat( f32, i ) / maxcol;
            var v : f32 = @intToFloat( f32, j ) / maxrow;

            var rd : Vec3 = Vec3.add( lower_left_corner, Vec3.mul_s( horizontal, u ) );
            rd = Vec3.add( rd, Vec3.mul_s( vertical, v ) );
            rd = Vec3.sub( rd, origin );

            const r : Ray = .{ .orig = origin,
                               .dir = rd };

            var color : Vec3 = traceRay( r, scene );
            _ = try writePixel( file, color );

        }
        if (j==0) break;
    }
}

pub fn main() anyerror!void {

    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpalloc.deinit());

    // const alloc = &gpalloc.allocator;

    //std.log.info("All your codebase are belong to us.", .{});
    traceScene( &gpalloc.allocator ) catch |err| {
        std.log.err("traceScene failed with error {s}.", .{ err } );
        return;
    };
    std.log.info( "Wrote file.", .{} );
}

test "basic test" {
    try std.testing.expectEqual(10, 3 + 7);
}
