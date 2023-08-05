#define feature_transmittance_lut_in

#include "atmosphere/constants"
#include "atmosphere/lut_mapping"
#include "atmosphere/medium"
#include "atmosphere/parameters"
#include "atmosphere/phase"
#include "atmosphere/raycast"
#include "atmosphere/raymarch"
#include "atmosphere/global"

#include "vs_screen_triangle"

struct FragOutput {
    @location(0) color: vec4<f32>,
}

struct SkyFragOutput {
    @location(0) luminance: vec4<f32>,
#ifdef feature_transmittance_out
    @location(1) transmittance: vec4<f32>,
#endif
}

@group(0) @binding(0) var<uniform> global: Global;
@group(0) @binding(1) var transmittance_lut: texture_2d<f32>;
@group(0) @binding(2) var transmittance_lut_sampler: sampler;
@group(0) @binding(3) var sky_view_lut: texture_2d<f32>;
@group(0) @binding(4) var sky_view_lut_sampler: sampler;

#ifdef feature_depth_in
@group(0) @binding(5) var depth_texture: texture_depth_2d;
@group(0) @binding(6) var depth_sampler: sampler;
#endif

@fragment
fn fs_main(input: VertexOutput) -> SkyFragOutput {
    let uv = input.tex_coord;
    let atmosphere = get_atmosphere_parameters();

    let clip_space = vec3(uv * vec2(2.0, -2.0) - vec2(1.0, -1.0), 1.0);
    let h_view_pos = global.sky_projection_inv * vec4(clip_space, 1.0);

    let sky_view_inv3 = mat3x3(global.sky_view_inv[0].xyz, global.sky_view_inv[1].xyz, global.sky_view_inv[2].xyz);
    var world_dir = normalize(sky_view_inv3 * (h_view_pos.xyz / h_view_pos.w));
    var world_pos = global.camera_pos + vec3(0.0, atmosphere.bottom_radius, 0.0);

    let view_height = length(world_pos);

    var depth_buffer_value = 0.0;
#ifdef feature_depth_in
    depth_buffer_value = textureSample(depth_texture, depth_sampler, uv);
#endif

    var output: SkyFragOutput;

    // "FAST SKY" Approximation
    if (view_height < atmosphere.top_radius && depth_buffer_value == 0.0) {
        let up_vector = normalize(world_pos);
        let view_zenith_cos_angle = dot(world_dir, up_vector);

        let sideVector = normalize(cross(up_vector, world_dir));       // assumes non parallel vectors
        let forwardVector = normalize(cross(sideVector, up_vector));  // aligns toward the sun light but perpendicular to up vector
        var light_on_plane = vec2(dot(global.sun_direction, forwardVector), dot(global.sun_direction, sideVector));
        light_on_plane = normalize(light_on_plane);
        let light_view_cos_angle = light_on_plane.x;

        let intersect_ground = ray_sphere_intersect_nearest(world_pos, world_dir, vec3(0.0), atmosphere.bottom_radius) >= 0.0;

        let lut_uv = sky_view_lut_params_to_uv(atmosphere, intersect_ground, view_zenith_cos_angle, light_view_cos_angle, view_height);

        let sample = textureSampleLevel(sky_view_lut, sky_view_lut_sampler, lut_uv, 0.0).rgb;
        // output.color = vec4(sample + GetSunLuminance(world_pos, world_dir, atmosphere.bottom_radius), 1.0);
        output.luminance = vec4(sample, 1.0);
        return output;
    }

    // TODO: FAST AERIAL PERSPECTIVE
    let top = move_to_top_of_atmosphere(world_pos, world_dir, atmosphere.top_radius);
    world_pos = top.world_pos;
    if (!top.intersecting) {
        // Ray is not intersecting the atmosphere
        var output: SkyFragOutput;
        output.luminance = vec4(0.0, 0.0, 0.0, 0.0);
        return output;
    }

    var input: SingleScatteringInput;
    input.uv = uv;
    input.world_pos = world_pos;
    input.world_dir = world_dir;
    input.sun_direction = global.sun_direction;
    input.atmosphere = atmosphere;
    input.sky_projection_view_inv = global.sky_projection_view_inv;
    input.sample_count_init = 0.0;
    input.depth_buffer_value = depth_buffer_value;
    input.variable_sample_count = true;
    input.mie_ray_phase = true;
    let result = integrate_scattered_luminance(input);

    let transmittance = dot(result.transmittance, vec3(1.0 / 3.0, 1.0 / 3.0, 1.0 / 3.0));
    output.luminance = vec4(result.L, 1.0 - transmittance);

#ifdef feature_transmittance_out
    output.luminance = vec4(result.L, 1.0);
    output.transmittance = vec4(result.transmittance, 1.0);
#endif

    return output;
}
