struct Global {
    camera_pos: vec3<f32>,
    _pad0: f32,
    sun_direction: vec3<f32>,
    _pad1: f32,

    sky_view_inv: mat4x4<f32>,
    sky_projection_inv: mat4x4<f32>,
    sky_projection_view_inv: mat4x4<f32>,
}
