struct VertexInput {
    @builtin(vertex_index) index: u32,
}

struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) tex_coord: vec2<f32>,
}

@vertex
fn vs_screen_triangle(in: VertexInput) -> VertexOutput {
    var rectangle = array<vec2<f32>, 6>(
        vec2(0.0, 0.0),
        vec2(0.0, 1.0),
        vec2(1.0, 1.0),

        vec2(1.0, 0.0),
        vec2(0.0, 0.0),
        vec2(1.0, 1.0)
    );

    let pos = rectangle[in.index];

    var out: VertexOutput;
    out.position = vec4(2.0 * vec2(pos.x - 0.5, -pos.y + 0.5), 0.0, 1.0);
    out.tex_coord = pos;
    return out;
}
