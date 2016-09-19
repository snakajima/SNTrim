//
//  maskImage.metal
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

kernel void maskImage(device Pixel* pixels [[ buffer(0) ]],
                      const device ushort& width [[ buffer(1) ]],
                      const device ushort& height [[ buffer(2) ]],
                      const device Position& pos [[ buffer(3) ]],
                      const device bool& inv [[ buffer(4) ]],

                      const uint tgPos [[ threadgroup_position_in_grid ]],
                      const uint tPerTg [[ threads_per_threadgroup ]],
                      const uint tPos [[ thread_position_in_threadgroup ]]) {
    
    uint offset = tgPos * tPerTg + tPos;
    if (offset >= height) {
        return;
    }
    uint index = offset * width;
    uint end = index + width;
    for(; index < end; index++) {
        const Pixel pixel = pixels[index];
        const uchar v = max(pixel.r, max(pixel.g, pixel.b)); // Value 0-255
        float s = 0.0; // Saturation 0.0-1.0
        short h = 0; // Hue 0-360
        if (v > 0) {
            uint delta = (uint)(v - min(pixel.r, min(pixel.g, pixel.b)));
            if (delta > 0) {
                s = (float)delta / (float)v;
                short delR = (((short)(v - pixel.r) * 60) + delta * 180) / delta;
                short delG = (((short)(v - pixel.g) * 60) + delta * 180) / delta;
                short delB = (((short)(v - pixel.b) * 60) + delta * 180) / delta;
                if (pixel.r == v) {
                    h = delB - delG;
                } else if (pixel.g == v) {
                    h = 120 + delR - delB;
                } else {
                    h = 240 + delG - delR;
                }
                h = (h + 360) % 360;
            }
        }
        float radian = (float)h * 3.14159265 / 180.0;
        float z = (float)v / 255.0;
        float factor = sqrt(z) * s;
        float dx = pos.x - sin(radian) * factor;
        float dy = pos.y - cos(radian) * factor;
        float dz = pos.z - z;
        float a = saturate((sqrt(dx * dx + dy * dy + dz * dz) - 0.1) * 4.0);
        if (inv) {
            a = 1.0 - a;
        }
        pixels[index].a = (uchar)(a * 255.0);
    }
}

