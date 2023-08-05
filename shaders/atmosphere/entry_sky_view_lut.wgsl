#define feature_transmittance_lut_in

#include "atmosphere/raymarch"
#include "atmosphere/lut_mapping"
#include "atmosphere/global"

#include "vs_screen_triangle"

@group(0) @binding(0) var<uniform> global: Global;
@group(0) @binding(1) var transmittance_lut: texture_2d<f32>;
@group(0) @binding(2) var transmittance_lut_sampler: sampler;

struct FragOutput {
    @location(0) color: vec4<f32>,
}

@fragment
fn fs_main(input: VertexOutput) -> FragOutput {
    let uv = input.tex_coord;

    let atmosphere = get_atmosphere_parameters();

    let clip_space = vec3(uv * vec2(2.0, -2.0) - vec2(1.0, -1.0), 1.0);
    let h_view_pos = global.sky_projection_inv * vec4(clip_space, 1.0);

    let sky_view_inv3 = mat3x3(global.sky_view_inv[0].xyz, global.sky_view_inv[1].xyz, global.sky_view_inv[2].xyz);
    var world_dir = normalize(sky_view_inv3 * (h_view_pos.xyz / h_view_pos.w));
    var world_pos = global.camera_pos + vec3(0.0, atmosphere.bottom_radius, 0.0);

    let view_height = length(world_pos);

    let lut_params = uv_to_lut_sky_view_params(atmosphere, view_height, uv);
    let view_zenith_cos_angle = lut_params.x;
    let light_view_cos_angle = lut_params.y;

    let up_vector = world_pos / view_height;
    let sun_zenith_cos_angle = dot(up_vector, global.sun_direction);
    let sun_dir = normalize(vec3(
        sqrt(1.0 - sun_zenith_cos_angle * sun_zenith_cos_angle),
        sun_zenith_cos_angle,
        0.0));

    // QUESTION: Why do we reassign world_pos and world_dir here?
    world_pos = vec3(0.0, view_height, 0.0);

    let view_zenith_sin_angle = sqrt(1.0 - view_zenith_cos_angle * view_zenith_cos_angle);
    world_dir = vec3(
        view_zenith_sin_angle * light_view_cos_angle,
        view_zenith_cos_angle,
        view_zenith_sin_angle * sqrt(1.0 - light_view_cos_angle * light_view_cos_angle));

    // Move to top atmospehre
    let top = move_to_top_of_atmosphere(world_pos, world_dir, atmosphere.top_radius);
    world_pos = top.world_pos;
    if (!top.intersecting) {
        // Ray is not intersecting the atmosphere
        var output: FragOutput;
        output.color = vec4(0.0, 0.0, 0.0, 1.0);
        return output;
    }

    var input: SingleScatteringInput;
    input.uv = uv;
    input.world_pos = world_pos;
    input.world_dir = world_dir;
    input.sun_direction = sun_dir;
    input.atmosphere = atmosphere;
    input.sky_projection_view_inv = global.sky_projection_view_inv;
    input.sample_count_init = 30.0;
    input.depth_buffer_value = -1.0;
    input.variable_sample_count = true;
    input.mie_ray_phase = true;
    let result = integrate_scattered_luminance(input);

    var output: FragOutput;
    output.color = vec4(result.L, 1.0);
    return output;
}
