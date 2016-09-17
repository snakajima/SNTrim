//
//  maskImage.metal
//  SNTrim
//
//  Created by satoshi on 9/16/16.
//  Copyright © 2016 Satoshi Nakajima. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

kernel void maskImage(device uchar* rgba [[ buffer(0) ]],
                      const device uint& width [[ buffer(1) ]],
                      const device uint& height [[ buffer(2) ]],
                      const device float& x0 [[ buffer(3) ]],
                      const device float& y0 [[ buffer(4) ]],
                      const device float& z0 [[ buffer(5) ]],

                      const uint tgPos [[ threadgroup_position_in_grid ]],
                      const uint tPerTg [[ threads_per_threadgroup ]],
                      const uint tPos [[ thread_position_in_threadgroup ]]) {
    
    uint offset = tgPos * tPerTg + tPos;
    uint index = offset * width * 4;
    uint end = index + width * 4;
    for(; index < end; index += 4) {
        const uchar r = rgba[index];
        const uchar g = rgba[index+1];
        const uchar b = rgba[index+2];
        const uchar v = max(r, max(g, b));
        uchar s = 0;
        int h = 0;
        if (v > 0) {
            uint delta = (uint)(v - min(r, min(g, b)));
            if (delta > 0) {
                s = (uchar)(delta * 255 / (uint)v);
                int delR = (((uint)(v - r) * 60) + delta * 180) / delta;
                int delG = (((uint)(v - g) * 60) + delta * 180) / delta;
                int delB = (((uint)(v - b) * 60) + delta * 180) / delta;
                if (r == v) {
                    h = delB - delG;
                } else if (g == v) {
                    h = 120 + delR - delB;
                } else {
                    h = 240 + delG - delR;
                }
                h = (h + 360) % 360;
            }
        }
        float radian = (float)h * 3.14159265 / 180.0;
        float z = (float)v / 255.0;
        float x = sin(radian) * sqrt(z) * (float)s / 255.0;
        float y = cos(radian) * sqrt(z) * (float)s / 255.0;
        float dx = x0 - x;
        float dy = y0 - y;
        float dz = z0 - z;
        float d = (sqrt(dx * dx + dy * dy + dz * dz) - 0.1) * 4.0;
        float a = max(0.0, min(1.0, d));
        rgba[index+3] = (uchar)(a * 255.0);
    }
}

