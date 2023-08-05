#include "atmosphere/constants"

fn rayleigh_phase(cos_theta: f32) -> f32 {
    let factor = 3.0 / (16.0 * PI);
    return factor * (1.0 + cos_theta * cos_theta);
}

fn cornette_shanks_mie_phase_function(g: f32, cos_theta: f32) -> f32 {
    let k = 3.0 / (8.0 * PI) * (1.0 - g * g) / (2.0 + g * g);
    return k * (1.0 + cos_theta * cos_theta) / pow(1.0 + g * g - 2.0 * g * -cos_theta, 1.5);
}

fn hg_phase(g: f32, cos_theta: f32) -> f32 {
    // Other options: Schlick appoximation, Henyey-Greenstein approximation
    return cornette_shanks_mie_phase_function(g, cos_theta);
}
