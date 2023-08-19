# sebh Atmosphere Model in wgpu + WGSL
This is port of the shaders from <https://github.com/sebh/UnrealEngineSkyAtmosphere> to wgpu and WGSL. It's a work in progress, mind the mess!

Some notes about our changes:

- We changed the shader coordinate system from Z+ up to Y+ up
- We use an inverse-infinite depth buffer, so all of the depth comparison code was flipped from the reference implementation.