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
    albedo: Vec3,
    roughness: f32,
    
    pub fn makeLambertian( albedo : Vec3 ) Material {
        return .{
            .metalness = 0.0,
            .albedo = albedo,
            .roughness = 0.9
        };
    }

    pub fn makeMetallic( albedo : Vec3 ) Material {
        return .{
            .metalness = 1.0,
            .albedo = albedo,
            .roughness = 0.9
        };
    }

    pub fn scatter( self : Self, rng: *Random, ray_in: Ray, hit : HitRecord ) ?ScatterResult {


        // todo probability 
        if (self.metalness > 0.5 ) {
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


};