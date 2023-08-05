#include "atmosphere/raymarch"
#include "atmosphere/global"

#include "vs_screen_triangle";

@group(0) @binding(0) var<uniform> global: Global;

struct FragOutput {
    @location(0) color: vec4<f32>,
}

@fragment
fn fs_main(input: VertexOutput) -> FragOutput {
    let uv = input.tex_coord;
    let atmosphere = get_atmosphere_parameters();

    // Compute camera position from LUT coords
    let t_params = uv_to_lut_transmittance_params(atmosphere, uv);
    let view_height = t_params.x;
    let view_zenith_cos_angle = t_params.y;

    //  A few extra needed constants
    let world_pos = vec3(0.0, view_height, 0.0);
    let world_dir = vec3(0.0, view_zenith_cos_angle, sqrt(1.0 - view_zenith_cos_angle * view_zenith_cos_angle));

    var input: SingleScatteringInput;
    input.uv = uv;
    input.world_pos = world_pos;
    input.world_dir = world_dir;
    input.sun_direction = global.sun_direction;
    input.atmosphere = atmosphere;
    input.sky_projection_view_inv = global.sky_projection_view_inv;
    input.sample_count_init = 40.0; // Can go a low as 10 sample but energy lost starts to be visible.
    input.depth_buffer_value = -1.0;
    let result = integrate_scattered_luminance(input);

    // Optical depth to transmittance
    let transmittance = exp(-result.optical_depth);

    var output: FragOutput;
    output.color = vec4(transmittance, 1.0);
    return output;
}
