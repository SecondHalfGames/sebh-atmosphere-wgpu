#include "atmosphere/constants"

// Returns distance from r0 to first intersecion with sphere, or -1.0 if no
// intersection.
fn ray_sphere_intersect_nearest(
    ray_origin: vec3<f32>,
    ray_dir: vec3<f32>,
    sphere_origin: vec3<f32>,
    sphere_radius: f32
) -> f32 {
    let a = dot(ray_dir, ray_dir);
    let s0_r0 = ray_origin - sphere_origin;
    let b = 2.0 * dot(ray_dir, s0_r0);
    let c = dot(s0_r0, s0_r0) - (sphere_radius * sphere_radius);
    let delta = b * b - 4.0*a*c;
    if (delta < 0.0 || a == 0.0) {
        return -1.0;
    }

    let sol0 = (-b - sqrt(delta)) / (2.0*a);
    let sol1 = (-b + sqrt(delta)) / (2.0*a);
    if (sol0 < 0.0 && sol1 < 0.0) {
        return -1.0;
    }

    if (sol0 < 0.0) {
        return max(0.0, sol1);
    } else if (sol1 < 0.0) {
        return max(0.0, sol0);
    }
    return max(0.0, min(sol0, sol1));
}

struct MoveToTop {
    intersecting: bool,
    world_pos: vec3<f32>,
}

fn move_to_top_of_atmosphere(world_pos: vec3<f32>, world_dir: vec3<f32>, atmosphere_top_radius: f32) -> MoveToTop {
    var result: MoveToTop;
    result.world_pos = world_pos;

    let view_height = length(world_pos);
    if (view_height > atmosphere_top_radius) {
        let tTop = ray_sphere_intersect_nearest(world_pos, world_dir, vec3(0.0, 0.0, 0.0), atmosphere_top_radius);

        if (tTop >= 0.0f) {
            let up_vector = world_pos / view_height;
            let up_offset = up_vector * -PLANET_RADIUS_OFFSET;
            result.world_pos = world_pos + world_dir * tTop + up_offset;
        } else {
            // Ray is not intersecting the atmosphere
            result.intersecting = false;
            return result;
        }
    }

    // ok to start tracing
    result.intersecting = true;
    return result;
}
