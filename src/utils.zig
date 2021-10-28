const std = @import("std");

const vm = @import("vecmath_j.zig");
const Vec3 = vm.Vec3;

const Random = std.rand.DefaultPrng;

pub fn randomRange( rng: *Random, min : f32, max : f32 ) f32 {

    return min + (max - min) * rng.random.float( f32 );
}

pub fn randomVec3( rng: *Random ) Vec3 {
    return Vec3.init( rng.random.float( f32 ), rng.random.float( f32 ), rng.random.float( f32 ) );
}

pub fn randomVec3Range( rng: *Random, min : f32, max : f32) Vec3 {
    return Vec3.init( 
        randomRange( rng, min, max ),
        randomRange( rng, min, max ),
        randomRange( rng, min, max )
    );
}

pub fn randomInUnitSphere( rng: *Random ) Vec3 {
    while (true) {
        var p = randomVec3Range( rng, -1.0, 1.0 );
        if (p.lengthSq() >= 1.0) {
            continue;
        }
        return p;
    }
}

pub fn randomUnitVector( rng: *Random ) Vec3 {
    return Vec3.normalize( randomInUnitSphere( rng ) );
}

pub fn randomInHemisphere( rng: *Random, normal : Vec3 ) Vec3 {
    const unitVec = randomUnitVector( rng );
    if ( Vec3.dot( unitVec, normal ) > 0.0 ) {
        return unitVec; // same hemisphere as unit vec
    } else {
        return Vec3.mul_s( unitVec, -1.0 );
    }
}
