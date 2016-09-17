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

kernel void maskImage(device Pixel* pixels [[ buffer(0) ]],
                      const device uint& width [[ buffer(1) ]],
                      const device uint& height [[ buffer(2) ]],
                      const device float& x0 [[ buffer(3) ]],
                      const device float& y0 [[ buffer(4) ]],
                      const device float& z0 [[ buffer(5) ]],
                      const device bool& inv [[ buffer(6) ]],

                      const uint tgPos [[ threadgroup_position_in_grid ]],
                      const uint tPerTg [[ threads_per_threadgroup ]],
                      const uint tPos [[ thread_position_in_threadgroup ]]) {
    
    uint offset = tgPos * tPerTg + tPos;
    uint index = offset * width;
    uint end = index + width;
    for(; index < end; index++) {
        const Pixel pixel = pixels[index];
        const uchar v = max(pixel.r, max(pixel.g, pixel.b));
        float s = 0.0;
        int h = 0;
        if (v > 0) {
            uint delta = (uint)(v - min(pixel.r, min(pixel.g, pixel.b)));
            if (delta > 0) {
                s = (float)delta / (float)v;
                int delR = (((uint)(v - pixel.r) * 60) + delta * 180) / delta;
                int delG = (((uint)(v - pixel.g) * 60) + delta * 180) / delta;
                int delB = (((uint)(v - pixel.b) * 60) + delta * 180) / delta;
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
        float x = sin(radian) * sqrt(z) * s;
        float y = cos(radian) * sqrt(z) * s;
        float dx = x0 - x;
        float dy = y0 - y;
        float dz = z0 - z;
        float d = (sqrt(dx * dx + dy * dy + dz * dz) - 0.1) * 4.0;
        float a = max(0.0, min(1.0, d));
        if (inv) {
            a = 1.0 - a;
        }
        pixels[index].a = (uchar)(a * 255.0);
    }
}

