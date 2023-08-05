struct Atmosphere {
    // Radius of the planet (center to ground)
    bottom_radius: f32,
    // Maximum considered atmosphere height (center to atmosphere top)
    top_radius: f32,

    // Rayleigh scattering exponential distribution scale in the atmosphere
    rayleigh_density_exp_scale: f32,
    // Rayleigh scattering coefficients
    rayleigh_scattering: vec3<f32>,

    // Mie scattering exponential distribution scale in the atmosphere
    mie_density_exp_scale: f32,
    // Mie scattering coefficients
    mie_scattering: vec3<f32>,
    // Mie extinction coefficients
    mie_extinction: vec3<f32>,
    // Mie absorption coefficients
    mie_absorption: vec3<f32>,
    // Mie phase function excentricity
    mie_phase_g: f32,

    // Another medium type in the atmosphere
    absorption_density_0_layer_width: f32,
    absorption_density_0_constant_term: f32,
    absorption_density_0_linear_term: f32,
    absorption_density_1_constant_term: f32,
    absorption_density_1_linear_term: f32,
    // This other medium only absorb light, e.g. useful to represent ozone in the earth atmosphere
    absorption_extinction: vec3<f32>,

    ground_albedo: vec3<f32>,
}

fn get_atmosphere_parameters() -> Atmosphere {
    return earth_atmosphere();
}

fn wip_atmosphere() -> Atmosphere {
    let EarthRayleighScaleHeight = 8.0;
    let EarthMieScaleHeight = 1.2;

    var atmosphere: Atmosphere;

    atmosphere.bottom_radius = 6360.0;
    atmosphere.top_radius = atmosphere.bottom_radius + 100.0;
    atmosphere.ground_albedo = vec3(0.0);

    // Raleigh scattering
    atmosphere.rayleigh_density_exp_scale = -1.0 / EarthRayleighScaleHeight;
    atmosphere.rayleigh_scattering = vec3(0.005802, 0.013558, 0.033100); // 1/km

    // Mie scattering
    atmosphere.mie_density_exp_scale = -1.0 / EarthMieScaleHeight;
    atmosphere.mie_scattering = vec3(0.003996, 0.003996, 0.003996); // 1/km
    atmosphere.mie_extinction = vec3(0.004440, 0.004440, 0.004440); // 1/km
    atmosphere.mie_absorption = max(vec3(0.0), atmosphere.mie_extinction - atmosphere.mie_scattering);
    atmosphere.mie_phase_g = 0.8;

    // Ozone absorption
    atmosphere.absorption_density_0_layer_width = 25.0; // absorption_density[0].x
    atmosphere.absorption_density_0_constant_term = -2.0 / 3.0; // absorption_density[1].x
    atmosphere.absorption_density_0_linear_term = 1.0 / 15.0; // absorption_density[0].w
    atmosphere.absorption_density_1_constant_term = 8.0 / 3.0; // absorption_density[2].y
    atmosphere.absorption_density_1_linear_term = -1.0 / 15.0; // absorption_density[2].x
    atmosphere.absorption_extinction = vec3(0.000650, 0.001881, 0.000085); // 1/km

    return atmosphere;
}

fn earth_atmosphere() -> Atmosphere {
    let EarthRayleighScaleHeight = 8.0;
    let EarthMieScaleHeight = 1.2;

    var atmosphere: Atmosphere;

    atmosphere.bottom_radius = 6360.0;
    atmosphere.top_radius = atmosphere.bottom_radius + 100.0;
    atmosphere.ground_albedo = vec3(0.0595, 0.404, 0.220);


    // Raleigh scattering
    atmosphere.rayleigh_density_exp_scale = -1.0 / EarthRayleighScaleHeight;
    atmosphere.rayleigh_scattering = vec3(0.005802, 0.013558, 0.033100); // 1/km

    // Mie scattering
    atmosphere.mie_density_exp_scale = -1.0 / EarthMieScaleHeight;
    atmosphere.mie_scattering = vec3(0.003996, 0.003996, 0.003996); // 1/km
    atmosphere.mie_extinction = vec3(0.004440, 0.004440, 0.004440); // 1/km
    atmosphere.mie_absorption = max(vec3(0.0), atmosphere.mie_extinction - atmosphere.mie_scattering);
    atmosphere.mie_phase_g = 0.8;

    // Ozone absorption
    atmosphere.absorption_density_0_layer_width = 25.0; // absorption_density[0].x
    atmosphere.absorption_density_0_constant_term = -2.0 / 3.0; // absorption_density[1].x
    atmosphere.absorption_density_0_linear_term = 1.0 / 15.0; // absorption_density[0].w
    atmosphere.absorption_density_1_constant_term = 8.0 / 3.0; // absorption_density[2].y
    atmosphere.absorption_density_1_linear_term = -1.0 / 15.0; // absorption_density[2].x
    atmosphere.absorption_extinction = vec3(0.000650, 0.001881, 0.000085); // 1/km

    return atmosphere;
}
