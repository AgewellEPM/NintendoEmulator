#include <metal_stdlib>
using namespace metal;

struct EnhancementParameters {
    float intensity;
    float threshold;
    float radius;
    float sharpness;
    float contrast;
    float brightness;
    float saturation;
    float gamma;

    // CRT-specific parameters
    float crtCurvature;
    float crtScanlineIntensity;
    float crtPhosphorDecay;

    // Bloom parameters
    float bloomThreshold;
    float bloomIntensity;
    float bloomRadius;
};

// MARK: - Utility Functions

float4 sample_bilinear(texture2d<float> tex, sampler s, float2 coord) {
    return tex.sample(s, coord);
}

float luminance(float3 color) {
    return dot(color, float3(0.299, 0.587, 0.114));
}

float3 apply_gamma(float3 color, float gamma) {
    return pow(color, 1.0 / gamma);
}

// MARK: - Basic Filters

kernel void texture_copy_compute(texture2d<float, access::read> inputTexture [[texture(0)]],
                                texture2d<float, access::write> outputTexture [[texture(1)]],
                                uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    float2 textureSize = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 coord = (float2(gid) + 0.5) / float2(outputTexture.get_width(), outputTexture.get_height());

    float4 color = inputTexture.read(uint2(coord * textureSize));
    outputTexture.write(color, gid);
}

kernel void bilinear_compute(texture2d<float, access::read> inputTexture [[texture(0)]],
                           texture2d<float, access::write> outputTexture [[texture(1)]],
                           constant EnhancementParameters& params [[buffer(0)]],
                           uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    float2 outputSize = float2(outputTexture.get_width(), outputTexture.get_height());
    float2 inputSize = float2(inputTexture.get_width(), inputTexture.get_height());

    float2 coord = (float2(gid) + 0.5) / outputSize;
    float2 inputCoord = coord * inputSize - 0.5;

    uint2 coord0 = uint2(floor(inputCoord));
    uint2 coord1 = coord0 + uint2(1, 0);
    uint2 coord2 = coord0 + uint2(0, 1);
    uint2 coord3 = coord0 + uint2(1, 1);

    float2 f = fract(inputCoord);

    float4 c0 = inputTexture.read(coord0);
    float4 c1 = inputTexture.read(coord1);
    float4 c2 = inputTexture.read(coord2);
    float4 c3 = inputTexture.read(coord3);

    float4 color = mix(mix(c0, c1, f.x), mix(c2, c3, f.x), f.y);
    color.rgb = apply_gamma(color.rgb, params.gamma);

    outputTexture.write(color, gid);
}

// MARK: - Advanced Filters

kernel void hq2x_compute(texture2d<float, access::read> inputTexture [[texture(0)]],
                        texture2d<float, access::write> outputTexture [[texture(1)]],
                        constant EnhancementParameters& params [[buffer(0)]],
                        uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    // HQ2x algorithm - simplified version
    uint2 inputCoord = gid / 2;
    uint2 subPixel = gid % 2;

    // Sample 3x3 neighborhood
    float4 c1 = inputTexture.read(inputCoord + uint2(-1, -1));
    float4 c2 = inputTexture.read(inputCoord + uint2( 0, -1));
    float4 c3 = inputTexture.read(inputCoord + uint2( 1, -1));
    float4 c4 = inputTexture.read(inputCoord + uint2(-1,  0));
    float4 c5 = inputTexture.read(inputCoord + uint2( 0,  0));
    float4 c6 = inputTexture.read(inputCoord + uint2( 1,  0));
    float4 c7 = inputTexture.read(inputCoord + uint2(-1,  1));
    float4 c8 = inputTexture.read(inputCoord + uint2( 0,  1));
    float4 c9 = inputTexture.read(inputCoord + uint2( 1,  1));

    // Simplified HQ2x logic
    float4 result = c5; // Default to center pixel

    if (subPixel.x == 0 && subPixel.y == 0) {
        // Top-left
        if (distance(c1.rgb, c5.rgb) < 0.1 && distance(c4.rgb, c5.rgb) < 0.1) {
            result = mix(c5, (c1 + c4) * 0.5, 0.5);
        }
    } else if (subPixel.x == 1 && subPixel.y == 0) {
        // Top-right
        if (distance(c3.rgb, c5.rgb) < 0.1 && distance(c2.rgb, c5.rgb) < 0.1) {
            result = mix(c5, (c3 + c2) * 0.5, 0.5);
        }
    } else if (subPixel.x == 0 && subPixel.y == 1) {
        // Bottom-left
        if (distance(c7.rgb, c5.rgb) < 0.1 && distance(c8.rgb, c5.rgb) < 0.1) {
            result = mix(c5, (c7 + c8) * 0.5, 0.5);
        }
    } else {
        // Bottom-right
        if (distance(c9.rgb, c5.rgb) < 0.1 && distance(c6.rgb, c5.rgb) < 0.1) {
            result = mix(c5, (c9 + c6) * 0.5, 0.5);
        }
    }

    outputTexture.write(result, gid);
}

kernel void scanlines_compute(texture2d<float, access::read> inputTexture [[texture(0)]],
                             texture2d<float, access::write> outputTexture [[texture(1)]],
                             constant EnhancementParameters& params [[buffer(0)]],
                             uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    float2 outputSize = float2(outputTexture.get_width(), outputTexture.get_height());
    float2 inputSize = float2(inputTexture.get_width(), inputTexture.get_height());

    float2 coord = (float2(gid) + 0.5) / outputSize;
    float2 inputCoord = coord * inputSize;

    float4 color = inputTexture.read(uint2(inputCoord));

    // Apply scanlines
    float scanline = sin(coord.y * outputSize.y * 3.14159) * 0.5 + 0.5;
    scanline = mix(1.0, scanline, params.crtScanlineIntensity);

    color.rgb *= scanline;
    outputTexture.write(color, gid);
}

kernel void crt_filter_compute(texture2d<float, access::read> inputTexture [[texture(0)]],
                              texture2d<float, access::write> outputTexture [[texture(1)]],
                              constant EnhancementParameters& params [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    float2 outputSize = float2(outputTexture.get_width(), outputTexture.get_height());
    float2 coord = (float2(gid) + 0.5) / outputSize;

    // Apply barrel distortion
    float2 center = coord - 0.5;
    float r = length(center);
    float distortion = 1.0 + params.crtCurvature * r * r;
    float2 distortedCoord = center * distortion + 0.5;

    if (distortedCoord.x < 0.0 || distortedCoord.x > 1.0 ||
        distortedCoord.y < 0.0 || distortedCoord.y > 1.0) {
        outputTexture.write(float4(0.0, 0.0, 0.0, 1.0), gid);
        return;
    }

    float2 inputSize = float2(inputTexture.get_width(), inputTexture.get_height());
    float2 inputCoord = distortedCoord * inputSize;

    float4 color = inputTexture.read(uint2(inputCoord));

    // Apply scanlines
    float scanline = sin(coord.y * outputSize.y * 3.14159 * 2.0) * 0.5 + 0.5;
    scanline = mix(1.0, scanline, params.crtScanlineIntensity);

    // Apply phosphor glow
    float glow = exp(-r * 4.0) * params.crtPhosphorDecay;
    color.rgb = color.rgb * scanline + color.rgb * glow * 0.1;

    // Apply vignette
    float vignette = 1.0 - r * 0.5;
    color.rgb *= vignette;

    outputTexture.write(color, gid);
}

kernel void sharpening_compute(texture2d<float, access::read> inputTexture [[texture(0)]],
                              texture2d<float, access::write> outputTexture [[texture(1)]],
                              constant EnhancementParameters& params [[buffer(0)]],
                              uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    // Unsharp mask sharpening
    float4 center = inputTexture.read(gid);
    float4 blur = (inputTexture.read(gid + uint2(-1, -1)) +
                   inputTexture.read(gid + uint2( 0, -1)) +
                   inputTexture.read(gid + uint2( 1, -1)) +
                   inputTexture.read(gid + uint2(-1,  0)) +
                   inputTexture.read(gid + uint2( 1,  0)) +
                   inputTexture.read(gid + uint2(-1,  1)) +
                   inputTexture.read(gid + uint2( 0,  1)) +
                   inputTexture.read(gid + uint2( 1,  1))) / 8.0;

    float4 sharpened = center + (center - blur) * params.sharpness;
    outputTexture.write(sharpened, gid);
}

kernel void bloom_compute(texture2d<float, access::read> inputTexture [[texture(0)]],
                         texture2d<float, access::write> outputTexture [[texture(1)]],
                         constant EnhancementParameters& params [[buffer(0)]],
                         uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    float4 original = inputTexture.read(gid);

    // Extract bright areas
    float luma = luminance(original.rgb);
    float4 bright = (luma > params.bloomThreshold) ? original : float4(0.0);

    // Simple bloom by sampling surrounding pixels
    float4 bloom = float4(0.0);
    int radius = int(params.bloomRadius);

    for (int x = -radius; x <= radius; x++) {
        for (int y = -radius; y <= radius; y++) {
            int2 offset = int2(x, y);
            uint2 sampleCoord = uint2(int2(gid) + offset);

            if (sampleCoord.x < inputTexture.get_width() &&
                sampleCoord.y < inputTexture.get_height()) {
                float4 sample = inputTexture.read(sampleCoord);
                float sampleLuma = luminance(sample.rgb);

                if (sampleLuma > params.bloomThreshold) {
                    float weight = exp(-float(x*x + y*y) / (params.bloomRadius * params.bloomRadius));
                    bloom += sample * weight;
                }
            }
        }
    }

    float4 result = original + bloom * params.bloomIntensity;
    outputTexture.write(result, gid);
}

// MARK: - Scaling Functions

kernel void nearest_scale_compute(texture2d<float, access::read> inputTexture [[texture(0)]],
                                 texture2d<float, access::write> outputTexture [[texture(1)]],
                                 uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    float2 outputSize = float2(outputTexture.get_width(), outputTexture.get_height());
    float2 inputSize = float2(inputTexture.get_width(), inputTexture.get_height());

    float2 coord = (float2(gid) + 0.5) / outputSize;
    uint2 inputCoord = uint2(coord * inputSize);

    float4 color = inputTexture.read(inputCoord);
    outputTexture.write(color, gid);
}

kernel void bilinear_scale_compute(texture2d<float, access::read> inputTexture [[texture(0)]],
                                  texture2d<float, access::write> outputTexture [[texture(1)]],
                                  uint2 gid [[thread_position_in_grid]]) {
    if (gid.x >= outputTexture.get_width() || gid.y >= outputTexture.get_height()) {
        return;
    }

    float2 outputSize = float2(outputTexture.get_width(), outputTexture.get_height());
    float2 inputSize = float2(inputTexture.get_width(), inputTexture.get_height());

    float2 coord = (float2(gid) + 0.5) / outputSize;
    float2 inputCoord = coord * inputSize - 0.5;

    uint2 coord0 = uint2(floor(inputCoord));
    uint2 coord1 = coord0 + uint2(1, 0);
    uint2 coord2 = coord0 + uint2(0, 1);
    uint2 coord3 = coord0 + uint2(1, 1);

    // Clamp coordinates
    coord0 = min(coord0, uint2(inputSize) - 1);
    coord1 = min(coord1, uint2(inputSize) - 1);
    coord2 = min(coord2, uint2(inputSize) - 1);
    coord3 = min(coord3, uint2(inputSize) - 1);

    float2 f = fract(inputCoord);

    float4 c0 = inputTexture.read(coord0);
    float4 c1 = inputTexture.read(coord1);
    float4 c2 = inputTexture.read(coord2);
    float4 c3 = inputTexture.read(coord3);

    float4 color = mix(mix(c0, c1, f.x), mix(c2, c3, f.x), f.y);
    outputTexture.write(color, gid);
}