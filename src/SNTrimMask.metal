//
//  SNTrimMask.metal
//  SNTrim
//
//  Created by satoshi on 9/16/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

struct Pixel {
    uchar r;
    uchar g;
    uchar b;
    uchar a;
};

struct Position {
    float x;
    float y;
    float z;
};

kernel void SNTrimMask(device Pixel* pixelBuffer [[ buffer(0) ]],
                      const device ushort& width [[ buffer(1) ]],
                      const device ushort& height [[ buffer(2) ]],
                      const device Position& pos [[ buffer(3) ]],
                      const device float& slack [[ buffer(4) ]],
                      const device float& slope [[ buffer(5) ]],
                      const device bool& inv [[ buffer(6) ]],

                      const uint2 gid [[ thread_position_in_grid ]]) {
    
    const uint index = (uint)width * (uint)gid.y + (uint)gid.x;
    const Pixel pixel = pixelBuffer[index];
    float v = max(pixel.r, max(pixel.g, pixel.b)); // Value 0-255
    float s = 0.0; // Saturation 0.0-1.0
    float h = 0; // Hue 0-360
    float delta = v - (float)min(pixel.r, min(pixel.g, pixel.b));
    if (v * delta > 0) {
        s = (float)delta / (float)v;
        float delG = (v - (float)pixel.g) * 60.0 / delta;
        float delB = (v - (float)pixel.b) * 60.0 / delta;
        float delR = (v - (float)pixel.r) * 60.0 / delta;
        if (pixel.r == v) {
            h = delB - delG;
        } else if (pixel.g == v) {
            h = 120 + delR - delB;
        } else {
            h = 240 + delG - delR;
        }
    }
    float radian = (float)h * M_PI_F / 180.0;
    float z = (float)v / 255.0;
    float factor = sqrt(z) * s;
    float dx = pos.x - cos(radian) * factor;
    float dy = pos.y - sin(radian) * factor;
    float dz = pos.z - z;
    float a = saturate((sqrt(dx * dx + dy * dy + dz * dz) - slack) * slope);
    if (inv) {
        a = 1.0 - a;
    }
    pixelBuffer[index].a = (uchar)(a * 255.0);
}

