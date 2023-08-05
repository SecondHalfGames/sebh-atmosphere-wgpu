#include "atmosphere/constants"
#include "atmosphere/parameters"

const SKY_VIEW_TEXTURE_WIDTH: f32 = 192.0;
const SKY_VIEW_TEXTURE_HEIGHT: f32 = 108.0;

fn from_sub_uvs_to_unit(u: f32, resolution: f32) -> f32 {
    return (u - 0.5f / resolution) * (resolution / (resolution - 1.0f));
}

fn from_unit_to_sub_uvs(u: f32, resolution: f32) -> f32 {
    return (u + 0.5f / resolution) * (resolution / (resolution + 1.0f));
}

fn uv_to_lut_sky_view_params(atmosphere: Atmosphere, view_height: f32, in_uv: vec2<f32>) -> vec2<f32> {
    // Constrain uvs to valid sub texel range (avoid zenith derivative issue making LUT usage visible)
    let uv = vec2(
        from_sub_uvs_to_unit(in_uv.x, SKY_VIEW_TEXTURE_WIDTH),
        from_sub_uvs_to_unit(in_uv.y, SKY_VIEW_TEXTURE_HEIGHT));

    let v_horizon = sqrt(view_height * view_height - atmosphere.bottom_radius * atmosphere.bottom_radius);
    let cos_beta = v_horizon / view_height;
    let beta = acos(cos_beta);
    let zenith_horizon_angle = PI - beta;

    var view_zenith_cos_angle: f32;
    if (uv.y < 0.5) {
        var coord = 2.0*uv.y;
        coord = 1.0 - coord;
        coord *= coord;
        coord = 1.0 - coord;
        view_zenith_cos_angle = cos(zenith_horizon_angle * coord);
    } else {
        var coord = uv.y * 2.0 - 1.0;
        coord *= coord;
        view_zenith_cos_angle = cos(zenith_horizon_angle + beta * coord);
    }

    var coord = uv.x;
    coord *= coord;
    let light_view_cos_angle = -(coord*2.0 - 1.0);

    return vec2(view_zenith_cos_angle, light_view_cos_angle);
}

fn sky_view_lut_params_to_uv(
    atmosphere: Atmosphere,
    intersect_ground: bool,
    view_zenith_cos_angle: f32,
    light_view_cos_angle: f32,
    view_height: f32,
) -> vec2<f32> {
    var uv: vec2<f32>;
    var v_horizon = sqrt(view_height * view_height - atmosphere.bottom_radius * atmosphere.bottom_radius);
    var cos_beta = v_horizon / view_height;              // GroundToHorizonCos
    var beta = acos(cos_beta);
    var zenith_horizon_angle = PI - beta;

    if (!intersect_ground) {
        var coord = acos(view_zenith_cos_angle) / zenith_horizon_angle;
        coord = 1.0 - coord;
        coord = sqrt(coord);
        coord = 1.0 - coord;
        uv.y = coord * 0.5f;
    } else {
        var coord = (acos(view_zenith_cos_angle) - zenith_horizon_angle) / beta;
        coord = sqrt(coord);
        uv.y = coord * 0.5f + 0.5f;
    }

    {
        var coord = -light_view_cos_angle * 0.5f + 0.5f;
        coord = sqrt(coord);
        uv.x = coord;
    }

    // Constrain uvs to valid sub texel range (avoid zenith derivative issue making LUT usage visible)
    return vec2(
        from_unit_to_sub_uvs(uv.x, SKY_VIEW_TEXTURE_WIDTH),
        from_unit_to_sub_uvs(uv.y, SKY_VIEW_TEXTURE_HEIGHT));
}
