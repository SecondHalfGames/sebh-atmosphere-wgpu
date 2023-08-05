#include "atmosphere/parameters"

struct MediumSampleRGB {
    scattering: vec3<f32>,
    absorption: vec3<f32>,
    extinction: vec3<f32>,

    scattering_mie: vec3<f32>,
    absorption_mie: vec3<f32>,
    extinction_mie: vec3<f32>,

    scattering_ray: vec3<f32>,
    absorption_ray: vec3<f32>,
    extinction_ray: vec3<f32>,

    scattering_ozo: vec3<f32>,
    absorption_ozo: vec3<f32>,
    extinction_ozo: vec3<f32>,

    albedo: vec3<f32>,
}

fn sample_medium_rgb(world_pos: vec3<f32>, atmosphere: Atmosphere) -> MediumSampleRGB {
    let view_height = length(world_pos) - atmosphere.bottom_radius;

    let density_mie = exp(atmosphere.mie_density_exp_scale * view_height);
    let density_ray = exp(atmosphere.rayleigh_density_exp_scale * view_height);
    let density_ozo = saturate(
        select(
            atmosphere.absorption_density_1_linear_term * view_height + atmosphere.absorption_density_1_constant_term,
            atmosphere.absorption_density_0_linear_term * view_height + atmosphere.absorption_density_0_constant_term,
            view_height < atmosphere.absorption_density_0_layer_width));

    var s: MediumSampleRGB;

    s.scattering_mie = density_mie * atmosphere.mie_scattering;
    s.absorption_mie = density_mie * atmosphere.mie_absorption;
    s.extinction_mie = density_mie * atmosphere.mie_extinction;

    s.scattering_ray = density_ray * atmosphere.rayleigh_scattering;
    s.absorption_ray = vec3(0.0);
    s.extinction_ray = s.scattering_ray + s.absorption_ray;

    s.scattering_ozo = vec3(0.0);
    s.absorption_ozo = density_ozo * atmosphere.absorption_extinction;
    s.extinction_ozo = s.scattering_ozo + s.absorption_ozo;

    s.scattering = s.scattering_mie + s.scattering_ray + s.scattering_ozo;
    s.absorption = s.absorption_mie + s.absorption_ray + s.absorption_ozo;
    s.extinction = s.extinction_mie + s.extinction_ray + s.extinction_ozo;
    s.albedo = get_albedo(s.scattering, s.extinction);

    return s;
}

fn get_albedo(scattering: vec3<f32>, extinction: vec3<f32>) -> vec3<f32> {
    return scattering / max(vec3(0.001), extinction);
}
