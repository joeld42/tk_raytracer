const std = @import("std");
const mem = std.mem;

const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const camera = @import("camera.zig");
const Camera = camera.Camera;
const Ray = camera.Ray;
const HitRecord = camera.HitRecord;

const vm = @import("vecmath_j.zig");
const math = std.math;
const Vec3 = vm.Vec3;

const material = @import("material.zig");
const Material = material.Material;

const Random = std.rand.DefaultPrng;
const util = @import("utils.zig");

pub const Sphere = struct {
    center : Vec3,
    radius : f32,
    material : *const Material,    
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
        .front_face = front,
        .mtl = sphere.material
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

pub fn traceRay( ray : Ray, scene : Scene, rng : *Random, depth: i32 ) Vec3 {

    if (depth <= 0) {
        return Vec3.initZero();
    }

    const hit : ?HitRecord = sceneIsectRay( ray, scene, 0.0001, 1000.0 );
    if (hit != null) {
        const hitSph = hit.?;

        // const targetDir = util.randomInHemisphere( rng, hitSph.normal );
        // const bounceRay : Ray = .{ .orig = hitSph.point,
        //                             .dir = targetDir };
        // var bounce = traceRay(  bounceRay, scene, rng, depth-1 );
        // return Vec3.mul( bounce, hitSph.mtl.albedo );

        const result = hitSph.mtl.scatter( rng, ray, hitSph );
        if (result != null) {
            const resultScatter = result.?;
            
            var bounce = traceRay(  resultScatter.scatterRay, 
                            scene, rng, depth-1 );
            return Vec3.mul( resultScatter.attenuation, bounce );
        } else {
            return Vec3.initZero();
        }
    }

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

    var rng = Random.init( 0 );

    // Image
    //const aspect_ratio : f32 = 16.0 / 9.0;
    const aspect_ratio : f32 = 3.0 / 2.0;
    const image_width: usize = 800;
    //const image_width: usize = 100; // small for testing
    const image_height: usize = @floatToInt( usize, @intToFloat( f32, image_width) / aspect_ratio );
    const samples_per_pixel : usize = 200;
    const max_depth : i32 = 50;

    const maxcol : f32 = @intToFloat( f32, image_width-1 );
    const maxrow : f32 = @intToFloat( f32, image_height-1 );

    // Camera
    const lookfrom = Vec3.init( 13, 2, 3);
    const lookat = Vec3.init( 0, 0, 0 );
    //const focus_dist = Vec3.length( Vec3.sub( lookfrom, lookat ) );
    const focus_dist = 10.0;
    const aperture :f32 = 0.01;
    const cam : Camera = Camera.init( 
        lookfrom, lookat, Vec3.init( 0, 1, 0 ), // up vector
        40.0, aspect_ratio, aperture, focus_dist );

    // Scene    
    var scene = Scene.init( alloc );
    defer scene.deinit();

    // ground    
    const mtlGround = Material.makeLambertian( Vec3.init( 0.5, 0.8, 0.5  ) );    
    try scene.sphereList.append( Sphere {
        .center = Vec3.init( 0, -1000, 0 ),
        .radius = 1000.0,
        .material = &mtlGround,
    } );

    // Big Spheres
    const mtlBigSphere1 = Material.makeGlass( Vec3.init( 1,1,1), 1.5 );
    try scene.sphereList.append( Sphere {
        .center = Vec3.init( 0, 1, 0 ),
        .radius = 1.0,    
        .material = &mtlBigSphere1,    
    } );

    const mtlBigSphere2 = Material.makeLambertian( Vec3.init( 0.4, 0.2, 0.1) );
    try scene.sphereList.append( Sphere {
        .center = Vec3.init( -4, 1, 0 ),
        .radius = 1.0,    
        .material = &mtlBigSphere2,    
    } );

    const mtlBigSphere3 = Material.makeMetallic( Vec3.init( 0.7, 0.6, 0.5), 0.0 );
    try scene.sphereList.append( Sphere {
        .center = Vec3.init( 4, 1, 0 ),
        .radius = 1.0,    
        .material = &mtlBigSphere3,
    } );

    // Allocate all the materials to an arena
    var mtl_alloc = std.heap.ArenaAllocator.init( alloc );
    defer mtl_alloc.deinit();


    var a : i32 = -11;
    while ( a < 11) : ( a += 1) {
        var b : i32 = -11;
        while ( b < 11) : ( b += 1) {
            
            const center = Vec3.init( @intToFloat( f32, a) + rng.random.float( f32 ) * 0.9,
                                      0.2,
                                      @intToFloat( f32, b) + rng.random.float( f32 ) * 0.9 );

            var choose_mat = rng.random.float( f32 );            
            var mtlSphere = try mtl_alloc.allocator.create( Material );            

            if (choose_mat < 0.8) {
                // Diffuse
                const color1 = util.randomVec3( &rng );
                const albedo= Vec3.init( color1.v[0]*color1.v[0],
                                    color1.v[1]*color1.v[1],
                                    color1.v[2]*color1.v[2] );
                mtlSphere.* = Material.makeLambertian( albedo );
            } else if (choose_mat < 0.95 ) {
                // Metal
                const roughness = util.randomRange( &rng, 0.0, 0.5 );
                const grey = util.randomRange( &rng, 0.5, 1.0 );
                const albedo= Vec3.init( grey, grey, grey );
                mtlSphere.* = Material.makeMetallic( albedo, roughness );
            } else {
                // Glass
                const color1 = util.randomVec3( &rng );
                const absorption= Vec3.init( color1.v[0]*color1.v[0],
                                    color1.v[1]*color1.v[1],
                                    color1.v[2]*color1.v[2] );
                mtlSphere.* = Material.makeGlass( absorption, 0.2 );
            }

            try scene.sphereList.append( Sphere {
                .center = center,
                .radius = 0.2,    
                .material = mtlSphere,
            } );
            
        }
    }

    // Scene output
    const file = try std.fs.cwd().createFile(
        "image.ppm", .{ .read = true },
    );
    defer file.close();

    _ = try file.writer().print("P3\n", .{} );
    _ = try file.writer().print("{d} {d}\n255\n", .{  image_width, image_height  });

    std.debug.print("Sizeof Sphere is {d}\n", .{ @sizeOf(Sphere) } );

    var j : usize = image_height-1;
    while ( true ) : ( j = j - 1) {
        var i : usize = 0;
        if (j % 10 == 0) {
            //std.log.info("Scanlines remaining: {d}", .{j} );
            std.debug.print("Scanlines remaining: {d}\n", .{j} );
        }
        while ( i < image_width ) : (i += 1 ) {
            
            var color_accum = Vec3.initZero();
            var s : usize = 0;
            while ( s < samples_per_pixel) : ( s += 1) {

                // jitter sample
                const uu = rng.random.float( f32 );
                const vv = rng.random.float( f32 );

                var u : f32 = (@intToFloat( f32, i ) + uu) / maxcol;
                var v : f32 = (@intToFloat( f32, j ) + vv) / maxrow;


                const r : Ray = cam.genRay( &rng, u, v );
                var sample_color : Vec3 = traceRay( r, scene, &rng, max_depth );

                color_accum = Vec3.add( color_accum, sample_color );
            }
            var color = Vec3.mul_s( color_accum, 1.0 / @intToFloat( f32, samples_per_pixel) );
            var colorGamma = Vec3.init( math.sqrt( color.v[0] ),
                                            math.sqrt( color.v[1] ),    
                                            math.sqrt( color.v[2] ) );

            _ = try writePixel( file, colorGamma );

        }
        if (j==0) break;
    }
}

pub fn main() anyerror!void {

    var gpalloc = std.heap.GeneralPurposeAllocator(.{}){};
    defer std.debug.assert(!gpalloc.deinit());

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
