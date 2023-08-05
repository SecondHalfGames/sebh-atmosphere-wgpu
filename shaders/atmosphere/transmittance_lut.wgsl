#include "atmosphere/lut_mapping"
#include "atmosphere/parameters"

const TRANSMITTANCE_TEXTURE_WIDTH: f32 = 256.0;
const TRANSMITTANCE_TEXTURE_HEIGHT: f32 = 64.0;

// Expects these bindings:
// @group(0) @binding(1) var transmittance_lut: texture_2d<f32>;
// @group(0) @binding(2) var transmittance_lut_sampler: sampler;

#ifdef feature_transmittance_lut_in
fn get_transmittance_lut(
    atmosphere: Atmosphere,
    view_height: f32,
    view_zenith_cos_angle: f32,
) -> vec3<f32> {
    var uv = lut_transmittance_params_to_uv(atmosphere, view_height, view_zenith_cos_angle);
    return textureSampleLevel(transmittance_lut, transmittance_lut_sampler, uv, 0.0).rgb;
}
#endif

fn uv_to_lut_transmittance_params(atmosphere: Atmosphere, uv: vec2<f32>) -> vec2<f32> {
    let x_mu = uv.x;
    let x_r = uv.y;

    let H = sqrt(atmosphere.top_radius * atmosphere.top_radius - atmosphere.bottom_radius * atmosphere.bottom_radius);
    let rho = H * x_r;
    let view_height = sqrt(rho * rho + atmosphere.bottom_radius * atmosphere.bottom_radius);

    let d_min = atmosphere.top_radius - view_height;
    let d_max = rho + H;
    let d = d_min + x_mu * (d_max - d_min);

    // let view_zenith_cos_angle = d == 0.0 ? 1.0 : (H * H - rho * rho - d * d) / (2.0 * view_height * d);
    var view_zenith_cos_angle = select(
        (H * H - rho * rho - d * d) / (2.0 * view_height * d),
        1.0,
        d == 0.0);
    view_zenith_cos_angle = clamp(view_zenith_cos_angle, -1.0, 1.0);

    return vec2(view_height, view_zenith_cos_angle);
}

fn lut_transmittance_params_to_uv(
    atmosphere: Atmosphere,
    view_height: f32,
    view_zenith_cos_angle: f32,
) -> vec2<f32> {
    let H = sqrt(max(0.0, atmosphere.top_radius * atmosphere.top_radius - atmosphere.bottom_radius * atmosphere.bottom_radius));
    let rho = sqrt(max(0.0, view_height * view_height - atmosphere.bottom_radius * atmosphere.bottom_radius));

    let discriminant = view_height * view_height * (view_zenith_cos_angle * view_zenith_cos_angle - 1.0) + atmosphere.top_radius * atmosphere.top_radius;
    let d = max(0.0, (-view_height * view_zenith_cos_angle + sqrt(discriminant))); // Distance to atmosphere boundary

    let d_min = atmosphere.top_radius - view_height;
    let d_max = rho + H;
    let x_mu = (d - d_min) / (d_max - d_min);
    let x_r = rho / H;

    return vec2(x_mu, x_r);
}
