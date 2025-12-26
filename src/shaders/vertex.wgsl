// Vertex shader for fullscreen quad rendering
// Input attributes - passed from vertex buffer
struct VertexInput {
    @location(0) a_position: vec2<f32>,  // Position in clip space (-1 to 1)
    @location(1) a_texCoord: vec2<f32>, // Texture coordinates (0 to 1)
};

// Output to fragment shader
struct VertexOutput {
    @builtin(position) position: vec4<f32>,
    @location(0) texCoord: vec2<f32>,
};

@vertex
fn vs_main(input: VertexInput) -> VertexOutput {
    var output: VertexOutput;

    // Pass position directly to clip space
    output.position = vec4<f32>(input.a_position, 0.0, 1.0);

    // Pass texture coordinates to fragment shader
    output.texCoord = input.a_texCoord;

    return output;
}
