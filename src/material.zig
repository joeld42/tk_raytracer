const std = @import("std");
const mem = std.mem;
const math = std.math;
const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;

const vm = @import("vecmath_j.zig");
const Vec3 = vm.Vec3;

const camera = @import("camera.zig");
const Camera = camera.Camera;
const Ray = camera.Ray;
const HitRecord = camera.HitRecord;

const util = @import("utils.zig");

const Random = std.rand.DefaultPrng;

pub const ScatterResult = struct {
    scatterRay : Ray,
    attenuation : Vec3
};

// unlike the rtiaw book, i'm going with an ubershader approach
pub const Material = struct {
    const Self = @This();

    metalness : f32,
    glassness : f32,
    ior : f32,
    albedo: Vec3,
    roughness: f32,
    
    pub fn makeLambertian( albedo : Vec3 ) Material {
        return .{
            .glassness = 0.0,
            .ior = 1.0,
            .metalness = 0.0,
            .albedo = albedo,
            .roughness = 0.9
        };
    }

    pub fn makeMetallic( albedo : Vec3, roughness : f32 ) Material {
        return .{
            .glassness = 0.0,
            .ior = 1.0,
            .metalness = 1.0,
            .albedo = albedo,
            .roughness = roughness
        };
    }

    pub fn makeGlass( albedo : Vec3, ior : f32 ) Material {
        return .{
            .glassness = 1.0,
            .ior = ior,
            .metalness = 0.0,
            .albedo = albedo,
            .roughness = 0.9
        };
    }

    pub fn scatter( self : Self, rng: *Random, ray_in: Ray, hit : HitRecord ) ?ScatterResult {

        // todo probability 
        if (self.glassness > 0.5 ) {

            // dialectric glass
            const unit_dir = Vec3.normalize( ray_in.dir );
            const ray_ior : f32 = if (hit.front_face) (1.0/self.ior) else self.ior;

            const cos_theta = math.min( Vec3.dot( Vec3.mul_s( unit_dir, -1.0), hit.normal ), 1.0 );
            const sin_theta = math.sqrt( 1.0 - cos_theta*cos_theta );

            const cannot_refract = (ray_ior * sin_theta) > 1.0;


            const scatter_dir = if ((cannot_refract) or 
                                    (reflectance_schlick( cos_theta, ray_ior ) > rng.random.float( f32 ) ))
                                Vec3.reflect( unit_dir, hit.normal ) 
                            else Vec3.refract( unit_dir, hit.normal, ray_ior );

            //const refracted = Vec3.refract( unit_dir, hit.normal, ray_ior );
            return ScatterResult {                 
                .scatterRay = Ray { .orig = hit.point, .dir = scatter_dir },
                .attenuation = self.albedo
                //.attenuation = Vec3.init (1.0, 1.0, 1.0 )
            };

        } else if (self.metalness > 0.5 ) {
            // dialectric metal
            const reflected = Vec3.reflect( Vec3.normalize( ray_in.dir ), hit.normal );            
            return ScatterResult { .scatterRay = Ray { .orig = hit.point, 
                                                        .dir = Vec3.add( reflected, Vec3.mul_s( util.randomUnitVector( rng ), self.roughness) ) },
                               .attenuation = self.albedo
                             };
        } else {
            // lambertian
            var scatter_dir = Vec3.add( hit.normal, util.randomUnitVector( rng ) ); 
            
            if (Vec3.checkZero(scatter_dir)) {
                scatter_dir = hit.normal;
            }

            return ScatterResult { .scatterRay = Ray { .orig = hit.point, .dir =  scatter_dir },
                               .attenuation = self.albedo
                             };
        }

        
    }

    pub inline fn reflectance_schlick( cosine : f32, ref_idx : f32 ) f32 {
        const r00 = (1.0-ref_idx) / ( 1.0 + ref_idx);
        const r0 = r00*r00;
        return r0 + (1.0-r0) * math.pow( f32, 1.0 - cosine, 5.0 );
    }


};