#include "atmosphere/raycast"
#include "atmosphere/constants"
#include "atmosphere/lut_mapping"
#include "atmosphere/medium"
#include "atmosphere/phase"
#include "atmosphere/transmittance_lut"

const RAY_MARCH_MIN_SPP: f32 = 4.0;
const RAY_MARCH_MAX_SPP: f32 = 14.0;

struct SingleScatteringResult {
    L: vec3<f32>,             // Scattered light (luminance)
    optical_depth: vec3<f32>, // Optical depth (1/m)
    transmittance: vec3<f32>, // Transmittance in [0,1] (unitless)
}

struct SingleScatteringInput {
    atmosphere: Atmosphere,
    uv: vec2<f32>,
    world_pos: vec3<f32>,
    world_dir: vec3<f32>,
    sun_direction: vec3<f32>,

    // inverse(projection * view) matrix for the camera
    sky_projection_view_inv: mat4x4<f32>,

    // The number of samples to use for the raymarch.
    //
    // If variable_sample_count is set, this value is ignored and instead
    // calculated based on the total distance covered by the raymarch.
    sample_count_init: f32,

    // The depth sample to use when calculating aerial perspective. Pass -1.0 if
    // there's no depth information available.
    depth_buffer_value: f32,

    // If set, the sample count will be derived based on the total distance
    // covered by the raymarch.
    variable_sample_count: bool,

    // I'm not really sure why you would or wouldn't want this set, but it
    // causes Rayleigh and Mie scattering to be evaluated separately instead of
    // being mixed together as a "uniform phase."
    mie_ray_phase: bool,

    // If set, lighting calculations will be made against the albedo given for
    // the planet's surface. This seems to only affect the color that's shown
    // below the horizon.
    ground: bool,
}

fn integrate_scattered_luminance(in: SingleScatteringInput) -> SingleScatteringResult {
    let gSunIlluminance = vec3(40.0);

    var result: SingleScatteringResult;

    // Compute next intersection with atmosphere or ground
    var earthO = vec3(0.0, 0.0, 0.0);
    let tBottom = ray_sphere_intersect_nearest(in.world_pos, in.world_dir, earthO, in.atmosphere.bottom_radius);
    let tTop = ray_sphere_intersect_nearest(in.world_pos, in.world_dir, earthO, in.atmosphere.top_radius);
    var tMax = 0.0;
    if (tBottom < 0.0) {
        if (tTop < 0.0) {
            tMax = 0.0; // No intersection with earth nor atmosphere: stop right away
            return result;
        } else {
            tMax = tTop;
        }
    } else {
        if (tTop > 0.0) {
            tMax = min(tTop, tBottom);
        }
    }

    // If this fragment has geometry rendered onto it, it might have an aerial
    // perspective effect applied to it.
    if (in.depth_buffer_value > 0.0 && in.depth_buffer_value < 1.0) {
        // Map UV from [0, 1] with Y-down to [-1, 1] with Y-up.
        let clip_space = vec3(
            in.uv * vec2(2.0, -2.0) - vec2(1.0, -1.0),
            in.depth_buffer_value);

        // Project depth back into world space
        var depth_buffer_world_pos = in.sky_projection_view_inv * vec4(clip_space, 1.0);
        depth_buffer_world_pos /= depth_buffer_world_pos.w;

        // QUESTION: Why do we move the camera down by this amount?
        //
        // sebh: apply earth offset to go back to origin as top of earth mode
        let camera_pos = in.world_pos + vec3(0.0, -in.atmosphere.bottom_radius, 0.0);
        let tDepthMeters = length(depth_buffer_world_pos.xyz - camera_pos);

        // The projection matrix assumes meters, so we rescale our units back to
        // kilometers here.
        let tDepth = tDepthMeters / 1000.0;

        // If this fragment is closer to us than the furthest sample we were
        // going to take, we should sample up to this point instead.
        //
        // That way, we can accumulate all of the scattering between the camera
        // and that point and blend it onto the scene.
        if (tDepth < tMax) {
            tMax = tDepth;
        }
    }

    var sample_count = in.sample_count_init;
    var sample_count_floor = in.sample_count_init;
    var tMaxFloor = tMax;
    if (in.variable_sample_count) {
        // QUESTION: Multiplying by 0.01 seems arbitrary here — is this causing
        // the artifacts on small planets?

        sample_count = mix(RAY_MARCH_MIN_SPP, RAY_MARCH_MAX_SPP, saturate(tMax * 0.01));
        sample_count_floor = floor(sample_count);
        tMaxFloor = tMax * sample_count_floor / sample_count;  // rescale tMax to map to the last entire step segment.
    }

    // This is our raymarching step size.
    var dt = tMax / sample_count;

    // Phase functions
    let uniform_phase = 1.0 / (4.0 * PI);
    let wi = in.sun_direction;
    let wo = in.world_dir;
    let cos_theta = dot(wi, wo);
    // negate cos_theta because due to world_dir being a "in" direction.
    let mie_phase_value = hg_phase(in.atmosphere.mie_phase_g, -cos_theta);
    let rayleigh_phase_value = rayleigh_phase(cos_theta);

// #ifdef ILLUMINANCE_IS_ONE
    // When building the scattering factor, we assume light illuminance is 1 to compute a transfert function relative to identity illuminance of 1.
    // This make the scattering factor independent of the light. It is now only linked to the atmosphere properties.
    // float3 globalL = 1.0f;
// #else
    let globalL = gSunIlluminance;
// #endif

    // Ray march the atmosphere to integrate optical depth
    var L = vec3(0.0);
    var throughput = vec3(1.0);
    var optical_depth = vec3(0.0);
    var t = 0.0;
    var tPrev = 0.0;
    let sample_segment_t = 0.3;
    for (var s = 0.0; s < sample_count; s += 1.0) {
        if in.variable_sample_count {
            // More expensive but artifact free
            var t0 = (s) / sample_count_floor;
            var t1 = (s + 1.0f) / sample_count_floor;
            // Non linear distribution of sample within the range.
            t0 = t0 * t0;
            t1 = t1 * t1;
            // Make t0 and t1 world space distances.
            t0 = tMaxFloor * t0;
            if (t1 > 1.0) {
                t1 = tMax;
                //  t1 = tMaxFloor; // this reveal depth slices
            } else {
                t1 = tMaxFloor * t1;
            }
            t = t0 + (t1 - t0) * sample_segment_t;
            dt = t1 - t0;
        } else {
            // Exact difference, important for accuracy of multiple scattering
            let new_t = tMax * (s + sample_segment_t) / sample_count;
            dt = new_t - t;
            t = new_t;
        }
        let P = in.world_pos + t * in.world_dir;

        let medium = sample_medium_rgb(P, in.atmosphere);
        let sample_optical_depth = medium.extinction * dt;
        let sample_transmittance = exp(-sample_optical_depth);
        optical_depth += sample_optical_depth;

        let pHeight = length(P);
        let up_vector = P / pHeight;
        let sun_zenith_cos_angle = dot(in.sun_direction, up_vector);

        var transmittance_to_sun = vec3(1.0);
#ifdef feature_transmittance_lut_in
        transmittance_to_sun = get_transmittance_lut(in.atmosphere, pHeight, sun_zenith_cos_angle);
#endif

        var phase_times_scattering: vec3<f32>;
        if (in.mie_ray_phase) {
            phase_times_scattering = medium.scattering_mie * mie_phase_value + medium.scattering_ray * rayleigh_phase_value;
        } else {
            phase_times_scattering = medium.scattering * uniform_phase;
        }

        // Earth shadow
        let tEarth = ray_sphere_intersect_nearest(
            P,
            in.sun_direction,
            earthO + PLANET_RADIUS_OFFSET * up_vector,
            in.atmosphere.bottom_radius);
        let earth_shadow = select(1.0, 0.0, tEarth >= 0.0);

        // Dual scattering for multi scattering
        var multi_scattered_luminance = vec3(0.0);
// #if MULTISCATAPPROX_ENABLED
//         multi_scattered_luminance = GetMultipleScattering(Atmosphere, medium.scattering, medium.extinction, P, sun_zenith_cos_angle);
// #endif

        var shadow = 1.0;
// #if SHADOWMAP_ENABLED
//         // First evaluate opaque shadow
//         shadow = getShadow(Atmosphere, P);
// #endif

        let S = globalL * (
                earth_shadow
                * shadow
                * transmittance_to_sun
                * phase_times_scattering
                + multi_scattered_luminance * medium.scattering);

// #if MULTI_SCATTERING_POWER_SERIE==0
        // 1 is the integration of luminance over the 4pi of a sphere, and assuming an isotropic phase function of 1.0/(4*PI)
        // result.MultiScatAs1 += throughput * medium.scattering * 1 * dt;
// #else
        // let MS = medium.scattering;
        // let MSint = (MS - MS * sample_transmittance) / medium.extinction;
        // result.MultiScatAs1 += throughput * MSint;
// #endif

        // Evaluate input to multi scattering
        // {
        //     float3 newMS;

        //     newMS = earthShadow * transmittance_to_sun * medium.scattering * uniformPhase * 1;
        //     result.NewMultiScatStep0Out += throughput * (newMS - newMS * sample_transmittance) / medium.extinction;

        //     newMS = medium.scattering * uniformPhase * multiScatteredLuminance;
        //     result.NewMultiScatStep1Out += throughput * (newMS - newMS * sample_transmittance) / medium.extinction;
        // }

        // See slide 28 at http://www.frostbite.com/2015/08/physically-based-unified-volumetric-rendering-in-frostbite/
        let Sint = (S - S * sample_transmittance) / medium.extinction;    // integrate along the current step segment
        L += throughput * Sint;                                              // accumulate and also take into account the transmittance from previous steps
        throughput *= sample_transmittance;

        tPrev = t;
    }

#ifdef feature_transmittance_lut_in
    if (in.ground && tMax == tBottom && tBottom > 0.0) {
        // Account for bounced light off the earth
        let P = in.world_pos + tBottom * in.world_dir;
        let pHeight = length(P);

        let up_vector = P / pHeight;
        let sun_zenith_cos_angle = dot(in.sun_direction, up_vector);
        let uv = lut_transmittance_params_to_uv(in.atmosphere, pHeight, sun_zenith_cos_angle);
        let transmittance_to_sun = textureSampleLevel(transmittance_lut, transmittance_lut_sampler, uv, 0.0).rgb;

        let NdotL = saturate(dot(normalize(up_vector), normalize(in.sun_direction)));
        L += globalL * transmittance_to_sun * throughput * NdotL * in.atmosphere.ground_albedo / PI;
    }
#endif

    result.L = L;
    result.optical_depth = optical_depth;
    result.transmittance = throughput;
    return result;
}
